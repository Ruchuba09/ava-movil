import 'dart:async';
import 'dart:io';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/offline_auth.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryTokenStore implements TokenStore {
  final Map<String, String> tokens = {};

  @override
  Future<String?> read(String userKey) async => tokens[userKey];

  @override
  Future<void> write(String userKey, String token) async =>
      tokens[userKey] = token;

  @override
  Future<void> delete(String userKey) async => tokens.remove(userKey);

  String? activeSession;

  @override
  Future<String?> readActiveSession() async => activeSession;

  @override
  Future<void> writeActiveSession(String? userKey) async =>
      activeSession = userKey;
}

void main() {
  late Directory databaseDirectory;
  late _MemoryTokenStore tokens;
  late DateTime now;
  late OfflineAuthService auth;

  const userKey = 'ana@ava.cl';
  final profile = <String, dynamic>{
    'id_user': 7,
    'email': 'Ana@AVA.cl',
    'rut': '12345678-5',
    'name': 'Ana',
  };

  LoginIdentifier id(String text) => LoginIdentifier.parse(text)!;

  Future<void> guardar({String password = 'secreta'}) async {
    await OfflineStore().saveJson(
      userKey: userKey,
      key: OfflineStore.profileKey,
      value: profile,
    );
    await auth.guardarLoginOnline(
      userKey: userKey,
      profile: profile,
      password: password,
      accessToken: 'token-1',
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'avamovil-offline-auth-test-',
    );
    await databaseFactoryFfi.setDatabasesPath(databaseDirectory.path);
  });

  setUp(() async {
    await AvaMovilDatabase.instance.deleteDB();
    tokens = _MemoryTokenStore();
    now = DateTime.utc(2026, 11, 12, 10);
    auth = OfflineAuthService(tokens: tokens, now: () => now);
  });

  tearDown(() async {
    await AvaMovilDatabase.instance.close();
  });

  tearDownAll(() async {
    await AvaMovilDatabase.instance.deleteDB();
    await databaseDirectory.delete(recursive: true);
  });

  group('LoginIdentifier', () {
    test('acepta RUT con o sin puntos y guion', () {
      for (final texto in ['12.345.678-5', '12345678-5', '123456785']) {
        final parsed = LoginIdentifier.parse(texto)!;
        expect(parsed.esCorreo, isFalse);
        expect(parsed.valor, '12345678-5');
      }
      expect(LoginIdentifier.parse('7.654.333-k')!.valor, '7654333-K');
    });

    test('rechaza RUT con dígito verificador incorrecto', () {
      expect(LoginIdentifier.parse('12.345.678-9'), isNull);
      expect(LoginIdentifier.validar('12.345.678-9'), 'El RUT no es válido');
    });

    test('acepta correo y lo pasa a minúsculas', () {
      final parsed = LoginIdentifier.parse('  Ana@AVA.cl ')!;
      expect(parsed.esCorreo, isTrue);
      expect(parsed.valor, 'ana@ava.cl');
      expect(LoginIdentifier.validar('ana@'), 'El correo no es válido');
    });
  });

  test('no guarda la contraseña en texto plano', () async {
    await guardar();
    final db = await AvaMovilDatabase.instance.database;
    final row = (await db.query('credenciales_offline')).single;
    expect(row['password_hash'], isNot(contains('secreta')));
    expect(row['password_hash'], startsWith(r'$2'));
    expect(row['email'], 'ana@ava.cl');
    expect(row['rut'], '12345678-5');
  });

  test('entra sin conexión con RUT o correo y la contraseña', () async {
    await guardar();
    for (final texto in ['12.345.678-5', 'ANA@ava.cl']) {
      final login = await auth.autenticar(
        identificador: id(texto),
        password: 'secreta',
      );
      expect(login.userKey, userKey);
      expect(login.accessToken, 'token-1');
      expect(login.profile['name'], 'Ana');
    }
  });

  test('rechaza usuarios que nunca entraron en el dispositivo', () async {
    expect(
      auth.autenticar(identificador: id('ana@ava.cl'), password: 'x'),
      throwsA(isA<OfflineAuthException>()),
    );
  });

  test('vence a los 7 días y se renueva con un login online', () async {
    await guardar();
    now = now.add(const Duration(days: 7, minutes: 1));
    await expectLater(
      auth.autenticar(identificador: id('ana@ava.cl'), password: 'secreta'),
      throwsA(
        isA<OfflineAuthException>().having(
          (e) => e.message,
          'message',
          contains('venció'),
        ),
      ),
    );

    await guardar();
    final login = await auth.autenticar(
      identificador: id('ana@ava.cl'),
      password: 'secreta',
    );
    expect(login.userKey, userKey);
  });

  test('bloquea tras 7 intentos fallidos', () async {
    await guardar();
    for (var i = 1; i < OfflineAuthService.maxIntentos; i++) {
      await expectLater(
        auth.autenticar(identificador: id('ana@ava.cl'), password: 'mala'),
        throwsA(
          isA<OfflineAuthException>().having(
            (e) => e.message,
            'message',
            contains('Te quedan'),
          ),
        ),
      );
    }
    await expectLater(
      auth.autenticar(identificador: id('ana@ava.cl'), password: 'mala'),
      throwsA(
        isA<OfflineAuthException>().having(
          (e) => e.message,
          'message',
          contains('bloqueado'),
        ),
      ),
    );

    // Bloqueado incluso con la contraseña correcta.
    await expectLater(
      auth.autenticar(identificador: id('ana@ava.cl'), password: 'secreta'),
      throwsA(isA<OfflineAuthException>()),
    );

    now = now.add(const Duration(minutes: 6));
    final login = await auth.autenticar(
      identificador: id('ana@ava.cl'),
      password: 'secreta',
    );
    expect(login.userKey, userKey);
  });

  test('cerrar sesión borra el token pero mantiene el acceso', () async {
    await guardar();
    await auth.cerrarSesion(userKey);
    final login = await auth.autenticar(
      identificador: id('ana@ava.cl'),
      password: 'secreta',
    );
    expect(login.accessToken, isNull);
  });

  test('restaura la sesión abierta sin contraseña ni vencimiento', () async {
    await guardar();
    expect(await auth.restaurarSesion(), isNull);

    await auth.abrirSesion(userKey);
    now = now.add(const Duration(days: 30));
    final login = await auth.restaurarSesion();
    expect(login?.userKey, userKey);
    expect(login?.accessToken, 'token-1');

    await auth.cerrarSesion(userKey);
    expect(await auth.restaurarSesion(), isNull);
  });

  test('sólo cae a offline si Laravel no responde', () {
    expect(
      OfflineAuthService.esFallaDeConexion(const SocketException('x')),
      isTrue,
    );
    expect(OfflineAuthService.esFallaDeConexion(TimeoutException('x')), isTrue);
    expect(
      OfflineAuthService.esFallaDeConexion(
        const ApiException(statusCode: 503, message: 'x'),
      ),
      isTrue,
    );
    expect(
      OfflineAuthService.esFallaDeConexion(
        const ApiException(statusCode: 422, message: 'x'),
      ),
      isFalse,
    );
  });
}
