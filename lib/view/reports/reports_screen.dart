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
  final TextEditingController _internalIdController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    _projectFilter = widget.initialProjectFilter;
  }

  @override
  void dispose() {
    _internalIdController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected != null) {
      setState(() {
        _fromDate = selected.start;
        _toDate = selected.end;
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
          final internalId = _internalIdController.text.trim().toLowerCase();
          final passInternalId = internalId.isEmpty ||
              (report['id'] as String).toLowerCase().contains(internalId);
          final passFrom = _fromDate == null || !date.isBefore(_fromDate!);
          final dayAfterTo = _toDate == null
              ? null
              : DateTime(_toDate!.year, _toDate!.month, _toDate!.day + 1);
          final passTo = dayAfterTo == null || date.isBefore(dayAfterTo);
          return passProject &&
              passCondition &&
              passStatus &&
              passInternalId &&
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
                          ? (constraints.maxWidth - 24) / 4
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
                            child: TextField(
                              controller: _internalIdController,
                              decoration: InputDecoration(
                                labelText: 'ID interna',
                                hintText: 'Ej: #200',
                                prefixIcon: const Icon(Icons.tag),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _dateField(
                                    'Desde',
                                    _formatDate(_fromDate),
                                    _selectDateRange,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _dateField(
                                    'Hasta',
                                    _formatDate(_toDate),
                                    _selectDateRange,
                                    isDark,
                                  ),
                                ),
                                if (_fromDate != null || _toDate != null)
                                  IconButton(
                                    tooltip: 'Limpiar fechas',
                                    onPressed: () => setState(() {
                                      _fromDate = null;
                                      _toDate = null;
                                    }),
                                    icon: const Icon(Icons.close),
                                  ),
                              ],
                            ),
                          ),
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
                        final isThirdParty = report['isThirdParty'] == true;
                        final subject =
                            (report['subject'] ?? report['reporter'])
                                .toString();
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          color: isDark ? gris2Color : Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openReport(report),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 21,
                                    backgroundColor: verde1Color,
                                    child: Text(report['id'] as String,
                                        style: const TextStyle(
                                            color: verde6Color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11)),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                report['project'] as String,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isOpen
                                                    ? verde1Color
                                                    : Colors.grey.withValues(
                                                        alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Text(
                                                isOpen ? 'ABIERTA' : 'CERRADA',
                                                style: TextStyle(
                                                  color: isOpen
                                                      ? verde6Color
                                                      : Colors.grey[700],
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          report['reference'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            _reportMeta(
                                              context,
                                              '${report['condition']} · ${_formatReportDate(report['date'] as DateTime)}',
                                              Icons.event_outlined,
                                            ),
                                            if (isThirdParty)
                                              _reportMeta(
                                                context,
                                                'Para $subject',
                                                Icons.people_outline,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOpen &&
                                      DemoData.instance.canCloseReport(report))
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
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.chevron_right),
                                    ),
                                ],
                              ),
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

  Widget _reportMeta(BuildContext context, String label, IconData icon) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: verde6Color),
          const SizedBox(width: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _dateField(
      String label, String value, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
            filled: true,
            fillColor: isDark ? gris2Color : Colors.white,
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
