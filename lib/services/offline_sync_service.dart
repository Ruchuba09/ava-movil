import 'dart:convert';

import 'package:avamovil/database/sync_queue.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class OfflineSyncResult {
  final int synchronized;
  final int failed;

  const OfflineSyncResult({required this.synchronized, required this.failed});
}

class OfflineSyncService {
  final http.Client? client;
  final String? baseUrl;

  const OfflineSyncService({this.client, this.baseUrl});

  Future<OfflineSyncResult> synchronize({
    required String userKey,
    required String accessToken,
  }) async {
    if (userKey.trim().isEmpty || accessToken.trim().isEmpty) {
      throw ArgumentError('Se requiere una sesión válida para sincronizar.');
    }

    final queue = const SyncQueue();
    final entries = await queue.pending(limit: 500);
    final service = ApiService(
      client: client,
      baseUrl: baseUrl,
      accessToken: accessToken,
    );
    var synchronized = 0;
    var failed = 0;

    try {
      for (final entry in entries) {
        if (entry.entity != 'eventos' ||
            entry.operation != 'crear' ||
            entry.payload?['user_key'] != userKey) {
          continue;
        }

        try {
          final payload = entry.payload!;
          final evidences = _decodeEvidence(payload);
          await service.registrarEvento(
            idTipoEvento: _requiredInt(payload, 'id_tipo_evento'),
            condicion: _requiredInt(payload, 'condicion'),
            descripcion: _requiredString(payload, 'descripcion'),
            referencia: _requiredString(payload, 'referencia'),
            idProyecto: _requiredInt(payload, 'id_proyecto'),
            esParaMi: payload['es_para_mi'] == true,
            idTrabajador: payload['id_trabajador'] is num
                ? (payload['id_trabajador'] as num).toInt()
                : null,
            evidencias: evidences,
          );
          await queue.markSynced(entry.id);
          synchronized++;
        } catch (error) {
          await queue.markFailed(entry.id, error);
          failed++;
        }
      }
    } finally {
      service.close();
    }

    return OfflineSyncResult(synchronized: synchronized, failed: failed);
  }

  int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! num) {
      throw FormatException('El campo $key del reporte local no es válido.');
    }
    return value.toInt();
  }

  String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('El campo $key del reporte local no es válido.');
    }
    return value;
  }

  List<XFile> _decodeEvidence(Map<String, Object?> payload) {
    final evidence = payload['evidencias'];
    if (evidence is! List) {
      throw const FormatException('Las evidencias locales no son válidas.');
    }

    return evidence
        .map((item) {
          if (item is! Map ||
              item['name'] is! String ||
              item['bytes_base64'] is! String) {
            throw const FormatException(
              'La evidencia local no contiene nombre y contenido.',
            );
          }
          return XFile.fromData(
            base64Decode(item['bytes_base64'] as String),
            path: item['name'] as String,
          );
        })
        .toList(growable: false);
  }
}
