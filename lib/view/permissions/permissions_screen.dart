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
  int? _selectedWorkerId;
  DateTime _until = DateTime.now().add(const Duration(days: 7));

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _until.isBefore(DateTime.now()) ? DateTime.now() : _until,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _until = selected);
  }

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
        final assignment = demoData.actingAssignmentFor(leaderId);
        final isLeader = demoData.currentUser['id'] == leaderId &&
            (demoData.currentUser['role'] as String).contains('JEFE');
        final selectedWorker = _selectedWorkerId ??
            assignment?['workerId'] as int? ??
            (team.isEmpty ? null : team.first['id'] as int);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Permisos de cuadrilla',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Gestiona reemplazos y revisa el desempeño de tu equipo.',
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
              if (assignment != null)
                _buildActiveAssignment(context, demoData, assignment, team),
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
                final isDelegate = assignment?['workerId'] == worker['id'];
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
                        '${worker['role']}  ·  ${workerReports.length} reportes'),
                    trailing: isDelegate
                        ? const Tooltip(
                            message: 'Reemplazo temporal activo',
                            child: Icon(Icons.swap_horiz, color: verde6Color),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              WorkerProfileScreen(worker: worker)),
                    ),
                  ),
                );
              }),
              if (isLeader) ...[
                const SizedBox(height: 18),
                _buildAssignmentForm(context, demoData, team, selectedWorker,
                    assignment != null),
              ],
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

  Widget _buildActiveAssignment(
    BuildContext context,
    DemoData demoData,
    Map<String, dynamic> assignment,
    List<Map<String, dynamic>> team,
  ) {
    final worker = team.firstWhere(
        (item) => item['id'] == assignment['workerId'],
        orElse: () => {'name': 'Trabajador'});
    final until = assignment['until'] as DateTime;
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.teal.withValues(alpha: 0.16)
          : const Color(0xFFEAF7E5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: verde6Color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${worker['name']} está a cargo temporalmente',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('Puede cerrar flujos hasta el ${_formatDate(until)}.'),
            const SizedBox(height: 4),
            const Text('El jefe de cuadrilla mantiene sus permisos de cierre.'),
            if (demoData.currentUser['id'] ==
                (demoData.currentUser['leaderId'] ??
                    demoData.currentUser['id'])) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => demoData
                      .clearActingManager((demoData.currentUser['id'] as int)),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Finalizar reemplazo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentForm(
    BuildContext context,
    DemoData demoData,
    List<Map<String, dynamic>> team,
    int? selectedWorker,
    bool hasAssignment,
  ) =>
      Card(
        color: Theme.of(context).brightness == Brightness.dark
            ? gris2Color
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hasAssignment ? 'Cambiar reemplazo' : 'Asignar reemplazo',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: selectedWorker,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Trabajador responsable',
                    border: OutlineInputBorder()),
                items: team
                    .map((worker) => DropdownMenuItem<int>(
                        value: worker['id'] as int,
                        child: Text(worker['name'] as String)))
                    .toList(),
                onChanged: team.isEmpty
                    ? null
                    : (value) => setState(() => _selectedWorkerId = value),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _selectEndDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Vigente hasta ${_formatDate(_until)}'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: team.isEmpty || selectedWorker == null
                      ? null
                      : () => demoData.assignActingManager(
                            leaderId: demoData.currentUser['id'] as int,
                            workerId: selectedWorker,
                            until: _until,
                          ),
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('Guardar reemplazo temporal'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: verde6Color,
                      foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'La asignación no quita permisos al jefe de cuadrilla.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
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
          final leaderId = worker['leaderId'] as int;
          final assignment = demoData.actingAssignmentFor(leaderId);
          final isActing = assignment?['workerId'] == workerId;

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
                  subtitle: Text('${worker['role']}  ·  ${worker['email']}'),
                  trailing: isActing
                      ? const Tooltip(
                          message: 'Reemplazo temporal activo',
                          child: Icon(Icons.verified_user, color: verde6Color),
                        )
                      : null,
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
                  trailing: Text('${counts[frequentCondition - 1]}'),
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
              ...reports.map((report) {
                final date = report['date'] as DateTime;
                return Card(
                  margin: const EdgeInsets.only(bottom: 7),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? gris2Color
                      : Colors.white,
                  child: ListTile(
                    title: Text('${report['id']}  ·  ${report['project']}'),
                    subtitle: Text(
                        '${report['condition']}  ·  ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}  ·  ${report['status']}'),
                    trailing: const Icon(Icons.chevron_right),
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
                      color: color, fontSize: 21, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}
