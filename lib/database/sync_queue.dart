import 'dart:convert';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:sqflite/sqflite.dart';

class SyncQueueEntry {
  final int id;
  final String entity;
  final int? recordId;
  final String operation;
  final String status;
  final Map<String, Object?>? payload;
  final int attempts;
  final String? lastError;

  const SyncQueueEntry({
    required this.id,
    required this.entity,
    required this.recordId,
    required this.operation,
    required this.status,
    required this.payload,
    required this.attempts,
    required this.lastError,
  });

  factory SyncQueueEntry.fromMap(Map<String, Object?> row) {
    final payloadJson = row['payload_json'] as String?;
    final decodedPayload =
        payloadJson == null ? null : jsonDecode(payloadJson);
    if (decodedPayload != null && decodedPayload is! Map) {
      throw const FormatException(
        'La carga de sincronización debe ser un objeto JSON.',
      );
    }

    return SyncQueueEntry(
      id: row['id'] as int,
      entity: row['tabla'] as String,
      recordId: row['registro_id'] as int?,
      operation: row['operacion'] as String,
      status: row['estado'] as String,
      payload: decodedPayload == null
          ? null
          : Map<String, Object?>.from(decodedPayload as Map),
      attempts: row['intentos'] as int,
      lastError: row['ultimo_error'] as String?,
    );
  }
}

class SyncQueue {
  const SyncQueue();

  Future<int> enqueue({
    required DatabaseExecutor executor,
    required String entity,
    int? recordId,
    required String operation,
    Map<String, Object?>? payload,
  }) async {
    if (entity.trim().isEmpty) {
      throw ArgumentError.value(entity, 'entity', 'No puede estar vacío.');
    }
    if (operation.trim().isEmpty) {
      throw ArgumentError.value(
        operation,
        'operation',
        'No puede estar vacío.',
      );
    }
    if (recordId != null && recordId <= 0) {
      throw ArgumentError.value(
        recordId,
        'recordId',
        'Debe ser un entero positivo.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    return executor.insert('sincronizacion', {
      'tabla': entity,
      'registro_id': recordId,
      'operacion': operation,
      'estado': 'pendiente',
      'payload_json': payload == null ? null : jsonEncode(payload),
      'intentos': 0,
      'fecha_creacion': now,
      'fecha_actualizacion': now,
    });
  }

  Future<List<SyncQueueEntry>> pending({int limit = 50}) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Debe ser mayor que cero.');
    }

    final db = await AvaMovilDatabase.instance.database;
    final rows = await db.query(
      'sincronizacion',
      where: 'estado IN (?, ?)',
      whereArgs: ['pendiente', 'error'],
      orderBy: 'fecha_creacion ASC, id ASC',
      limit: limit,
    );
    return rows
        .map((row) => SyncQueueEntry.fromMap(row))
        .toList(growable: false);
  }

  Future<void> markSynced(int id) async {
    final db = await AvaMovilDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await db.update(
      'sincronizacion',
      {
        'estado': 'sincronizado',
        'fecha_sincronizacion': now,
        'fecha_actualizacion': now,
        'ultimo_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _requireExistingEntry(updated, id);
  }

  Future<void> markFailed(int id, Object error) async {
    final db = await AvaMovilDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await db.rawUpdate(
      '''
      UPDATE sincronizacion
      SET estado = ?,
          intentos = intentos + 1,
          fecha_actualizacion = ?,
          ultimo_error = ?
      WHERE id = ? AND estado != ?
      ''',
      ['error', now, error.toString(), id, 'sincronizado'],
    );

    if (updated == 0) {
      final entry = await db.query(
        'sincronizacion',
        columns: ['estado'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (entry.isEmpty) {
        throw StateError('No existe el cambio de sincronización $id.');
      }
      throw StateError('El cambio de sincronización $id ya fue completado.');
    }
  }

  void _requireExistingEntry(int updated, int id) {
    if (updated == 0) {
      throw StateError('No existe el cambio de sincronización $id.');
    }
  }
}
