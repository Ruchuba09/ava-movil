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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canClose = DemoData.instance.canCloseReport(report);
    final hadConnection = report['hasConnectionAtCreation'] as bool? ?? false;
    final qrSize =
        (MediaQuery.sizeOf(context).width - 88).clamp(180.0, 320.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de cierre de flujo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: successColor, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isNewReport ? 'Reporte guardado' : 'QR del reporte',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'ACÉRCATE A TU SUPERVISOR AHORA',
                  style: TextStyle(
                    color: isDark ? verde5Color : const Color(0xFF477600),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pídele que escanee este QR para iniciar el cierre del reporte. Si no está cerca, asegúrate de que venga cuanto antes.',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF202428),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: hadConnection
                        ? (isDark
                            ? const Color(0xFF203A2C)
                            : const Color(0xFFE8F5D7))
                        : (isDark
                            ? const Color(0xFF432F2A)
                            : const Color(0xFFFFE9E2)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hadConnection
                            ? Icons.notifications_active
                            : Icons.wifi_off,
                        color: hadConnection
                            ? (isDark ? verde5Color : const Color(0xFF477600))
                            : const Color(0xFFC43D22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hadConnection
                              ? 'Se avisó a tu supervisor. Muéstrale este QR.'
                              : 'Sin conexión: avisa a tu supervisor y muéstrale este QR.',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF202428),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _payload,
                      version: QrVersions.auto,
                      size: qrSize,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Reporte ${report['id']} · ${report['reference']}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
                    label: const Text('ABRIR CIERRE DEL REPORTE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde6Color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
