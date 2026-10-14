import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReportQrScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isNewReport;

  const ReportQrScreen({
    super.key,
    required this.report,
    this.isNewReport = true,
  });

  String get _payload => jsonEncode({
        'id': report['id'],
        'project': report['project'],
        'reference': report['reference'],
        'condition': report['condition'],
        'conditionText': report['conditionText'],
        'description': report['description'],
        'status': report['status'],
        'createdAt': (report['createdAt'] ?? report['date']).toString(),
        'hasConnectionAtCreation': report['hasConnectionAtCreation'],
        'reporterId': report['reporterId'],
        'reporter': report['reporter'],
        'managerId': report['managerId'],
        'manager': report['manager'],
        'originalManager': report['originalManager'],
        'action': 'close_report',
      });

  String _formatDateTime(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canClose = DemoData.instance.canCloseReport(report);
    final hadConnection = report['hasConnectionAtCreation'] as bool? ?? false;
    final createdAt =
        report['createdAt'] as DateTime? ?? report['date'] as DateTime?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de cierre de flujo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              color: isDark ? gris2Color : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: successColor, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      isNewReport ? '¡Reporte guardado!' : 'QR del reporte',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Muestra este QR al encargado para abrir directamente el cierre del flujo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hadConnection
                            ? const Color(0xFF1C3D3F)
                            : const Color(0xFF432F2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            hadConnection ? Icons.wifi : Icons.wifi_off,
                            color: hadConnection
                                ? Colors.cyan
                                : const Color(0xFFFF542E),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hadConnection
                                  ? 'Tiene conexión. Se registró una notificación en la aplicación para su encargado, para que complete el proceso.'
                                  : 'Usted no tiene conexión. Diríjase a su encargado para completar el proceso.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tarjeta creada: ${_formatDateTime(createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'El QR sirve para identificar la tarjeta y abrir su cierre; no indica por sí solo que se haya creado sin conexión.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _payload,
                        version: QrVersions.auto,
                        size: 180.0,
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
                          minimumSize: const Size.fromHeight(44),
                        ),
                      )
                    else
                      const Text(
                        'Solo el jefe de cuadrilla asignado a este reporte puede cerrar este flujo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde6Color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: const Text('Volver',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
