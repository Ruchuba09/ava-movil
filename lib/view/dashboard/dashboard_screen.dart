import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/reports_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardContent();
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent();

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  String _project = 'Todos los proyectos';
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _selectDate({required bool isStart}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (isStart ? _fromDate : _toDate) ?? DateTime(2026, 10, 8),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected != null) {
      setState(() {
        if (isStart) {
          _fromDate = selected;
        } else {
          _toDate = selected;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final demoData = DemoData.instance;

    return AnimatedBuilder(
      animation: demoData,
      builder: (context, child) {
        final reports = demoData.reports.where((report) {
          final date = report['date'] as DateTime;
          return (_project == 'Todos los proyectos' ||
                  report['project'] == _project) &&
              (_fromDate == null || !date.isBefore(_fromDate!)) &&
              (_toDate == null ||
                  !date.isAfter(DateTime(
                      _toDate!.year, _toDate!.month, _toDate!.day, 23, 59)));
        }).toList();
        final counts = List<int>.generate(
          DemoData.conditions.length,
          (index) => reports
              .where((report) => report['condition'] == '#${index + 1}')
              .length,
        );
        final openReports =
            reports.where((report) => report['status'] == 'ABIERTA').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Panel Estadístico',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('Resumen de hallazgos y reportes (Tarjeta PARE).',
                  style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700])),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final projectFilter = DropdownButtonFormField<String>(
                    initialValue: _project,
                    isExpanded: true,
                    decoration: _filterDecoration('PROYECTO', isDark),
                    items: ['Todos los proyectos', ...DemoData.projects]
                        .map((value) => DropdownMenuItem(
                            value: value,
                            child:
                                Text(value, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _project = value);
                    },
                  );
                  final fromDate = _dateField(
                      'DESDE', _fromDate, () => _selectDate(isStart: true));
                  final toDate = _dateField(
                      'HASTA', _toDate, () => _selectDate(isStart: false));
                  if (constraints.maxWidth <= 700) {
                    return Column(
                      children: [
                        projectFilter,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: fromDate),
                            const SizedBox(width: 8),
                            Expanded(child: toDate),
                          ],
                        ),
                      ],
                    );
                  }
                  final width = (constraints.maxWidth - 16) / 3;
                  return Wrap(
                    spacing: 8,
                    children: [
                      SizedBox(width: width, child: projectFilter),
                      SizedBox(width: width, child: fromDate),
                      SizedBox(width: width, child: toDate),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildChart(context, isDark, counts),
              const SizedBox(height: 8),
              _buildStats(context, isDark, reports.length, openReports),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _filterDecoration(String label, bool isDark) =>
      InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: isDark ? Colors.black12 : verde1Color,
      );

  Widget _dateField(String label, DateTime? date, VoidCallback onTap) {
    final value = date == null
        ? 'dd-mm-aaaa'
        : '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black12
              : verde1Color,
        ),
        child: Text(value,
            style: TextStyle(color: date == null ? Colors.grey : null)),
      ),
    );
  }

  Widget _buildChart(BuildContext context, bool isDark, List<int> counts) {
    final chartGroups = [
      counts.sublist(0, 5),
      counts.sublist(5),
    ];
    final maxCount = counts.fold<int>(
        1, (maximum, value) => value > maximum ? value : maximum);
    final valueColor = isDark ? Colors.white70 : Colors.black87;

    return Card(
      elevation: 1,
      color: isDark ? gris2Color : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Frecuencia por Condición (Tarjeta PARE)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('Cantidad de reportes por tipo de condición.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            ...chartGroups.asMap().entries.map((entry) {
              final groupIndex = entry.key;
              final group = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    SizedBox(
                      height: 110,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(group.length, (index) {
                          final count = group[index];
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('$count',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: valueColor)),
                                  const SizedBox(height: 3),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: double.infinity,
                                    height:
                                        count == 0 ? 4 : 74 * count / maxCount,
                                    decoration: const BoxDecoration(
                                      color: verde6Color,
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(3)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                        group.length,
                        (index) => Expanded(
                          child: Text(
                            '${(groupIndex * 5) + index + 1}',
                            style: TextStyle(
                              fontSize: 9,
                              color: valueColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(
      BuildContext context, bool isDark, int total, int openReports) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            isDark,
            'TOTAL REPORTES',
            '$total',
            'Registrados en el período',
            Icons.assessment_outlined,
            verde6Color,
            onTap: () => _openReportsList('Todos'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            context,
            isDark,
            'POR CERRAR',
            '$openReports',
            'Requieren seguimiento',
            Icons.pending_actions_outlined,
            Colors.deepOrange,
            onTap: () => _openReportsList('Abierta'),
          ),
        ),
      ],
    );
  }

  void _openReportsList(String status) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(
          initialStatusFilter: status == 'Todos' ? 'Todos' : 'Abierta',
          initialProjectFilter: _project,
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, bool isDark, String title,
          String value, String caption, IconData icon, Color valueColor,
          {VoidCallback? onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Card(
            elevation: 1,
            color: isDark ? gris2Color : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(icon, color: valueColor, size: 17),
                      const SizedBox(width: 8),
                      Text(value,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: valueColor)),
                    ],
                  ),
                  Text(caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      );
}
