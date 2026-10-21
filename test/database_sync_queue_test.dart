import 'dart:io';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/database/principal.dart';
import 'package:avamovil/database/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
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
      containsAll(['personas', 'eventos', 'evidencias', 'sincronizacion']),
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

  test('upgrades version one queue and preserves its pending entries',
      () async {
    final databasePath = path.join(
      await getDatabasesPath(),
      'avamovil.db',
    );
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
  });

  test('queues transactional changes, retries errors, and marks success',
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
  });

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
}
