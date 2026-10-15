import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ReportQrScannerScreen extends StatefulWidget {
  const ReportQrScannerScreen({super.key});

  @override
  State<ReportQrScannerScreen> createState() => _ReportQrScannerScreenState();
}

class _ReportQrScannerScreenState extends State<ReportQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handlingScan = false;

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
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _handleDetection,
            ),
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
      );
}
