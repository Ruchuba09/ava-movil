import 'dart:convert';

import 'package:avamovil/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requests projects below the configured API path', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      expect(request.headers['Accept'], 'application/json');
      return http.Response(jsonEncode([]), 200);
    });
    final service = ApiService(
      client: client,
      baseUrl: 'https://example.test/v1/api',
    );

    expect(await service.obtenerProyectos(), isEmpty);
    expect(requestedUri, Uri.https('example.test', '/v1/api/proyectos'));
    service.close();
  });

  test('surfaces HTTP errors returned by the API', () async {
    final service = ApiService(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'No autorizado'}), 401),
      ),
      baseUrl: 'https://example.test/api',
    );

    await expectLater(
      service.obtenerProyectos(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', 'No autorizado'),
      ),
    );
    service.close();
  });

  test('rejects a successful response with an unexpected JSON shape', () async {
    final service = ApiService(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'data': []}), 200),
      ),
      baseUrl: 'https://example.test/api',
    );

    await expectLater(service.obtenerProyectos(), throwsFormatException);
    service.close();
  });

  test('fails clearly when the API base URL is missing', () async {
    final service = ApiService(
      client: MockClient((_) async => http.Response('[]', 200)),
      baseUrl: '',
    );

    await expectLater(service.obtenerProyectos(), throwsStateError);
    service.close();
  });
}
