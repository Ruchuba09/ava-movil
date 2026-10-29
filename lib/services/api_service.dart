
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const String configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final String _baseUrl;
  final String? accessToken;
  final Duration timeout;

  ApiService({
    http.Client? client,
    String? baseUrl,
    this.accessToken,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? configuredBaseUrl {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Debe ser positivo.',
      );
    }
  }

  Future<List<dynamic>> obtenerProyectos() async {
    final response = await _client
        .get(
          _endpoint('proyectos'),
          headers: _headers(),
        )
        .timeout(timeout);

    final body = _decodeResponse(response);

    if (body is! List) {
      throw const FormatException(
        'La respuesta de proyectos debe ser una lista JSON.',
      );
    }

    return body;
  }

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      if (accessToken != null &&
          accessToken!.trim().isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  Uri _endpoint(String resource) {
    final configuredUrl = _baseUrl.trim();

    if (configuredUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL no está configurada. '
        'Inicia la aplicación con '
        '--dart-define=API_BASE_URL=https://servidor/api/v1/',
      );
    }

    final uri = Uri.tryParse(
      configuredUrl.endsWith('/')
          ? configuredUrl
          : '$configuredUrl/',
    );

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw ArgumentError.value(
        _baseUrl,
        'baseUrl',
        'Debe ser una URL HTTP(S) sin credenciales, '
        'query ni fragmento.',
      );
    }

    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError(
        'La API de producción debe utilizar HTTPS.',
      );
    }

    return uri.resolve(resource);
  }

  Object? _decodeResponse(http.Response response) {
    Object? body;

    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode >= 200 &&
            response.statusCode < 300) {
          rethrow;
        }
      }
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final message =
          body is Map && body['message'] is String
              ? body['message'] as String
              : 'La solicitud a la API falló.';

      throw ApiException(
        statusCode: response.statusCode,
        message: message,
      );
    }

    return body;
  }

  void close() {
    _client.close();
  }
}
