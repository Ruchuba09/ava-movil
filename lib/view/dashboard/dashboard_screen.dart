import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';

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
        final criticalIndex = counts.isEmpty
            ? 0
            : counts.indexOf(counts.reduce((a, b) => a > b ? a : b));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Panel Estadístico',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Resumen de hallazgos y reportes (Tarjeta PARE).',
                  style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700])),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth > 700
                      ? (constraints.maxWidth - 16) / 3
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width,
                        child: DropdownButtonFormField<String>(
                          initialValue: _project,
                          isExpanded: true,
                          decoration: _filterDecoration('PROYECTO', isDark),
                          items: ['Todos los proyectos', ...DemoData.projects]
                              .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _project = value);
                          },
                        ),
                      ),
                      SizedBox(
                          width: width,
                          child: _dateField('DESDE', _fromDate,
                              () => _selectDate(isStart: true))),
                      SizedBox(
                          width: width,
                          child: _dateField('HASTA', _toDate,
                              () => _selectDate(isStart: false))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildChart(context, isDark, counts),
              const SizedBox(height: 12),
              _buildStats(
                  context, isDark, reports.length, counts, criticalIndex),
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
    final maxCount = counts.fold<int>(
        1, (maximum, value) => value > maximum ? value : maximum);
    return Card(
      elevation: 1,
      color: isDark ? gris2Color : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Frecuencia por Condición (Tarjeta PARE)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Cantidad de reportes ingresados por cada tipo de condición.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width:
                        constraints.maxWidth > 700 ? constraints.maxWidth : 700,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(counts.length, (index) {
                        final count = counts[index];
                        return SizedBox(
                          width: 54,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('$count',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                height: count == 0 ? 2 : 130 * count / maxCount,
                                decoration: const BoxDecoration(
                                    color: verde6Color,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(3))),
                              ),
                              const SizedBox(height: 8),
                              Text('${index + 1}.',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, bool isDark, int total,
      List<int> counts, int criticalIndex) {
    final criticalCount = counts.isEmpty ? 0 : counts[criticalIndex];
    final criticalLabel =
        DemoData.conditions[criticalIndex].split(' ').skip(1).take(4).join(' ');
    return Row(
      children: [
        Expanded(
            child: _statCard(
                context, isDark, 'TOTAL REPORTES', '$total', verde6Color)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard(context, isDark, 'CONDICIÓN MÁS CRÍTICA',
                '$criticalCount\n$criticalLabel', Colors.red)),
      ],
    );
  }

  Widget _statCard(BuildContext context, bool isDark, String title,
          String value, Color valueColor) =>
      Card(
        elevation: 1,
        color: isDark ? gris2Color : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: valueColor),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
