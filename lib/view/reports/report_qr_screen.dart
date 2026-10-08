import 'package:flutter/material.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReportQrScreen extends StatelessWidget {
  final String reportData; // Data to encode in the QR

  const ReportQrScreen({
    super.key,
    this.reportData = '{"id": 1234, "action": "close_report"}', // Mock data
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación de Encargado'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            color: isDark ? gris2Color : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: successColor, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Reporte guardado!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para terminar el flujo con o sin señal, muestra este código QR al encargado para que lo escanee.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, // QR always needs contrast
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: reportData,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to Home
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde6Color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Volver al Inicio', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

