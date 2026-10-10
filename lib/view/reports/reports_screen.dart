import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:avamovil/view/reports/report_qr_screen.dart';

class ReportsScreen extends StatefulWidget {
  final String initialStatusFilter;
  final String initialProjectFilter;

  const ReportsScreen({
    super.key,
    this.initialStatusFilter = 'Todos',
    this.initialProjectFilter = 'Todos los proyectos',
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late String _statusFilter;
  late String _projectFilter;
  String _conditionFilter = 'Todas';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    _projectFilter = widget.initialProjectFilter;
  }

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

  String _formatDate(DateTime? date) => date == null
      ? 'dd-mm-aaaa'
      : '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final demoData = DemoData.instance;

    return AnimatedBuilder(
      animation: demoData,
      builder: (context, child) {
        final filteredReports = demoData.reports.where((report) {
          final date = report['date'] as DateTime;
          final passProject = _projectFilter == 'Todos los proyectos' ||
              report['project'] == _projectFilter;
          final passCondition = _conditionFilter == 'Todas' ||
              report['condition'] == _conditionFilter;
          final passStatus = _statusFilter == 'Todos' ||
              report['status'] == _statusFilter.toUpperCase();
          final passFrom = _fromDate == null || !date.isBefore(_fromDate!);
          final passTo = _toDate == null ||
              !date.isAfter(DateTime(
                  _toDate!.year, _toDate!.month, _toDate!.day, 23, 59));
          return passProject &&
              passCondition &&
              passStatus &&
              passFrom &&
              passTo;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Eventos',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Listado de reportes registrados.',
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700])),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth > 900
                          ? (constraints.maxWidth - 32) / 5
                          : constraints.maxWidth > 560
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                              width: width,
                              child: _dropdown(
                                  'Proyecto',
                                  _projectFilter,
                                  ['Todos los proyectos', ...DemoData.projects],
                                  (value) =>
                                      setState(() => _projectFilter = value))),
                          SizedBox(
                              width: width,
                              child: _dropdown(
                                  'Condición',
                                  _conditionFilter,
                                  [
                                    'Todas',
                                    ...List.generate(
                                        10, (index) => '#${index + 1}')
                                  ],
                                  (value) => setState(
                                      () => _conditionFilter = value))),
                          SizedBox(
                              width: width,
                              child: _dropdown(
                                  'Estado',
                                  _statusFilter,
                                  ['Todos', 'Abierta', 'Cerrada'],
                                  (value) =>
                                      setState(() => _statusFilter = value))),
                          SizedBox(
                              width: width,
                              child: _dateField('Desde', _formatDate(_fromDate),
                                  () => _selectDate(isStart: true))),
                          SizedBox(
                              width: width,
                              child: _dateField('Hasta', _formatDate(_toDate),
                                  () => _selectDate(isStart: false))),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('${filteredReports.length} reportes',
                  style: Theme.of(context).textTheme.labelMedium),
            ),
            Expanded(
              child: filteredReports.isEmpty
                  ? const Center(
                      child: Text(
                          'No hay reportes para los filtros seleccionados.'))
                  : ListView.builder(
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = filteredReports[index];
                        final isOpen = report['status'] == 'ABIERTA';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          color: isDark ? gris2Color : Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: verde1Color,
                                  child: Text(report['id'] as String,
                                      style: const TextStyle(
                                          color: verde6Color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(report['project'] as String,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${report['condition']}  |  ${_formatReportDate(report['date'] as DateTime)}  |  ${report['reference']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? verde1Color
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(report['status'] as String,
                                      style: TextStyle(
                                          color: isOpen
                                              ? verde6Color
                                              : Colors.grey[700],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (isOpen && DemoData.instance.canCloseReport(report))
                                  IconButton(
                                    tooltip: 'QR de cierre del flujo',
                                    icon: const Icon(Icons.qr_code_2,
                                        color: verde6Color),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ReportQrScreen(report: report),
                                      ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () => _openReport(report),
                                  child: const Text('Ver  →'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      items: options
          .map((option) => DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _dateField(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(value,
            style:
                TextStyle(color: value == 'dd-mm-aaaa' ? Colors.grey : null)),
      ),
    );
  }

  String _formatReportDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  void _openReport(Map<String, dynamic> report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(
          report: report,
          isLider: DemoData.instance.canCloseReport(report),
        ),
      ),
    );
  }
}
