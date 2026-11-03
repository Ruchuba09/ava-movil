import 'dart:io';
import 'dart:convert';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/database/principal.dart';
import 'package:avamovil/database/sync_queue.dart';
import 'package:avamovil/services/offline_sync_service.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _versionOneSyncTable = '''
CREATE TABLE sincronizacion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tabla TEXT NOT NULL,
  registro_id INTEGER,
  operacion TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT 'pendiente',
  fecha_creacion TEXT NOT NULL,
  fecha_sincronizacion TEXT,
  ultimo_error TEXT
);
''';

void main() {
  late Directory databaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'avamovil-database-test-',
    );
    await databaseFactoryFfi.setDatabasesPath(databaseDirectory.path);
  });

  setUp(() async {
    await AvaMovilDatabase.instance.deleteDB();
  });

  tearDown(() async {
    await AvaMovilDatabase.instance.close();
  });

  tearDownAll(() async {
    await AvaMovilDatabase.instance.deleteDB();
    await databaseDirectory.delete(recursive: true);
  });

  test('creates the schema with foreign keys and sync queue indexes', () async {
    final db = await AvaMovilDatabase.instance.database;

    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys;');
    expect(foreignKeys.single.values.single, 1);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      tables.map((row) => row['name']),
      containsAll([
        'personas',
        'eventos',
        'evidencias',
        'sincronizacion',
        'offline_cache',
      ]),
    );

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      indexes.map((row) => row['name']),
      contains('idx_sincronizacion_estado_fecha'),
    );
    expect(
      indexes.map((row) => row['name']),
      contains('idx_sincronizacion_registro'),
    );
  });

  test(
    'upgrades version one queue and preserves its pending entries',
    () async {
      final databasePath = path.join(await getDatabasesPath(), 'avamovil.db');
      final versionOneDb = await openDatabase(
        databasePath,
        version: 1,
        onCreate: (db, version) async {
          final statements = [
            personasTable,
            rolesTable,
            permisosTable,
            clientesTable,
            faenasTable,
            departamentosTable,
            tipoEventosTable,
            tipoObrerosTable,
            trabajadoresTable,
            administrativosTable,
            supervisoresTable,
            usersTable,
            areasTable,
            proyectosTable,
            cuadrillasTable,
            obrerosTable,
            asignacionesTable,
            actividadesTable,
            rolPermisoTable,
            usuarioRolTable,
            trabajadorDepartamentoTable,
            eventosTable,
            eventoTrabajadorTable,
            evidenciasTable,
            _versionOneSyncTable,
          ];
          for (final statement in statements) {
            await db.execute(statement);
          }

          await db.insert('sincronizacion', {
            'tabla': 'eventos',
            'registro_id': 42,
            'operacion': 'actualizar',
            'fecha_creacion': '2026-01-02T03:04:05.000Z',
          });
        },
      );
      await versionOneDb.close();

      final upgradedDb = await AvaMovilDatabase.instance.database;
      final rows = await upgradedDb.query('sincronizacion');

      expect(rows, hasLength(1));
      expect(rows.single['tabla'], 'eventos');
      expect(rows.single['registro_id'], 42);
      expect(rows.single['payload_json'], isNull);
      expect(rows.single['intentos'], 0);
      expect(rows.single['fecha_actualizacion'], rows.single['fecha_creacion']);

      final tables = await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(tables.map((row) => row['name']), contains('offline_cache'));
    },
  );

  test(
    'queues transactional changes, retries errors, and marks success',
    () async {
      final db = await AvaMovilDatabase.instance.database;
      const queue = SyncQueue();
      late int entryId;

      await db.transaction((transaction) async {
        entryId = await queue.enqueue(
          executor: transaction,
          entity: 'eventos',
          recordId: 8,
          operation: 'actualizar',
          payload: const {'estado': 'cerrado'},
        );
      });

      var pending = await queue.pending();
      expect(pending, hasLength(1));
      expect(pending.single.id, entryId);
      expect(pending.single.entity, 'eventos');
      expect(pending.single.recordId, 8);
      expect(pending.single.payload, {'estado': 'cerrado'});
      expect(pending.single.attempts, 0);

      await queue.markFailed(entryId, Exception('Sin conexión'));
      pending = await queue.pending();
      expect(pending.single.status, 'error');
      expect(pending.single.attempts, 1);
      expect(pending.single.lastError, contains('Sin conexión'));

      await queue.markSynced(entryId);
      expect(await queue.pending(), isEmpty);
    },
  );

  test('rolls back the queue entry with its enclosing transaction', () async {
    final db = await AvaMovilDatabase.instance.database;
    const queue = SyncQueue();

    await expectLater(
      db.transaction((transaction) async {
        await queue.enqueue(
          executor: transaction,
          entity: 'eventos',
          operation: 'crear',
          payload: const {'descripcion': 'Cambio local'},
        );
        throw StateError('Simular fallo de la escritura local');
      }),
      throwsStateError,
    );

    expect(await queue.pending(), isEmpty);
  });

  test('caches per-user data without credentials', () async {
    final store = OfflineStore();
    await store.saveJson(
      userKey: 'person@example.test',
      key: OfflineStore.profileKey,
      value: {
        'id': 42,
        'email': 'person@example.test',
        'password': 'must-not-be-cached',
        'access_token': 'must-not-be-cached-either',
        'nested': {'token': 'also-not-cached', 'name': 'Persona'},
      },
    );

    final cached =
        await store.readJson(
              userKey: 'person@example.test',
              key: OfflineStore.profileKey,
            )
            as Map<String, dynamic>;

    expect(cached, {
      'id': 42,
      'email': 'person@example.test',
      'nested': {'name': 'Persona'},
    });
    expect(
      await store.readJson(
        userKey: 'another@example.test',
        key: OfflineStore.profileKey,
      ),
      isNull,
    );
  });

  test('shows pending reports only for matching account', () async {
    final db = await AvaMovilDatabase.instance.database;
    const queue = SyncQueue();
    await queue.enqueue(
      executor: db,
      entity: 'eventos',
      operation: 'crear',
      payload: const {
        'user_key': 'one@example.test',
        'descripcion': 'Reporte del usuario uno',
      },
    );
    await queue.enqueue(
      executor: db,
      entity: 'eventos',
      operation: 'crear',
      payload: const {
        'user_key': 'two@example.test',
        'descripcion': 'Reporte del usuario dos',
      },
    );

    final pending = await OfflineStore().pendingReports('one@example.test');

    expect(pending, hasLength(1));
    expect(pending.single.payload?['descripcion'], 'Reporte del usuario uno');
  });

  test('syncs only the active user’s queued reports with evidence', () async {
    final db = await AvaMovilDatabase.instance.database;
    const queue = SyncQueue();
    final payload = <String, Object?>{
      'user_key': 'one@example.test',
      'id_tipo_evento': 4,
      'condicion': 2,
      'descripcion': 'Reporte guardado sin conexión',
      'referencia': 'Nivel 4',
      'id_proyecto': 7,
      'es_para_mi': true,
      'evidencias': [
        {
          'name': 'evidencia.jpg',
          'bytes_base64': base64Encode([1, 2, 3]),
        },
      ],
    };
    final activeId = await queue.enqueue(
      executor: db,
      entity: 'eventos',
      operation: 'crear',
      payload: payload,
    );
    await queue.enqueue(
      executor: db,
      entity: 'eventos',
      operation: 'crear',
      payload: {...payload, 'user_key': 'two@example.test'},
    );

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.https('example.test', '/api/eventos'));
      expect(request.headers['Authorization'], 'Bearer cached-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final multipartBody = utf8.decode(
        request.bodyBytes,
        allowMalformed: true,
      );
      expect(multipartBody, contains('name="descripcion"'));
      expect(multipartBody, contains(payload['descripcion'] as String));
      expect(multipartBody, contains('filename="evidencia.jpg"'));
      return http.Response(
        jsonEncode({'id_evento': 101}),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await OfflineSyncService(
      client: client,
      baseUrl: 'https://example.test/api',
    ).synchronize(userKey: 'one@example.test', accessToken: 'cached-token');

    final pendingAfterSync = await queue.pending();
    expect(result.synchronized, 1, reason: pendingAfterSync.first.lastError);
    expect(result.failed, 0);
    expect(await queue.pending(), hasLength(1));
    final remainingRows = await db.query(
      'sincronizacion',
      where: 'id = ?',
      whereArgs: [activeId],
    );
    expect(remainingRows.single['estado'], 'sincronizado');
  });
}
