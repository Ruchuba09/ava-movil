import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Lanzada en vez de llamar a Laravel cuando ya se sabe que no hay conexión,
/// para que la pantalla use los datos guardados sin esperar un timeout.
class SinConexionException implements Exception {
  const SinConexionException();

  @override
  String toString() => 'Sin conexión con el servidor.';
}

/// Estado de la conexión con Laravel, compartido por toda la app.
///
/// Combina dos señales: si el teléfono tiene red (connectivity_plus) y si la
/// última petición a Laravel falló por red. Lo segundo cubre la señal débil o
/// el Wi-Fi sin internet, donde el teléfono "tiene red" pero nada responde.
class Conectividad extends ChangeNotifier {
  Conectividad({this._connectivity, DateTime Function()? ahora})
    : _ahora = ahora ?? DateTime.now;

  static final Conectividad instance = Conectividad();

  /// Tras una falla de red se asume el servidor caído durante este tiempo, y
  /// después se vuelve a probar (lo que dispara la sincronización).
  static const Duration esperaTrasFalla = Duration(minutes: 2);

  Connectivity? _connectivity;
  final DateTime Function() _ahora;
  StreamSubscription<List<ConnectivityResult>>? _suscripcion;
  Timer? _reintento;

  bool _hayRed = true;
  DateTime? _servidorCaidoHasta;
  bool _ultimoEstado = false;

  /// `true` si no conviene llamar a Laravel ahora.
  bool get sinConexion =>
      !_hayRed ||
      (_servidorCaidoHasta != null && _ahora().isBefore(_servidorCaidoHasta!));

  /// Empieza a escuchar los cambios de red. Se puede llamar varias veces.
  Future<void> iniciar() async {
    if (_suscripcion != null || kIsWeb) return;
    final connectivity = _connectivity ??= Connectivity();
    try {
      _actualizarRed(await connectivity.checkConnectivity());
      _suscripcion = connectivity.onConnectivityChanged.listen(_actualizarRed);
    } catch (error) {
      debugPrint('No se pudo consultar el estado de la red: $error');
    }
  }

  void _actualizarRed(List<ConnectivityResult> resultados) {
    _hayRed = resultados.any((r) => r != ConnectivityResult.none);
    // Una red nueva merece un intento inmediato, aunque el servidor haya
    // fallado hace poco con la red anterior.
    if (_hayRed) _servidorCaidoHasta = null;
    _notificarSiCambia();
  }

  /// Laravel respondió (aunque sea con un error HTTP): hay conexión.
  void reportarRespuesta() {
    if (_servidorCaidoHasta == null) return;
    _servidorCaidoHasta = null;
    _reintento?.cancel();
    _notificarSiCambia();
  }

  /// La petición no llegó a Laravel. Otros errores se ignoran.
  void reportarFalla(Object error) {
    if (!esFallaDeRed(error)) return;
    _servidorCaidoHasta = _ahora().add(esperaTrasFalla);
    _reintento?.cancel();
    _reintento = Timer(esperaTrasFalla, _notificarSiCambia);
    _notificarSiCambia();
  }

  static bool esFallaDeRed(Object error) =>
      error is SinConexionException ||
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is TlsException;

  void _notificarSiCambia() {
    final estado = sinConexion;
    if (estado == _ultimoEstado) return;
    _ultimoEstado = estado;
    notifyListeners();
  }

  /// Lanza [SinConexionException] si no conviene llamar a Laravel.
  void exigirConexion() {
    if (sinConexion) throw const SinConexionException();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _reintento?.cancel();
    super.dispose();
  }
}

/// Cliente HTTP que informa a [Conectividad] de cada respuesta o falla de red.
class ClienteConConectividad extends http.BaseClient {
  ClienteConConectividad(this._inner, this._timeout, {Conectividad? estado})
    : _estado = estado ?? Conectividad.instance;

  final http.Client _inner;
  final Duration _timeout;
  final Conectividad _estado;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final response = await _inner.send(request).timeout(_timeout);
      _estado.reportarRespuesta();
      return response;
    } catch (error) {
      _estado.reportarFalla(error);
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}
