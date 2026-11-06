import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/view/reports/camera_access.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:avamovil/services/api_service.dart';



class ReportQrScannerScreen extends StatefulWidget {
  final String accessToken;

  const ReportQrScannerScreen({
    super.key,
    required this.accessToken,
  });


  @override
  State<ReportQrScannerScreen> createState() => _ReportQrScannerScreenState();
}

class _ReportQrScannerScreenState extends State<ReportQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    facing: CameraFacing.back,
  );
  bool _handlingScan = false;
  bool _isRetryingCamera = false;
  bool _checkingCameraPermission = true;
  String? _cameraRetryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCameraAccess());
  }

  bool get _canOpenAppSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _retryCamera() async {
    final wasPermissionBlocked = _cameraRetryError != null;
    setState(() {
      _isRetryingCamera = true;
      if (wasPermissionBlocked) _checkingCameraPermission = true;
    });
    try {
      if (!await ensureCameraPermission(context)) {
        if (mounted) {
          setState(() {
            _checkingCameraPermission = false;
            _cameraRetryError =
                'Permite el acceso a la cámara para escanear QR.';
          });
        }
        return;
      }
      if (!mounted) return;
      if (wasPermissionBlocked) {
        setState(() {
          _checkingCameraPermission = false;
          _cameraRetryError = null;
        });
      } else {
        await _controller.start();
      }
    } on MobileScannerException catch (error) {
      if (mounted) {
        setState(() => _cameraRetryError = _cameraErrorMessage(error));
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _cameraRetryError =
              'No se pudo iniciar la cámara: ${error.message ?? error.code}';
        });
      }
    } finally {
      if (mounted) setState(() => _isRetryingCamera = false);
    }
  }

  Future<void> _requestCameraAccess() async {
    if (!DemoData.instance.canScanReportQr) {
      if (mounted) setState(() => _checkingCameraPermission = false);
      return;
    }
    final granted = await ensureCameraPermission(context);
    if (!mounted) return;
    setState(() {
      _checkingCameraPermission = false;
      if (!granted) {
        _cameraRetryError = 'Permite el acceso a la cámara para escanear QR.';
      }
    });
  }

  Future<void> _openCameraSettings() async {
    try {
      final opened = await openAppSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron abrir los ajustes de la aplicación.'),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron abrir los ajustes: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  String _cameraErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'No hay permiso para usar la cámara. Habilítalo en los ajustes '
            'de la aplicación y vuelve a intentar.';
      case MobileScannerErrorCode.unsupported:
        return 'No se encontró una cámara disponible en este dispositivo.';
      default:
        return 'No se pudo iniciar la cámara. ${error.errorDetails?.message ?? ''}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  
Future<void> _handleDetection(BarcodeCapture capture) async {
  if (_handlingScan) return;

  String? payload;
  for (final barcode in capture.barcodes) {
    if (barcode.rawValue != null) {
      payload = barcode.rawValue;
      break;
    }
  }

  if (payload == null) return;

  _handlingScan = true;

  try {
    final decoded = jsonDecode(payload);

    if (decoded is! Map ||
        decoded['version'] != 3 ||
        decoded['action'] != 'view_event' ||
        decoded['id_evento'] is! int ||
        (decoded['id_evento'] as int) <= 0) {
      throw const FormatException(
        'Este QR no corresponde a una Tarjeta PARE registrada en Laravel.',
      );
    }

    final idEvento = decoded['id_evento'] as int;
    final servicio = ApiService(accessToken: widget.accessToken);

    Map<String, dynamic> evento;

    try {
      evento = await servicio.obtenerEvento(idEvento);
    } finally {
      servicio.close();
    }

    if (!mounted) return;

    final proyecto = evento['proyecto'] as Map?;
    final condicion =
        (num.tryParse(evento['condicion'].toString()) ?? 0).toInt();
    final fecha = DateTime.parse(
      evento['fecha_creacion'] as String,
    ).toLocal();

    final report = <String, dynamic>{
      'id_evento': idEvento,
      'id': 'EVENTO-$idEvento',
      'displayId': '#$idEvento',
      'project': proyecto?['nombre'] ?? 'Proyecto desconocido',
      'condition': '#$condicion',
      'conditionText': condicion >= 1 &&
              condicion <= DemoData.conditions.length
          ? DemoData.conditions[condicion - 1]
          : 'Condición no especificada',
      'reference': evento['referencia'] ?? '',
      'description': evento['descripcion'] ?? '',
      'status': ApiService.estadoParaApp(evento['estado']),
      'date': fecha,
      'createdAt': fecha,
      'hasConnectionAtCreation': true,
      'isThirdParty': false,
      'reporter': 'Registrado en Laravel',
      'createdBy': 'Registrado en Laravel',
      'subject': 'No especificado',
      'evidence': evento['evidencia'] ?? [],
      'closeEvidence': evento['evidencia_cierre'] ?? [],
    };

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(
          report: report,
          isLider: DemoData.instance.puedeCerrarEventos,
          accessToken: widget.accessToken,
        ),
      ),
    );
  } on FormatException catch (error) {
    await _showScanError(error.message);
  } on ApiException catch (error) {
    await _showScanError(error.message);
  } catch (error) {
    await _showScanError('No se pudo consultar Laravel: $error');
  }
}


  

  Future<void> _showScanError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No se pudo abrir la tarjeta'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver a escanear'),
          ),
        ],
      ),
    );
    _handlingScan = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR de Tarjeta PARE')),
    body: !DemoData.instance.canScanReportQr
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Solo el supervisor puede escanear tarjetas PARE.'),
            ),
          )
        : _checkingCameraPermission
        ? const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          )
        : _cameraRetryError != null
        ? _buildCameraError(context, _cameraRetryError!)
        : MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
            errorBuilder: (context, error) => _buildCameraError(
              context,
              _cameraRetryError ?? _cameraErrorMessage(error),
            ),
            placeholderBuilder: (context) => const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            overlayBuilder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 40,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Centra el código QR dentro del recuadro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );

  Widget _buildCameraError(BuildContext context, String message) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'No se puede acceder a la cámara',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isRetryingCamera ? null : _retryCamera,
              icon: _isRetryingCamera
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                _isRetryingCamera ? 'Iniciando cámara...' : 'Reintentar',
              ),
            ),
            if (_canOpenAppSettings) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _openCameraSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Abrir ajustes de la aplicación'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ] else if (kIsWeb) ...[
              const SizedBox(height: 8),
              const Text(
                'Revisa los permisos de cámara del sitio en tu navegador.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
