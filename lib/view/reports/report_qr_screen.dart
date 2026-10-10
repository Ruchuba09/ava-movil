import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReportQrScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const ReportQrScreen({
    super.key,
    required this.report,
  });

  String get _payload => jsonEncode({
        'id': report['id'],
        'project': report['project'],
        'reference': report['reference'],
        'condition': report['condition'],
        'conditionText': report['conditionText'],
        'status': report['status'],
        'reporterId': report['reporterId'],
        'reporter': report['reporter'],
        'managerId': report['managerId'],
        'manager': report['manager'],
        'originalManager': report['originalManager'],
        'action': 'close_report',
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canClose = DemoData.instance.canCloseReport(report);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de cierre de flujo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            color: isDark ? gris2Color : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
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
                    'Muestra este QR al encargado para abrir directamente el cierre del flujo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _payload,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (canClose)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportDetailScreen(
                            report: report,
                            isLider: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('Abrir cierre del flujo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde6Color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    )
                  else
                    const Text(
                      'Solo el jefe de cuadrilla o su reemplazo temporal puede cerrar este flujo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde6Color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Volver al Inicio',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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

