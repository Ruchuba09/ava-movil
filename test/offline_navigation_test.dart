import 'dart:convert';
import 'dart:io';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/database/sync_queue.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/conectividad.dart';
import 'package:avamovil/services/evidence_cache.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:avamovil/services/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory databaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'avamovil-offline-navigation-test-',
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

  group('Conectividad', () {
    test('una falla de red marca sin conexión por 2 minutos', () {
      var ahora = DateTime(2026, 11, 13, 9);
      final estado = Conectividad(ahora: () => ahora);
      var avisos = 0;
      estado.addListener(() => avisos++);

      expect(estado.sinConexion, isFalse);
      estado.reportarFalla(const SocketException('sin red'));
      expect(estado.sinConexion, isTrue);
      expect(avisos, 1);
      expect(estado.exigirConexion, throwsA(isA<SinConexionException>()));

      ahora = ahora.add(Conectividad.esperaTrasFalla);
      expect(estado.sinConexion, isFalse);
      estado.dispose();
    });

    test('una respuesta de Laravel restablece la conexión', () {
      final estado = Conectividad();
      estado.reportarFalla(const SocketException('sin red'));
      estado.reportarRespuesta();
      expect(estado.sinConexion, isFalse);
      estado.dispose();
    });

    test('los errores HTTP no cuentan como falta de conexión', () {
      final estado = Conectividad();
      estado.reportarFalla(const ApiException(statusCode: 500, message: 'x'));
      expect(estado.sinConexion, isFalse);
      estado.dispose();
    });

    test('el cliente HTTP informa fallas y respuestas', () async {
      final estado = Conectividad();
      var falla = true;
      final cliente = ClienteConConectividad(
        MockClient((request) async {
          if (falla) throw http.ClientException('sin red');
          return http.Response('{}', 200);
        }),
        const Duration(seconds: 5),
        estado: estado,
      );

      await expectLater(
        cliente.get(Uri.https('example.test', '/api/user')),
        throwsA(isA<http.ClientException>()),
      );
      expect(estado.sinConexion, isTrue);

      falla = false;
      await cliente.get(Uri.https('example.test', '/api/user'));
      expect(estado.sinConexion, isFalse);
      estado.dispose();
    });
  });

  test('sincroniza un cierre de evento hecho sin conexión', () async {
    final db = await AvaMovilDatabase.instance.database;
    const queue = SyncQueue();
    await queue.enqueue(
      executor: db,
      entity: 'eventos',
      recordId: 55,
      operation: 'cerrar',
      payload: {
        'user_key': 'one@example.test',
        'id_evento': 55,
        'justificacion': 'Se corrigió la condición',
        'evidencias': const [],
      },
    );
    await queue.enqueue(
      executor: db,
      entity: 'eventos',
      recordId: 56,
      operation: 'cerrar',
      payload: {
        'user_key': 'two@example.test',
        'id_evento': 56,
        'justificacion': 'Otro usuario',
        'evidencias': const [],
      },
    );

    expect(
      await OfflineStore().pendingClosures('one@example.test'),
      hasLength(1),
    );

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.https('example.test', '/api/eventos/55/cerrar'));
      expect(request.headers['Authorization'], 'Bearer cached-token');
      final body = utf8.decode(request.bodyBytes, allowMalformed: true);
      expect(body, contains('PATCH'));
      expect(body, contains('Se corrigió la condición'));
      return http.Response(
        jsonEncode({'id_evento': 55, 'estado': 'cerrado'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await OfflineSyncService(
      client: client,
      baseUrl: 'https://example.test/api',
    ).synchronize(userKey: 'one@example.test', accessToken: 'cached-token');

    expect(result.synchronized, 1);
    expect(result.failed, 0);
    expect(await OfflineStore().pendingClosures('one@example.test'), isEmpty);
    expect(
      await OfflineStore().pendingClosures('two@example.test'),
      hasLength(1),
    );
  });

  test('precarga sólo fotos de los reportes más recientes', () async {
    final store = OfflineStore();
    await store.saveJsonList(
      userKey: 'one@example.test',
      key: OfflineStore.myReportsKey,
      value: [
        {
          'id_evento': 1,
          'fecha_creacion': '2026-11-01T10:00:00Z',
          'evidencia': ['https://example.test/viejo.jpg'],
        },
        {
          'id_evento': 2,
          'fecha_creacion': '2026-11-12T10:00:00Z',
          'evidencia': [
            'https://example.test/nuevo.png',
            'https://example.test/informe.pdf',
          ],
          'evidencia_cierre': {'archivo': 'https://example.test/cierre.jpg'},
        },
      ],
    );

    final urls = await EvidenceCache.urlsParaPrecargar(
      userKey: 'one@example.test',
      claves: [OfflineStore.myReportsKey, OfflineStore.teamReportsKey],
    );

    expect(urls, [
      'https://example.test/nuevo.png',
      'https://example.test/cierre.jpg',
      'https://example.test/viejo.jpg',
    ]);
  });
}
