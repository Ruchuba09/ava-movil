import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:avamovil/view/reports/reports_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final demoData = DemoData.instance;
    return AnimatedBuilder(
      animation: demoData,
      builder: (context, child) {
        final leaderId = (demoData.currentUser['leaderId'] ??
            demoData.currentUser['id']) as int;
        final team = demoData.workers
            .where((worker) => worker['leaderId'] == leaderId)
            .toList();
        final teamReports = demoData.reports
            .where((report) => report['managerId'] == leaderId)
            .toList();
        final openCount =
            teamReports.where((report) => report['status'] == 'ABIERTA').length;
        final closedCount = teamReports.length - openCount;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Visualización de cuadrilla',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Revisa los reportes y el desempeño de tu equipo.',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              _buildTeamSummary(
                context,
                total: teamReports.length,
                open: openCount,
                closed: closedCount,
                onOpenTap: () => _openReportList('Abierta'),
                onClosedTap: () => _openReportList('Cerrada'),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 22),
              Text('Trabajadores a cargo (${team.length})',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (team.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        Text('No hay trabajadores asignados a esta cuadrilla.'),
                  ),
                ),
              ...team.map((worker) {
                final workerReports =
                    demoData.reportsForWorker(worker['id'] as int);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? gris2Color
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: verde1Color,
                      child: Text((worker['name'] as String).substring(0, 1),
                          style: const TextStyle(
                              color: verde6Color, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(worker['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${worker['role']}  -  ${workerReports.length} reportes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              WorkerProfileScreen(worker: worker)),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openReportList(String status) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(
          initialStatusFilter: status,
          initialProjectFilter: 'Todos los proyectos',
        ),
      ),
    );
  }

  Widget _buildTeamSummary(
    BuildContext context, {
    required int total,
    required int open,
    required int closed,
    required VoidCallback onOpenTap,
    required VoidCallback onClosedTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
            child: _summaryCard(context, isDark, 'REPORTES', total,
                Icons.assignment_outlined, verde6Color,
                onTap: null)),
        const SizedBox(width: 8),
        Expanded(
            child: _summaryCard(context, isDark, 'ABIERTOS', open,
                Icons.pending_actions_outlined, Colors.deepOrange,
                onTap: onOpenTap)),
        const SizedBox(width: 8),
        Expanded(
            child: _summaryCard(context, isDark, 'CERRADOS', closed,
                Icons.task_alt, Colors.teal,
                onTap: onClosedTap)),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, bool isDark, String title,
          int value, IconData icon, Color color,
          {VoidCallback? onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Card(
            margin: EdgeInsets.zero,
            color: isDark ? gris2Color : Colors.white,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 19),
                  const SizedBox(height: 5),
                  Text('$value',
                      style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      );

}

class WorkerProfileScreen extends StatelessWidget {
  final Map<String, dynamic> worker;

  const WorkerProfileScreen({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    final demoData = DemoData.instance;
    final workerId = worker['id'] as int;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del trabajador')),
      body: AnimatedBuilder(
        animation: demoData,
        builder: (context, child) {
          final reports = demoData.reportsForWorker(workerId);
          final open =
              reports.where((report) => report['status'] == 'ABIERTA').length;
          final closed = reports.length - open;
          final counts = List<int>.generate(
            DemoData.conditions.length,
            (index) => reports
                .where((report) => report['condition'] == '#${index + 1}')
                .length,
          );
          final frequentCondition = counts.isEmpty
              ? 0
              : counts.indexOf(counts.reduce((a, b) => a > b ? a : b)) + 1;
          final displayedReports = demoData.openReportsFirst(reports);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? gris2Color
                    : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: verde1Color,
                    child: Text((worker['name'] as String).substring(0, 1),
                        style: const TextStyle(
                            color: verde6Color, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(worker['name'] as String,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text('${worker['role']}\n${worker['email']}'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _profileStat(
                          context, 'REPORTES', reports.length, verde6Color)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _profileStat(
                          context, 'ABIERTOS', open, Colors.deepOrange)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _profileStat(
                          context, 'CERRADOS', closed, Colors.teal)),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? gris2Color
                    : Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.bar_chart, color: verde6Color),
                  title: const Text('Condición más reportada'),
                  subtitle: Text('Condición #$frequentCondition'),
                  trailing: Text(
                    '${counts[frequentCondition - 1]}',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: verde6Color),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Historial de reportes (${reports.length})',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (reports.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Este trabajador aún no tiene reportes.'),
                  ),
                ),
              ...displayedReports.map((report) {
                final date = report['date'] as DateTime;
                final isOpen = report['status'] == 'ABIERTA';
                final statusColor = isOpen ? Colors.deepOrange : Colors.teal;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  color: Color.lerp(
                    isDark ? gris2Color : Colors.white,
                    statusColor,
                    isDark ? 0.16 : 0.08,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: statusColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.18),
                      child: Text(
                        report['condition'] as String,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${report['id']}  ${report['project']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOpen ? 'ABIERTA' : 'CERRADA',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: statusColor),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportDetailScreen(
                          report: report,
                          isLider: demoData.canCloseReport(report),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _profileStat(
          BuildContext context, String title, int value, Color color) =>
      Card(
        margin: EdgeInsets.zero,
        color: Theme.of(context).brightness == Brightness.dark
            ? gris2Color
            : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(
                      color: color, fontSize: 25, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}
