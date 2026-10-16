import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ReportQrScannerScreen extends StatefulWidget {
  const ReportQrScannerScreen({super.key});

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
  String? _cameraRetryError;

  bool get _canOpenAppSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _retryCamera() async {
    setState(() {
      _isRetryingCamera = true;
      _cameraRetryError = null;
    });
    try {
      await _controller.start();
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
    final reportId = _reportIdFromPayload(payload);
    Map<String, dynamic>? report;
    if (reportId != null) {
      for (final candidate in DemoData.instance.reports) {
        if (candidate['id'] == reportId) {
          report = candidate;
          break;
        }
      }
    }

    if (report == null) {
      await _showScanError(
        reportId == null
            ? 'El código QR no corresponde a una tarjeta PARE válida.'
            : 'La tarjeta no está disponible en este dispositivo. Sin sincronización con un servidor, solo se pueden abrir tarjetas creadas en esta instalación.',
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(
          report: report!,
          isLider: DemoData.instance.canCloseReport(report),
        ),
      ),
    );
  }

  String? _reportIdFromPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['id'] is String) {
        return decoded['id'] as String;
      }
      return null;
    } on FormatException {
      return payload.startsWith('#') ? payload : null;
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
        body: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (context, scannerState, _) => Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
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
              ),
              if (scannerState.error == null)
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
              if (scannerState.error == null)
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
                const Icon(Icons.no_photography_outlined,
                    color: Colors.white, size: 56),
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
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
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
