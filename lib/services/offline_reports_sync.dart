import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:flutter/foundation.dart';

/// Estado de la última descarga de reportes para usar sin conexión.
class EstadoSincronizacion {
  final DateTime fecha;
  final bool completa;

  const EstadoSincronizacion({required this.fecha, required this.completa});
}

/// Descarga todos los reportes del usuario para consultarlos sin conexión,
/// aunque nunca haya abierto esas páginas en la lista.
class OfflineReportsSync {
  OfflineReportsSync({
    OfflineStore? store,
    Future<void> Function(Duration)? esperar,
    DateTime Function()? ahora,
  }) : _store = store ?? OfflineStore(),
       _esperar = esperar ?? Future<void>.delayed,
       _ahora = ahora ?? DateTime.now;

  static final OfflineReportsSync instance = OfflineReportsSync();

  static const int porPagina = 100;

  /// Laravel permite 60 peticiones por minuto: la pausa deja margen para que
  /// la app siga usando la API mientras se descarga un listado largo.
  static const Duration pausaEntrePaginas = Duration(milliseconds: 1500);
  static const Duration intervaloMinimo = Duration(minutes: 15);
  static const int maximoReintentos = 5;

  final OfflineStore _store;
  final Future<void> Function(Duration) _esperar;
  final DateTime Function() _ahora;
  final Set<String> _enCurso = {};

  /// Solo se guarda lo que muestra la lista y el detalle del reporte.
  static const Set<String> _camposEvento = {
    'id_evento',
    'id_proyecto',
    'id_trabajador',
    'id_autor',
    'condicion',
    'condicion_nombre',
    'estado',
    'fecha_creacion',
    'fecha_cierre',
    'referencia',
    'descripcion',
    'justificacion',
    'evidencia',
    'evidencia_cierre',
    'tipo_detencion',
    'fecha_detencion',
  };

  static String _claveEstado(String clave) => '$clave.sincronizacion';

  Future<EstadoSincronizacion?> estado({
    required String userKey,
    required String clave,
  }) async {
    final guardado = await _store.readJson(
      userKey: userKey,
      key: _claveEstado(clave),
    );
    if (guardado is! Map) return null;

    final fecha = DateTime.tryParse(guardado['fecha']?.toString() ?? '');
    if (fecha == null) return null;

    return EstadoSincronizacion(
      fecha: fecha.toLocal(),
      completa: guardado['completa'] == true,
    );
  }

  /// [pedirPagina] debe usar siempre el listado sin filtros.
  /// Devuelve true si la copia local quedó completa y actualizada.
  Future<bool> sincronizar({
    required String userKey,
    required String clave,
    required Future<PaginaEventos> Function(int pagina) pedirPagina,
    bool forzar = false,
  }) async {
    final idProceso = '$userKey/$clave';
    if (!_enCurso.add(idProceso)) return false;

    try {
      if (!forzar) {
        final anterior = await estado(userKey: userKey, clave: clave);
        if (anterior != null &&
            anterior.completa &&
            _ahora().difference(anterior.fecha) < intervaloMinimo) {
          return true;
        }
      }

      final eventos = <dynamic>[];
      try {
        var pagina = 1;
        while (true) {
          final resultado = await _pedirConReintentos(pedirPagina, pagina);
          eventos.addAll(resultado.eventos.map(_compactar));
          if (!resultado.hayMas) break;
          pagina++;
          await _esperar(pausaEntrePaginas);
        }
      } catch (error) {
        debugPrint('Descarga de reportes ($clave) interrumpida: $error');
        // Una descarga a medias no reemplaza una copia completa anterior, pero
        // si es lo único que hay, sirve mejor que no tener nada.
        final anterior = await estado(userKey: userKey, clave: clave);
        if (anterior == null && eventos.isNotEmpty) {
          await _guardar(userKey, clave, eventos, completa: false);
        }
        return false;
      }

      await _guardar(userKey, clave, eventos, completa: true);
      return true;
    } finally {
      _enCurso.remove(idProceso);
    }
  }

  Future<PaginaEventos> _pedirConReintentos(
    Future<PaginaEventos> Function(int pagina) pedirPagina,
    int pagina,
  ) async {
    for (var intento = 0; ; intento++) {
      try {
        return await pedirPagina(pagina);
      } on ApiException catch (error) {
        if (error.statusCode != 429 || intento >= maximoReintentos) rethrow;
        await _esperar(Duration(seconds: error.retryAfter ?? 60));
      }
    }
  }

  Object? _compactar(Object? evento) {
    if (evento is! Map) return evento;

    final proyecto = evento['proyecto'];
    return {
      for (final campo in _camposEvento)
        if (evento[campo] != null) campo: evento[campo],
      if (proyecto is Map)
        'proyecto': {
          'id_proyecto': proyecto['id_proyecto'],
          'nombre': proyecto['nombre'],
        },
    };
  }

  Future<void> _guardar(
    String userKey,
    String clave,
    List<dynamic> eventos, {
    required bool completa,
  }) async {
    await _store.saveJsonList(userKey: userKey, key: clave, value: eventos);
    await _store.saveJson(
      userKey: userKey,
      key: _claveEstado(clave),
      value: {
        'fecha': _ahora().toUtc().toIso8601String(),
        'completa': completa,
        'total': eventos.length,
      },
    );
  }
}
