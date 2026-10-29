
import 'dart:convert';

import 'package:avamovil/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Pruebas de ApiService', () {

    test('Obtiene proyectos desde Laravel', () async {
      final clienteSimulado = MockClient((request) async {
        expect(request.method, 'GET');

        expect(
          request.url.toString(),
          'https://ejemplo.cl/api/v1/proyectos',
        );

        expect(
          request.headers['Authorization'],
          'Bearer token_prueba',
        );

        return http.Response(
          jsonEncode([
            {
              'id_proyecto': 1,
              'nombre': 'Proyecto de prueba',
            }
          ]),
          200,
          headers: {
            'content-type': 'application/json',
          },
        );
      });

      final servicio = ApiService(
        client: clienteSimulado,
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final proyectos = await servicio.obtenerProyectos();

        expect(proyectos.length, 1);
        expect(proyectos.first['id_proyecto'], 1);
        expect(
          proyectos.first['nombre'],
          'Proyecto de prueba',
        );
      } finally {
        servicio.close();
      }
    });

    test('Detecta errores de autenticación', () async {
      final servicio = ApiService(
        client: MockClient(
          (_) async => http.Response(
            '{"message":"Unauthenticated."}',
            401,
          ),
        ),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        await expectLater(
          servicio.obtenerProyectos(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
      } finally {
        servicio.close();
      }
    });

    test('Construye correctamente la URL de proyectos', () async {
      late Uri requestedUri;

      final client = MockClient((request) async {
        requestedUri = request.url;

        expect(
          request.headers['Accept'],
          'application/json',
        );

        return http.Response(jsonEncode([]), 200);
      });

      final service = ApiService(
        client: client,
        baseUrl: 'https://example.test/v1/api',
      );

      try {
        expect(await service.obtenerProyectos(), isEmpty);

        expect(
          requestedUri,
          Uri.https('example.test', '/v1/api/proyectos'),
        );
      } finally {
        service.close();
      }
    });

    test('Muestra el mensaje de error de Laravel', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'No autorizado'}),
            401,
          ),
        ),
        baseUrl: 'https://example.test/api',
      );

      try {
        await expectLater(
          service.obtenerProyectos(),
          throwsA(
            isA<ApiException>()
                .having(
                  (error) => error.statusCode,
                  'statusCode',
                  401,
                )
                .having(
                  (error) => error.message,
                  'message',
                  'No autorizado',
                ),
          ),
        );
      } finally {
        service.close();
      }
    });

    test('Rechaza una estructura JSON inesperada', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'data': []}),
            200,
          ),
        ),
        baseUrl: 'https://example.test/api',
      );

      try {
        await expectLater(
          service.obtenerProyectos(),
          throwsFormatException,
        );
      } finally {
        service.close();
      }
    });

    test('Detecta cuando falta la URL de la API', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response('[]', 200),
        ),
        baseUrl: '',
      );

      try {
        await expectLater(
          service.obtenerProyectos(),
          throwsStateError,
        );
      } finally {
        service.close();
      }
    });

  });
}
