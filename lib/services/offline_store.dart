import 'dart:convert';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/database/sync_queue.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

class OfflineStore {
  static const String profileKey = 'profile';
  static const String projectsKey = 'projects';
  static const String eventOptionsKey = 'event_options';
  static const String myReportsKey = 'my_reports';
  static const String teamReportsKey = 'team_reports';

  Map<String, dynamic> profileForOffline(
    Map<String, dynamic> profile, {
    required String fallbackEmail,
  }) {
    final result = <String, dynamic>{
      'email': profile['email'] ?? profile['correo'] ?? fallbackEmail,
    };
    for (final key in [
      'id',
      'id_user',
      'id_trabajador',
      'trabajador_id',
      'name',
      'nombre',
      'role',
      'rol',
      'tipo_usuario',
      'cargo',
    ]) {
      if (profile.containsKey(key)) result[key] = profile[key];
    }

    final roles = profile['roles'];
    if (roles is List) {
      result['roles'] = roles
          .map((role) {
            if (role is String) return role;
            if (role is Map) {
              final name =
                  role['name'] ?? role['nombre'] ?? role['descripcion'];
              if (name is String) return {'name': name};
            }
            return null;
          })
          .where((role) => role != null)
          .toList(growable: false);
    }

    if (profile['trabajador'] is Map ||
        profile['usuario_trabajador'] is Map ||
        profile['usuarioTrabajador'] is Map) {
      result['trabajador'] = const <String, Object?>{};
    }
    return result;
  }

  static String userKeyFor(Map<String, dynamic> profile) {
    final email = profile['email'] ?? profile['correo'];
    if (email is String && email.trim().isNotEmpty) {
      return email.trim().toLowerCase();
    }

    final id =
        profile['id'] ??
        profile['id_user'] ??
        profile['id_trabajador'] ??
        profile['trabajador_id'];
    if (id is num && id > 0) {
      return 'user:${id.toInt()}';
    }

    throw const FormatException(
      'El perfil no contiene un identificador local seguro.',
    );
  }

  Future<void> saveJson({
    required String userKey,
    required String key,
    required Object? value,
  }) async {
    _validateKey(userKey, 'userKey');
    _validateKey(key, 'key');

    final db = await AvaMovilDatabase.instance.database;
    await db.insert('offline_cache', {
      'user_key': userKey,
      'cache_key': key,
      'payload_json': jsonEncode(_withoutCredentials(value)),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Object?> readJson({
    required String userKey,
    required String key,
  }) async {
    _validateKey(userKey, 'userKey');
    _validateKey(key, 'key');

    final db = await AvaMovilDatabase.instance.database;
    final rows = await db.query(
      'offline_cache',
      columns: ['payload_json'],
      where: 'user_key = ? AND cache_key = ?',
      whereArgs: [userKey, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    return jsonDecode(rows.single['payload_json'] as String);
  }

  Future<List<SyncQueueEntry>> pendingReports(String userKey) async {
    final entries = await const SyncQueue().pending(limit: 500);
    return entries
        .where(
          (entry) =>
              entry.entity == 'eventos' &&
              entry.operation == 'crear' &&
              entry.payload?['user_key'] == userKey,
        )
        .toList(growable: false);
  }

  void _validateKey(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'No puede estar vacío.');
    }
  }

  Object? _withoutCredentials(Object? value) {
    if (value is List) {
      return value.map(_withoutCredentials).toList(growable: false);
    }
    if (value is Map) {
      const forbiddenKeys = {
        'password',
        'passwd',
        'token',
        'api_token',
        'access_token',
        'refresh_token',
        'remember_token',
      };
      return {
        for (final entry in value.entries)
          if (!forbiddenKeys.contains(entry.key.toString().toLowerCase()))
            entry.key.toString(): _withoutCredentials(entry.value),
      };
    }
    return value;
  }
}

class OfflineSession {
  final String userKey;
  final String accessToken;

  const OfflineSession({required this.userKey, required this.accessToken});
}

class OfflineSessionStore {
  static const String _sessionStorageKey = 'ava_movil_offline_session';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> save(OfflineSession session) async {
    if (session.userKey.trim().isEmpty || session.accessToken.trim().isEmpty) {
      throw ArgumentError('La sesión offline debe tener usuario y token.');
    }
    await _storage.write(
      key: _sessionStorageKey,
      value: jsonEncode({
        'user_key': session.userKey,
        'access_token': session.accessToken,
      }),
    );
  }

  Future<OfflineSession?> read() async {
    final encoded = await _storage.read(key: _sessionStorageKey);
    if (encoded == null) return null;

    final decoded = jsonDecode(encoded);
    if (decoded is! Map ||
        decoded['user_key'] is! String ||
        decoded['access_token'] is! String ||
        (decoded['user_key'] as String).trim().isEmpty ||
        (decoded['access_token'] as String).trim().isEmpty) {
      throw const FormatException('La sesión local almacenada no es válida.');
    }

    return OfflineSession(
      userKey: decoded['user_key'] as String,
      accessToken: decoded['access_token'] as String,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionStorageKey);
  }
}
