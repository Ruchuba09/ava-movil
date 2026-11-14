import 'dart:io';

import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/conectividad.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Guarda en el teléfono las fotos de evidencia de los reportes para poder
/// verlas sin conexión.
class EvidenceCache {
  EvidenceCache({this._manager, Future<void> Function(Duration)? esperar})
    : _esperar = esperar ?? Future<void>.delayed;

  static final EvidenceCache instance = EvidenceCache();

  /// Se precargan las fotos de los reportes más recientes, con un tope de
  /// archivos para no llenar el teléfono.
  static const int maxReportes = 50;
  static const int maxArchivos = 150;

  /// Laravel permite 60 peticiones por minuto: se deja margen para la app.
  static const Duration pausaEntreArchivos = Duration(milliseconds: 1500);

  CacheManager? _manager;
  final Future<void> Function(Duration) _esperar;
  bool _descargando = false;

  CacheManager get _cache => _manager ??= CacheManager(
    Config(
      'ava_evidencias',
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 500,
    ),
  );

  static final RegExp _imagen = RegExp(
    r'\.(jpe?g|png|gif|bmp|webp)$',
    caseSensitive: false,
  );

  static bool esImagen(String ruta) =>
      _imagen.hasMatch(Uri.tryParse(ruta)?.path ?? ruta);

  /// Rutas de evidencia tal como vienen de Laravel (texto, mapa o lista).
  static List<String> normalizar(dynamic valor) {
    if (valor == null) return [];
    if (valor is String) {
      final texto = valor.trim();
      return texto.isEmpty ? [] : [texto];
    }
    if (valor is Map) {
      final archivo = valor['archivo'] ?? valor['ruta'] ?? valor['path'];
      return archivo is String && archivo.trim().isNotEmpty ? [archivo] : [];
    }
    if (valor is List) return valor.expand(normalizar).toList();
    return [];
  }

  static bool esRemota(String ruta) {
    final uri = Uri.tryParse(ruta);
    return (uri?.scheme == 'http' || uri?.scheme == 'https') ||
        ruta.startsWith('/storage/') ||
        ruta.startsWith('storage/');
  }

  /// URL absoluta de una evidencia remota, o `null` si no se puede armar.
  static Uri? uriRemota(String ruta) {
    final uri = Uri.tryParse(ruta);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
    }

    final baseUri = Uri.tryParse(ApiService.configuredBaseUrl);
    if (baseUri == null ||
        !baseUri.hasAuthority ||
        (baseUri.scheme != 'http' && baseUri.scheme != 'https')) {
      return null;
    }

    final serverRoot = baseUri.replace(path: '/', query: null, fragment: null);
    return serverRoot.resolve(ruta.startsWith('/') ? ruta.substring(1) : ruta);
  }

  /// Laravel guarda rutas del disco privado; se sirven desde la API con token.
  static List<String> urlsDelServidor(Object? idEvento, List<String> rutas) {
    if (idEvento is! int || ApiService.configuredBaseUrl.trim().isEmpty) {
      return rutas;
    }
    return rutas
        .map(
          (ruta) => esRemota(ruta)
              ? ruta
              : ApiService.urlArchivoEvento(idEvento, ruta).toString(),
        )
        .toList();
  }

  Map<String, String>? _headers(String? token) {
    final limpio = token?.trim();
    return limpio == null || limpio.isEmpty
        ? null
        : {'Authorization': 'Bearer $limpio'};
  }

  /// Archivo guardado de [url]; si no está y hay conexión, lo descarga.
  /// Devuelve `null` si no está guardado y no hay conexión.
  Future<File?> archivo(String url, {String? accessToken}) async {
    final guardado = await _cache.getFileFromCache(url);
    if (guardado != null) return guardado.file;
    if (Conectividad.instance.sinConexion) return null;

    try {
      final info = await _cache.downloadFile(
        url,
        authHeaders: _headers(accessToken),
      );
      Conectividad.instance.reportarRespuesta();
      return info.file;
    } catch (error) {
      Conectividad.instance.reportarFalla(error);
      rethrow;
    }
  }

  /// Precarga las fotos de los reportes guardados para uso sin conexión.
  /// Corre en segundo plano y se detiene si se pierde la conexión.
  Future<void> descargarDeReportes({
    required String userKey,
    required List<String> claves,
    required String accessToken,
  }) async {
    if (kIsWeb || _descargando || accessToken.trim().isEmpty) return;
    _descargando = true;
    try {
      final urls = await urlsParaPrecargar(userKey: userKey, claves: claves);
      for (final url in urls) {
        if (Conectividad.instance.sinConexion) break;
        if (await _cache.getFileFromCache(url) != null) continue;
        try {
          await _cache.downloadFile(url, authHeaders: _headers(accessToken));
        } catch (error) {
          if (Conectividad.esFallaDeRed(error)) {
            Conectividad.instance.reportarFalla(error);
            break;
          }
          debugPrint('No se pudo guardar la evidencia $url: $error');
        }
        await _esperar(pausaEntreArchivos);
      }
    } catch (error) {
      debugPrint('No se pudieron precargar evidencias: $error');
    } finally {
      _descargando = false;
    }
  }

  /// URLs de las fotos de los [maxReportes] reportes más recientes.
  static Future<List<String>> urlsParaPrecargar({
    required String userKey,
    required List<String> claves,
    OfflineStore? store,
  }) async {
    final offlineStore = store ?? OfflineStore();
    final eventos = <Map>[];
    for (final clave in claves) {
      final lista = await offlineStore.readJsonList(
        userKey: userKey,
        key: clave,
      );
      eventos.addAll(lista?.whereType<Map>() ?? const []);
    }
    eventos.sort(
      (a, b) => (b['fecha_creacion']?.toString() ?? '').compareTo(
        a['fecha_creacion']?.toString() ?? '',
      ),
    );

    final urls = <String>{};
    final vistos = <Object?>{};
    for (final evento in eventos) {
      if (!vistos.add(evento['id_evento'])) continue;
      if (vistos.length > maxReportes) break;
      final rutas = [
        ...normalizar(evento['evidencia']),
        ...normalizar(evento['evidencia_cierre']),
      ].where(esImagen).toList();
      for (final ruta in urlsDelServidor(evento['id_evento'], rutas)) {
        final uri = esRemota(ruta) ? uriRemota(ruta) : null;
        if (uri != null) urls.add(uri.toString());
        if (urls.length >= maxArchivos) return urls.toList();
      }
    }
    return urls.toList();
  }
}
