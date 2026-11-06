import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  final http.Client _client;
  final String _baseUrl;
  final String? accessToken;
  final Duration timeout;

  ApiService({
    http.Client? client,
    String? baseUrl,
    this.accessToken,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? configuredBaseUrl {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Debe ser positivo.');
    }
  }

  /// Traduce `EstadoEvento` de Laravel a los estados que maneja la app.
  ///
  /// `en_revision` cuenta como abierta porque el evento sigue pendiente de
  /// cierre, igual que en el filtro "abierto" del backend. Se aceptan también
  /// los valores antiguos que pueden seguir en la caché offline.
  static String estadoParaApp(Object? estado) {
    final valor = estado.toString().toLowerCase();
    return switch (valor) {
      'abierto' || 'abierta' || 'en_revision' || 'proceso' => 'ABIERTA',
      'cerrado' || 'cerrada' => 'CERRADA',
      _ => valor.toUpperCase(),
    };
  }

  /// URL de una evidencia privada. Requiere enviar el token en la cabecera.
  static Uri urlArchivoEvento(
    int idEvento,
    String ruta, {
    String baseUrl = configuredBaseUrl,
  }) {
    final archivo = Uri.encodeComponent(ruta.split(RegExp(r'[/\\]')).last);
    return _resolver(baseUrl, 'eventos/$idEvento/archivos/$archivo');
  }

  Future<void> cerrarSesion() async {
    final response = await _client
        .post(_endpoint('logout'), headers: _headers())
        .timeout(timeout);

    _decodeResponse(response);
  }

  Future<Map<String, dynamic>> obtenerEvento(int idEvento) async {
    final response = await _client
        .get(_endpoint('eventos/$idEvento'), headers: _headers())
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! Map<String, dynamic>) {
      throw const FormatException('Laravel no devolvió un evento válido.');
    }

    return body;
  }

  Future<String> iniciarSesion({
    required String rut,
    required String password,
  }) async {
    final response = await _client
        .post(
          _endpoint('login'),
          headers: {..._headers(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'rut': rut.trim(),
            'password': password,
            'device_name': 'ava_movil',
          }),
        )
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! Map ||
        body['access_token'] is! String ||
        (body['access_token'] as String).isEmpty) {
      throw const FormatException('Laravel no devolvió un token válido.');
    }

    return body['access_token'] as String;
  }

  Future<List<dynamic>> obtenerProyectos() async {
    final response = await _client
        .get(_endpoint('proyectos'), headers: _headers())
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! List) {
      throw const FormatException(
        'La respuesta de proyectos debe ser una lista JSON.',
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> obtenerOpcionesEventos() async {
    final response = await _client
        .get(_endpoint('eventos/opciones'), headers: _headers())
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! Map<String, dynamic>) {
      throw const FormatException(
        'Las opciones de eventos deben ser un objeto JSON.',
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> obtenerUsuarioAutenticado() async {
    final response = await _client
        .get(_endpoint('user'), headers: _headers())
        .timeout(timeout);

    final body = _decodeResponse(response);
    final data = body is Map && body['data'] is Map ? body['data'] : body;
    final usuario = data is Map && data['user'] is Map ? data['user'] : data;

    if (usuario is! Map) {
      throw const FormatException(
        'Laravel debe devolver el perfil del usuario autenticado.',
      );
    }

    return Map<String, dynamic>.from(usuario);
  }

  Future<List<dynamic>> obtenerEventos() async {
    final response = await _client
        .get(_endpoint('eventos'), headers: _headers())
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! List) {
      throw const FormatException(
        'Laravel debe devolver una lista de eventos.',
      );
    }

    return body;
  }

  Future<List<dynamic>> obtenerMisReportes() async {
    final response = await _client
        .get(_endpoint('eventos/mis-reportes'), headers: _headers())
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! List) {
      throw const FormatException(
        'Laravel debe devolver una lista de mis reportes.',
      );
    }

    return body;
  }

  Future<List<dynamic>> obtenerReportesMiCuadrilla() async {
    final response = await _client
        .get(_endpoint('eventos/mi-cuadrilla'), headers: _headers())
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! List) {
      throw const FormatException(
        'Laravel debe devolver una lista de reportes de la cuadrilla.',
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> cerrarEvento({
    required int idEvento,
    required String justificacion,
  }) async {
    final texto = justificacion.trim();

    if (texto.isEmpty || texto.length > 500) {
      throw ArgumentError(
        'La justificación debe tener entre 1 y 500 caracteres.',
      );
    }

    final response = await _client
        .patch(
          _endpoint('eventos/$idEvento/cerrar'),
          headers: {..._headers(), 'Content-Type': 'application/json'},
          body: jsonEncode({'justificacion': texto}),
        )
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! Map<String, dynamic>) {
      throw const FormatException('Laravel no devolvió un evento válido.');
    }

    return body;
  }

  Future<Map<String, dynamic>> registrarEvento({
    required int idTipoEvento,
    required int condicion,
    required String descripcion,
    required String referencia,
    required int idProyecto,
    required bool esParaMi,
    int? idTrabajador,
    int? idArea,
    List<XFile> evidencias = const [],
  }) async {
    if (evidencias.length > 3) {
      throw ArgumentError('Se permiten máximo 3 evidencias.');
    }

    if (!esParaMi && idTrabajador == null) {
      throw ArgumentError('Debe seleccionar a la persona reportada.');
    }

    final request = http.MultipartRequest('POST', _endpoint('eventos'));

    request.headers.addAll(_headers());

    request.fields.addAll({
      'id_tipo_evento': idTipoEvento.toString(),
      'condicion': condicion.toString(),
      'descripcion': descripcion.trim(),
      'referencia': referencia.trim(),
      'id_proyecto': idProyecto.toString(),
      'es_para_mi': esParaMi ? '1' : '0',
      if (!esParaMi && idTrabajador != null)
        'id_trabajador': idTrabajador.toString(),
      if (idArea != null) 'id_area': idArea.toString(),
    });

    for (final evidencia in evidencias) {
      final bytes = await evidencia.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {
        throw ArgumentError('Cada evidencia debe pesar máximo 5 MB.');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'evidencia[]',
          bytes,
          filename: evidencia.name,
        ),
      );
    }

    final streamedResponse = await _client.send(request).timeout(timeout);

    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(timeout);

    final body = _decodeResponse(response);

    if (response.statusCode != 201 ||
        body is! Map<String, dynamic> ||
        body['id_evento'] is! int) {
      throw const FormatException(
        'Laravel no confirmó correctamente el registro.',
      );
    }

    return body;
  }

  Map<String, String> _baseHeaders() {
    return {
      'Accept': 'application/json',
      if (accessToken != null && accessToken!.trim().isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, String> _headers() {
    final headers = _baseHeaders()..remove('Authorization');
    final token = accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _endpoint(String resource) => _resolver(_baseUrl, resource);

  static Uri _resolver(String baseUrl, String resource) {
    final configuredUrl = baseUrl.trim();

    if (configuredUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL no está configurada. '
        'Inicia la aplicación con '
        '--dart-define=API_BASE_URL=https://localhost:8080/api/v1/',
      );
    }

    final uri = Uri.tryParse(
      configuredUrl.endsWith('/') ? configuredUrl : '$configuredUrl/',
    );

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Debe ser una URL HTTP(S) sin credenciales, '
            'query ni fragmento.',
      );
    }

    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('La API de producción debe utilizar HTTPS.');
    }

    return uri.resolve(resource);
  }

  Object? _decodeResponse(http.Response response) {
    Object? body;

    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          rethrow;
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map && body['message'] is String
          ? body['message'] as String
          : 'La solicitud a la API falló.';

      throw ApiException(statusCode: response.statusCode, message: message);
    }

    return body;
  }

  void close() {
    _client.close();
  }
}
