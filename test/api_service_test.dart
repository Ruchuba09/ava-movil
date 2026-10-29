
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/services/api_service.dart';

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
      final clienteSimulado = MockClient((request) async {
        return http.Response(
          '{"message":"Unauthenticated."}',
          401,
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
  });
}
