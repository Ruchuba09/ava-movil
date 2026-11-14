import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/conectividad.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

/// Lo que el usuario escribe en el login: un correo o un RUT chileno.
class LoginIdentifier {
  final bool esCorreo;

  /// Correo en minúsculas, o RUT sin puntos con guion y DV en mayúscula
  /// (`12345678-K`), el mismo formato que usa `Rut::clean` en Laravel.
  final String valor;

  const LoginIdentifier._(this.esCorreo, this.valor);

  static final RegExp _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Devuelve `null` si no es un correo ni un RUT válido.
  static LoginIdentifier? parse(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return null;

    if (limpio.contains('@')) {
      return _correo.hasMatch(limpio)
          ? LoginIdentifier._(true, limpio.toLowerCase())
          : null;
    }

    final rut = normalizarRut(limpio);
    return rut != null && rutValido(rut) ? LoginIdentifier._(false, rut) : null;
  }

  /// Mensaje para el validador del formulario, o `null` si es válido.
  static String? validar(String? texto) {
    final valor = texto?.trim() ?? '';
    if (valor.isEmpty) return 'Ingrese su RUT o correo';
    if (parse(valor) != null) return null;
    return valor.contains('@')
        ? 'El correo no es válido'
        : 'El RUT no es válido';
  }

  /// `12.345.678-k` → `12345678-K`. Devuelve `null` si no tiene forma de RUT.
  static String? normalizarRut(String texto) {
    final compacto = texto.toUpperCase().replaceAll(RegExp(r'[.\s-]'), '');
    if (!RegExp(r'^\d{7,8}[\dK]$').hasMatch(compacto)) return null;
    final cuerpo = compacto.substring(0, compacto.length - 1);
    return '${int.parse(cuerpo)}-${compacto[compacto.length - 1]}';
  }

  /// Comprueba el dígito verificador (módulo 11) de un RUT normalizado.
  static bool rutValido(String rutNormalizado) {
    final partes = rutNormalizado.split('-');
    if (partes.length != 2) return false;

    var suma = 0;
    var factor = 2;
    for (final digito in partes[0].split('').reversed) {
      suma += int.parse(digito) * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }
    final resto = 11 - (suma % 11);
    final dv = switch (resto) {
      11 => '0',
      10 => 'K',
      _ => '$resto',
    };
    return dv == partes[1];
  }
}

/// Fallo al entrar sin conexión, con un mensaje para mostrar al usuario.
class OfflineAuthException implements Exception {
  final String message;

  const OfflineAuthException(this.message);

  @override
  String toString() => message;
}

/// Sesión abierta sin consultar a Laravel.
class OfflineLogin {
  final String userKey;
  final Map<String, dynamic> profile;

  /// Último token emitido por Laravel para este usuario, o `null` si se
  /// borró al cerrar sesión. Sin token la app sólo funciona con la caché.
  final String? accessToken;

  const OfflineLogin({
    required this.userKey,
    required this.profile,
    required this.accessToken,
  });
}

/// Guarda fuera de SQLite el token de cada usuario y qué sesión está abierta.
abstract class TokenStore {
  Future<String?> read(String userKey);
  Future<void> write(String userKey, String token);
  Future<void> delete(String userKey);

  /// `userKey` de la sesión abierta en el dispositivo, si hay una.
  Future<String?> readActiveSession();
  Future<void> writeActiveSession(String? userKey);
}

class SecureTokenStore implements TokenStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  const SecureTokenStore();

  String _key(String userKey) => 'ava_movil_token:$userKey';

  @override
  Future<String?> read(String userKey) => _storage.read(key: _key(userKey));

  @override
  Future<void> write(String userKey, String token) =>
      _storage.write(key: _key(userKey), value: token);

  @override
  Future<void> delete(String userKey) => _storage.delete(key: _key(userKey));

  static const String _activeSessionKey = 'ava_movil_sesion_activa';

  @override
  Future<String?> readActiveSession() => _storage.read(key: _activeSessionKey);

  @override
  Future<void> writeActiveSession(String? userKey) => userKey == null
      ? _storage.delete(key: _activeSessionKey)
      : _storage.write(key: _activeSessionKey, value: userKey);
}

String _hashPassword(String password) =>
    BCrypt.hashpw(password, BCrypt.gensalt());

bool _checkPassword(List<String> args) => BCrypt.checkpw(args[0], args[1]);

/// Login sin conexión contra los usuarios que ya entraron en este dispositivo.
class OfflineAuthService {
  /// Días que dura el acceso sin conexión desde el último login con conexión.
  static const Duration vigencia = Duration(days: 7);

  /// Intentos fallidos permitidos antes de bloquear temporalmente.
  static const int maxIntentos = 7;

  final TokenStore _tokens;
  final OfflineStore _store;
  final DateTime Function() _now;

  OfflineAuthService({
    this._tokens = const SecureTokenStore(),
    OfflineStore? store,
    DateTime Function()? now,
  }) : _store = store ?? OfflineStore(),
       _now = now ?? DateTime.now;

  static const String _tabla = 'credenciales_offline';

  /// `true` si el error indica que Laravel no está disponible (sin red,
  /// timeout o fallo del servidor). Un 401/422/429 significa que el servidor
  /// respondió, así que no se debe intentar entrar sin conexión.
  static bool esFallaDeConexion(Object error) {
    if (error is ApiException) return error.statusCode >= 500;
    return Conectividad.esFallaDeRed(error);
  }

  /// Guarda o renueva el acceso offline tras un login correcto en Laravel.
  Future<void> guardarLoginOnline({
    required String userKey,
    required Map<String, dynamic> profile,
    required String password,
    required String accessToken,
  }) async {
    final hash = await compute(_hashPassword, password);
    final email = (profile['email'] ?? profile['correo'])?.toString().trim();
    final rutPerfil = profile['rut']?.toString();
    final rut = rutPerfil == null
        ? null
        : LoginIdentifier.normalizarRut(rutPerfil);
    final id = profile['id_user'] ?? profile['id'];

    final db = await AvaMovilDatabase.instance.database;
    await db.transaction((txn) async {
      // Si el correo o RUT pasó a otro usuario en Laravel, el registro
      // antiguo deja de valer para no chocar con las columnas únicas.
      await txn.delete(
        _tabla,
        where: 'user_key <> ? AND (email = ? OR rut = ?)',
        whereArgs: [userKey, email?.toLowerCase(), rut],
      );
      await txn.insert(_tabla, {
        'user_key': userKey,
        'id_user': id is num ? id.toInt() : null,
        'email': email == null || email.isEmpty ? null : email.toLowerCase(),
        'rut': rut,
        'password_hash': hash,
        'ultimo_login_online': _now().toUtc().toIso8601String(),
        'intentos_fallidos': 0,
        'bloqueado_hasta': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await _tokens.write(userKey, accessToken);
  }

  /// Valida RUT/correo y contraseña sólo con los datos del dispositivo.
  Future<OfflineLogin> autenticar({
    required LoginIdentifier identificador,
    required String password,
  }) async {
    final db = await AvaMovilDatabase.instance.database;
    final rows = await db.query(
      _tabla,
      where: identificador.esCorreo ? 'email = ?' : 'rut = ?',
      whereArgs: [identificador.valor],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const OfflineAuthException(
        'Sin conexión: este usuario no ha iniciado sesión antes en este '
        'dispositivo. Conéctate a internet para entrar por primera vez.',
      );
    }

    final row = rows.single;
    final userKey = row['user_key'] as String;
    final ahora = _now().toUtc();

    final bloqueadoHasta = DateTime.tryParse(
      row['bloqueado_hasta'] as String? ?? '',
    );
    if (bloqueadoHasta != null && ahora.isBefore(bloqueadoHasta)) {
      final minutos = bloqueadoHasta.difference(ahora).inMinutes + 1;
      throw OfflineAuthException(
        'Demasiados intentos fallidos. Intenta de nuevo en $minutos '
        '${minutos == 1 ? 'minuto' : 'minutos'} o conéctate a internet.',
      );
    }

    final ultimoLogin = DateTime.parse(row['ultimo_login_online'] as String);
    if (ahora.difference(ultimoLogin) > vigencia) {
      throw const OfflineAuthException(
        'Tu acceso sin conexión venció (más de 7 días sin conectarte). '
        'Conéctate a internet e inicia sesión para renovarlo.',
      );
    }

    final correcta = await compute(_checkPassword, [
      password,
      row['password_hash'] as String,
    ]);
    if (!correcta) {
      final intentos = (row['intentos_fallidos'] as int) + 1;
      final bloqueo = _duracionBloqueo(intentos);
      await db.update(
        _tabla,
        {
          'intentos_fallidos': intentos,
          'bloqueado_hasta': bloqueo == null
              ? null
              : ahora.add(bloqueo).toIso8601String(),
        },
        where: 'user_key = ?',
        whereArgs: [userKey],
      );
      final restantes = maxIntentos - intentos;
      throw OfflineAuthException(
        bloqueo != null
            ? 'Contraseña incorrecta. Acceso sin conexión bloqueado por '
                  '${bloqueo.inMinutes} minutos.'
            : 'Contraseña incorrecta. Te quedan $restantes '
                  '${restantes == 1 ? 'intento' : 'intentos'}.',
      );
    }

    await db.update(
      _tabla,
      {'intentos_fallidos': 0, 'bloqueado_hasta': null},
      where: 'user_key = ?',
      whereArgs: [userKey],
    );

    final profile = await _store.readJson(
      userKey: userKey,
      key: OfflineStore.profileKey,
    );
    if (profile is! Map) {
      throw const OfflineAuthException(
        'No hay datos sincronizados de este usuario en el dispositivo. '
        'Conéctate a internet e inicia sesión.',
      );
    }

    return OfflineLogin(
      userKey: userKey,
      profile: Map<String, dynamic>.from(profile),
      accessToken: await _tokens.read(userKey),
    );
  }

  /// Marca la sesión como abierta: al reiniciar la app se entra directo,
  /// sin contraseña ni conexión, hasta que el usuario cierre sesión.
  Future<void> abrirSesion(String userKey) =>
      _tokens.writeActiveSession(userKey);

  /// Sesión que quedó abierta la última vez, o `null` si no hay una o ya no
  /// quedan datos locales de ese usuario. No aplica los 7 días: esos rigen
  /// sólo para un login nuevo sin conexión.
  Future<OfflineLogin?> restaurarSesion() async {
    final userKey = await _tokens.readActiveSession();
    if (userKey == null || userKey.trim().isEmpty) return null;

    final db = await AvaMovilDatabase.instance.database;
    final rows = await db.query(
      _tabla,
      columns: ['user_key'],
      where: 'user_key = ?',
      whereArgs: [userKey],
      limit: 1,
    );
    final profile = rows.isEmpty
        ? null
        : await _store.readJson(userKey: userKey, key: OfflineStore.profileKey);
    if (profile is! Map) {
      await _tokens.writeActiveSession(null);
      return null;
    }

    return OfflineLogin(
      userKey: userKey,
      profile: Map<String, dynamic>.from(profile),
      accessToken: await _tokens.read(userKey),
    );
  }

  /// Al cerrar sesión se borra el token (ya revocado en Laravel) y la sesión
  /// abierta, pero el usuario conserva el acceso sin conexión con contraseña.
  Future<void> cerrarSesion(String userKey) async {
    await _tokens.writeActiveSession(null);
    await _tokens.delete(userKey);
  }

  /// 7 fallos → 5 min; cada fallo extra duplica la espera, hasta 1 hora.
  static Duration? _duracionBloqueo(int intentos) {
    if (intentos < maxIntentos) return null;
    final minutos = 5 * (1 << (intentos - maxIntentos).clamp(0, 4));
    return Duration(minutes: minutos.clamp(5, 60));
  }
}
