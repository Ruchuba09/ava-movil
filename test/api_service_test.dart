
import 'dart:convert';

import 'package:avamovil/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

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
    
    test('Inicia sesión y obtiene un token de Laravel', () async {
      final clienteSimulado = MockClient((request) async {
        expect(request.method, 'POST');

        expect(
          request.url.toString(),
          'https://ejemplo.cl/api/v1/login',
        );

        expect(
          request.headers['Accept'],
          'application/json',
        );

        expect(
          request.headers['Content-Type'],
          contains('application/json'),
        );

        
        expect(
          request.headers['Content-Type'],
          contains('application/json'),
        );

        
        final datos = jsonDecode(request.body);

        expect(datos['rut'], 'admin@empresa.cl');
        expect(datos['password'], 'clave_de_prueba');
        expect(datos['device_name'], 'ava_movil');



        return http.Response(
          jsonEncode({
            'token_type': 'Bearer',
            'access_token': 'token_simulado_123',
          }),
          200,
          headers: {
            'content-type': 'application/json',
          },
        );
      });

      final servicio = ApiService(
        client: clienteSimulado,
        baseUrl: 'https://ejemplo.cl/api/v1/',
      );

      try {
        final token = await servicio.iniciarSesion(
          rut: 'admin@empresa.cl',
          password: 'clave_de_prueba',
        );

        expect(token, 'token_simulado_123');
      } finally {
        servicio.close();
      }
    });

    test('Obtiene el perfil autenticado de Laravel', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, Uri.https('example.test', '/api/user'));
        expect(request.headers['Authorization'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'id': 17,
            'name': 'Trabajador de prueba',
            'email': 'trabajador@example.test',
            'role': {'name': 'TRABAJADOR'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiService(
        client: client,
        baseUrl: 'https://example.test/api',
        accessToken: 'token_prueba',
      );

      try {
        final user = await service.obtenerUsuarioAutenticado();
        expect(user['id'], 17);
        expect(user['name'], 'Trabajador de prueba');
        expect((user['role'] as Map)['name'], 'TRABAJADOR');
      } finally {
        service.close();
      }
    });

    
    test('Obtiene las opciones reales para crear eventos', () async {
      final clienteSimulado = MockClient((request) async {
        expect(request.method, 'GET');

        expect(
          request.url.toString(),
          'https://ejemplo.cl/api/v1/eventos/opciones',
        );

        expect(
          request.headers['Authorization'],
          'Bearer token_prueba',
        );

        return http.Response(
          jsonEncode({
            'tiposEvento': [
              {
                'id_tipo_evento': 5,
                'nombre': 'Observacion preventiva',
              }
            ],
            'usuarioTrabajador': null,
            'trabajadores': [],
            'proyectos': [
              {
                'id_proyecto': 1,
                'nombre': 'Montaje Planta Norte',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final servicio = ApiService(
        client: clienteSimulado,
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final opciones = await servicio.obtenerOpcionesEventos();

        expect(opciones['tiposEvento'], isA<List>());
        expect(opciones['trabajadores'], isA<List>());
        expect(opciones['proyectos'], isA<List>());
        expect(opciones['proyectos'][0]['id_proyecto'], 1);
      } finally {
        servicio.close();
      }
    });
  
    test('Registra un evento y recibe el ID de Laravel', () async {
      final clienteSimulado = MockClient((request) async {
        expect(request.method, 'POST');

        expect(
          request.url.toString(),
          'https://ejemplo.cl/api/v1/eventos',
        );

        expect(
          request.headers['Authorization'],
          'Bearer token_prueba',
        );

        
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );

        final cuerpo = request.body;

        expect(cuerpo, contains('name="id_tipo_evento"'));
        expect(cuerpo, contains('name="condicion"'));
        expect(cuerpo, contains('name="id_proyecto"'));
        expect(cuerpo, contains('name="es_para_mi"'));
        expect(cuerpo, contains('Sector de mantenimiento'));


        return http.Response(
          jsonEncode({
            'id_evento': 123,
            'id_tipo_evento': 4,
            'condicion': 1,
            'id_proyecto': 1,
            'estado': 'abierta',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final servicio = ApiService(
        client: clienteSimulado,
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final evento = await servicio.registrarEvento(
          idTipoEvento: 4,
          condicion: 1,
          descripcion: 'Condición insegura detectada',
          referencia: 'Sector de mantenimiento',
          idProyecto: 1,
          esParaMi: true,
        );

        expect(evento['id_evento'], 123);
        expect(evento['estado'], 'abierta');
      } finally {
        servicio.close();
      }
    });
    
    test('Envía evidencia adjunta al registrar un evento', () async {
      final clienteSimulado = MockClient((request) async {
        expect(request.method, 'POST');

        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );

        final cuerpo = request.body;

        expect(cuerpo, contains('name="evidencia[]"'));
        expect(cuerpo, contains('filename="foto_prueba.jpg"'));
        expect(cuerpo, contains('contenido_simulado'));

        return http.Response(
          jsonEncode({
            'id_evento': 124,
            'estado': 'abierta',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final servicio = ApiService(
        client: clienteSimulado,
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final evento = await servicio.registrarEvento(
          idTipoEvento: 4,
          condicion: 1,
          descripcion: 'Evidencia de prueba',
          referencia: 'Sector de mantenimiento',
          idProyecto: 1,
          esParaMi: true,
          evidencias: [
            XFile.fromData(
              utf8.encode('contenido_simulado'),
              name: 'foto_prueba.jpg',
              mimeType: 'image/jpeg',
              path: 'foto_prueba.jpg',
),
          ],
        );

        expect(evento['id_evento'], 124);
      } finally {
        servicio.close();
      }
    });

    
    test('Obtiene el listado de eventos desde Laravel', () async {
      final clienteSimulado = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://ejemplo.cl/api/v1/eventos?estado=abierto&page=2&per_page=30',
        );
        expect(
          request.headers['Authorization'],
          'Bearer token_prueba',
        );

        return http.Response(
          jsonEncode({
            'data': [
              {
                'id_evento': 501,
                'id_proyecto': 1,
                'condicion': 1,
                'referencia': 'PRUEBA INTEGRACIÓN AVA MÓVIL',
                'estado': 'abierta',
              },
            ],
            'current_page': 2,
            'last_page': 3,
            'total': 61,
            'proyectos': [
              {'id_proyecto': 1, 'nombre': 'Montaje Planta Norte'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final servicio = ApiService(
        client: clienteSimulado,
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final pagina = await servicio.obtenerEventos(
          pagina: 2,
          filtros: {'estado': 'abierto'},
        );

        expect(pagina.eventos.length, 1);
        expect(pagina.eventos.first['id_evento'], 501);
        expect(pagina.total, 61);
        expect(pagina.hayMas, isTrue);
        expect(pagina.proyectos.first['id_proyecto'], 1);
      } finally {
        servicio.close();
      }
    });

    test('Construye la URL de una evidencia privada solo con su nombre', () {
      expect(
        ApiService.urlArchivoEvento(
          7,
          'evidencias/foto 1.jpg',
          baseUrl: 'https://ejemplo.cl/api/v1/',
        ).toString(),
        'https://ejemplo.cl/api/v1/eventos/7/archivos/foto%201.jpg',
      );
    });

    test('Obtiene los reportes de la cuadrilla', () async {
      final servicio = ApiService(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://ejemplo.cl/api/v1/eventos/mi-cuadrilla?page=1&per_page=30',
          );
          return http.Response(jsonEncode({'data': []}), 200);
        }),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final pagina = await servicio.obtenerReportesMiCuadrilla();
        expect(pagina.eventos, isEmpty);
        expect(pagina.hayMas, isFalse);
      } finally {
        servicio.close();
      }
    });

    test('Obtiene un evento por su ID', () async {
      final servicio = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://ejemplo.cl/api/v1/eventos/501',
          );
          return http.Response(
            jsonEncode({'id_evento': 501, 'estado': 'en_revision'}),
            200,
          );
        }),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final evento = await servicio.obtenerEvento(501);
        expect(evento['id_evento'], 501);
      } finally {
        servicio.close();
      }
    });

    test('Cierra la sesión enviando el token', () async {
      final servicio = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://ejemplo.cl/api/v1/logout');
          expect(request.headers['Authorization'], 'Bearer token_prueba');
          return http.Response(
            jsonEncode({'message': 'Sesión cerrada correctamente.'}),
            200,
          );
        }),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        await servicio.cerrarSesion();
      } finally {
        servicio.close();
      }
    });

    test('Envía el área al registrar un evento', () async {
      final servicio = ApiService(
        client: MockClient((request) async {
          expect(request.body, contains('name="id_area"'));
          return http.Response(jsonEncode({'id_evento': 125}), 201);
        }),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final evento = await servicio.registrarEvento(
          idTipoEvento: 4,
          condicion: 1,
          descripcion: 'Evento con área',
          referencia: 'Sector de mantenimiento',
          idProyecto: 1,
          esParaMi: true,
          idArea: 7,
        );
        expect(evento['id_evento'], 125);
      } finally {
        servicio.close();
      }
    });

    test('Cierra un evento con reinicio y evidencia de cierre', () async {
      final servicio = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://ejemplo.cl/api/v1/eventos/9/cerrar',
          );
          final cuerpo = request.body;
          expect(cuerpo, contains('name="_method"'));
          expect(cuerpo, contains('PATCH'));
          expect(cuerpo, contains('name="justificacion"'));
          expect(cuerpo, contains('name="fecha_reinicio"'));
          expect(cuerpo, contains('2026-11-05T15:30:00.000Z'));
          expect(cuerpo, contains('name="evidencia_cierre[]"'));
          expect(cuerpo, contains('filename="cierre.pdf"'));
          return http.Response(jsonEncode({'estado': 'cerrado'}), 200);
        }),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        final evento = await servicio.cerrarEvento(
          idEvento: 9,
          justificacion: 'Área asegurada',
          fechaReinicio: DateTime.utc(2026, 11, 5, 15, 30),
          evidencias: [XFile.fromData(utf8.encode('pdf'), path: 'cierre.pdf')],
        );
        expect(ApiService.estadoParaApp(evento['estado']), 'CERRADA');
      } finally {
        servicio.close();
      }
    });

    test('Rechaza antes de enviar los archivos que Laravel no acepta', () async {
      final servicio = ApiService(
        client: MockClient((_) async => fail('No debe llegar al servidor')),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        for (final nombre in ['foto.webp', 'video.mp4', 'foto.heic', 'sin_ext']) {
          await expectLater(
            servicio.cerrarEvento(
              idEvento: 9,
              justificacion: 'Prueba',
              evidencias: [XFile.fromData(utf8.encode('x'), path: nombre)],
            ),
            throwsArgumentError,
            reason: nombre,
          );
        }
      } finally {
        servicio.close();
      }
    });

    test('Descarga un archivo con el token y sin decodificarlo', () async {
      final bytes = [0x25, 0x50, 0x44, 0x46, 0xFF, 0x00];
      final servicio = ApiService(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token_prueba');
          return http.Response.bytes(bytes, 200);
        }),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        expect(
          await servicio.descargarArchivo(
            Uri.parse('https://ejemplo.cl/api/v1/eventos/1/archivos/a.pdf'),
          ),
          bytes,
        );
      } finally {
        servicio.close();
      }
    });

    test('Informa el error al descargar un archivo', () async {
      final servicio = ApiService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'message': 'Sin permiso'}), 403),
        ),
        baseUrl: 'https://ejemplo.cl/api/v1/',
        accessToken: 'token_prueba',
      );

      try {
        await expectLater(
          servicio.descargarArchivo(Uri.parse('https://ejemplo.cl/a.pdf')),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
      } finally {
        servicio.close();
      }
    });

    test('Traduce los estados de Laravel a los de la app', () {
      expect(ApiService.estadoParaApp('abierto'), 'ABIERTA');
      expect(ApiService.estadoParaApp('en_revision'), 'ABIERTA');
      expect(ApiService.estadoParaApp('cerrado'), 'CERRADA');
      expect(ApiService.estadoParaApp('cerrada'), 'CERRADA');
    });

  });
}
