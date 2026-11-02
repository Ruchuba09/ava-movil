import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/widgets/selection_field.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  final String accessToken;
  final String initialStatusFilter;
  final String initialProjectFilter;
  final bool onlyCurrentUser;
  final bool onlyCurrentTeam;

  const ReportsScreen({
    super.key,
    required this.accessToken,
    this.initialStatusFilter = 'Todos',
    this.initialProjectFilter = 'Todos los proyectos',
    this.onlyCurrentUser = false,
    this.onlyCurrentTeam = false,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _eventosReales = [];
  bool _cargandoEventos = false;
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
  _cargarEventos();
}

  
  Map<String, dynamic> _adaptarEvento(Map<String, dynamic> evento) {
    final proyecto = evento['proyecto'] as Map?;
    final fecha = DateTime.parse(
      evento['fecha_creacion'] as String,
    ).toLocal();

    final condicionNumero =
        (num.tryParse(evento['condicion'].toString()) ?? 0)
            .toInt();

    return {
      'id_evento': evento['id_evento'],
      'id': 'EVENTO-${evento['id_evento']}',
      'displayId': '#${evento['id_evento']}',
      'project': proyecto?['nombre'] ?? 'Proyecto desconocido',
      'condition': '#$condicionNumero',
      'conditionText': condicionNumero >= 1 &&
              condicionNumero <= DemoData.conditions.length
          ? DemoData.conditions[condicionNumero - 1]
          : 'Condición no especificada',
      'reference': evento['referencia'] ?? '',
      'description': evento['descripcion'] ?? '',
      'status': evento['estado'] == 'abierta'
          ? 'ABIERTA'
          : evento['estado'] == 'cerrada'
              ? 'CERRADA'
              : evento['estado'].toString().toUpperCase(),
      'date': fecha,
      'createdAt': fecha,
      'hasConnectionAtCreation': true,
      'isThirdParty': false,
      'reporter': 'Registrado en Laravel',
      'createdBy': 'Registrado en Laravel',
      'subject': 'No especificado',
      'evidence': evento['evidencia'] ?? [],
    };
  }

  Future<void> _cargarEventos() async {
    setState(() => _cargandoEventos = true);

    final servicio = ApiService(
      accessToken: widget.accessToken,
    );

    try {
      
      final eventos = widget.onlyCurrentUser
          ? await servicio.obtenerMisReportes()
          : widget.onlyCurrentTeam
              ? await servicio.obtenerReportesMiCuadrilla()
              : await servicio.obtenerEventos();


      if (!mounted) return;

      
      setState(() {
        _eventosReales = eventos
            .map(
              (evento) => _adaptarEvento(
                Map<String, dynamic>.from(evento as Map),
              ),
            )
            .toList();
      });


      debugPrint(
        'Eventos reales recibidos desde Laravel: ${_eventosReales.length}',
      );

      debugPrint(
        'Evento 501 encontrado: ${_eventosReales.any((e) => e['id_evento'] == 501)}',
      );
      for (final evento in _eventosReales) {
        if (evento['id_evento'] == 501) {
          debugPrint('Estructura del evento 501: $evento');
          break;
        }
      }
    
} catch (error) {
  final origen = widget.onlyCurrentUser
      ? 'eventos/mis-reportes'
      : widget.onlyCurrentTeam
          ? 'eventos/mi-cuadrilla'
          : 'eventos';

  debugPrint('ERROR EN $origen: $error');

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No se pudieron cargar los reportes: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
 finally {
      servicio.close();

      if (mounted) {
        setState(() => _cargandoEventos = false);
      }
    }
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
    if (_cargandoEventos) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
    

    return AnimatedBuilder(
      animation: demoData,
      builder: (context, child) {
        
        final sourceReports = _eventosReales;

        final matchingReports = sourceReports.where((report) {
          final date = report['date'] as DateTime;
          final passProject =
              _projectFilter == 'Todos los proyectos' ||
              report['project'] == _projectFilter;
          final passCondition =
              _conditionFilter == 'Todas' ||
              report['condition'] == _conditionFilter;
          final passStatus =
              _statusFilter == 'Todos' ||
              report['status'] == _statusFilter.toUpperCase();
          final internalId = _internalIdController.text.trim().toLowerCase();
          final passInternalId =
              internalId.isEmpty ||
              demoData
                  .reportDisplayId(report)
                  .toLowerCase()
                  .contains(internalId) ||
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
        final filteredReports = _statusFilter == 'Todos'
            ? demoData.openReportsFirst(matchingReports)
            : matchingReports;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.onlyCurrentUser
                        ? 'Mis Reportes'
                        : widget.onlyCurrentTeam
                        ? 'Reportes de la cuadrilla'
                        : 'Listado Tarjeta PARE',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.onlyCurrentUser
                        ? 'Tarjetas creadas por ti o asociadas a tu usuario.'
                        : widget.onlyCurrentTeam
                        ? 'Reportes asignados a tu cuadrilla para revisar y cerrar.'
                        : 'Listado de reportes registrados.',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 6),
                      leading: const Icon(Icons.tune),
                      title: const Text('Filtros'),
                      subtitle: Text(
                        _statusFilter == 'Todos'
                            ? 'Abiertas primero'
                            : 'Estado: $_statusFilter',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth > 900
                                ? (constraints.maxWidth - 24) / 4
                                : (constraints.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: SelectionField<String>(
                                    label: 'Proyecto',
                                    value: _projectFilter,
                                    options:
                                        [
                                              'Todos los proyectos',
                                              ...DemoData.projects,
                                            ]
                                            .map(
                                              (option) => SelectionOption(
                                                value: option,
                                                label: option,
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _projectFilter = value);
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: SelectionField<String>(
                                    label: 'Condición',
                                    value: _conditionFilter,
                                    options:
                                        [
                                              'Todas',
                                              ...List.generate(
                                                10,
                                                (index) => '#${index + 1}',
                                              ),
                                            ]
                                            .map(
                                              (option) => SelectionOption(
                                                value: option,
                                                label: option,
                                              ),
                                            )
                                            .toList(),
                                    optionRows: [
                                      const [
                                        SelectionOption(
                                          value: 'Todas',
                                          label: 'Todas',
                                        ),
                                      ],
                                      List.generate(
                                        5,
                                        (index) => SelectionOption(
                                          value: '#${index + 1}',
                                          label: '#${index + 1}',
                                        ),
                                      ),
                                      List.generate(
                                        5,
                                        (index) => SelectionOption(
                                          value: '#${index + 6}',
                                          label: '#${index + 6}',
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(
                                          () => _conditionFilter = value,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: SelectionField<String>(
                                    label: 'Estado',
                                    value: _statusFilter,
                                    options: ['Todos', 'Abierta', 'Cerrada']
                                        .map(
                                          (option) => SelectionOption(
                                            value: option,
                                            label: option,
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _statusFilter = value);
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: TextField(
                                    controller: _internalIdController,
                                    decoration: InputDecoration(
                                      labelText: 'ID interna',
                                      hintText: 'Ej: #200',
                                      prefixIcon: const Icon(Icons.tag),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '${filteredReports.length} reportes',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(
              child: filteredReports.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay reportes para los filtros seleccionados.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = filteredReports[index];
                        final isOpen = report['status'] == 'ABIERTA';
                        final isThirdParty = report['isThirdParty'] == true;
                        final subject =
                            (report['subject'] ?? report['reporter'])
                                .toString();
                        final createdBy =
                            (report['createdBy'] ?? report['reporter'])
                                .toString();
                        final statusColor = isOpen
                            ? const Color(0xFFFF542E)
                            : Colors.cyan;
                        final cardColor = isOpen
                            ? verde5Color
                            : Colors.cyan.shade100;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          color: cardColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: statusColor.withValues(alpha: 0.8),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ReportDetailScreen(
                                    report: report,
                                    isLider: true,
                                    accessToken: widget.accessToken,
                                  ),
                                ),
                              );

                              if (mounted) {
                                await _cargarEventos();
                              }
                            },

                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (widget.onlyCurrentUser) ...[
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      child: Text(
                                        demoData.reportDisplayId(report),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.onlyCurrentUser
                                                    ? report['project']
                                                          as String
                                                    : createdBy,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      widget.onlyCurrentUser
                                                      ? null
                                                      : 17,
                                                ),
                                                maxLines: widget.onlyCurrentUser
                                                    ? 1
                                                    : null,
                                                overflow: widget.onlyCurrentUser
                                                    ? TextOverflow.ellipsis
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isOpen ? 'ABIERTA' : 'CERRADA',
                                              style: TextStyle(
                                                color: isOpen
                                                    ? const Color(0xFFFF542E)
                                                    : Colors.cyan.shade900,
                                                fontSize: 10,
                                                letterSpacing: 0.3,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          report['reference'] as String,
                                          maxLines: widget.onlyCurrentUser
                                              ? 1
                                              : null,
                                          overflow: widget.onlyCurrentUser
                                              ? TextOverflow.ellipsis
                                              : null,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.black),
                                        ),
                                        const SizedBox(height: 4),
                                        if (widget.onlyCurrentUser)
                                          Text(
                                            '${report['condition']}  ·  ${_formatReportDateTime(report)}${isThirdParty ? '  ·  Para $subject' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: Colors.black),
                                          )
                                        else ...[
                                          Text(
                                            (report['conditionText'] ??
                                                    report['condition'])
                                                .toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: Colors.black),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatReportDateTime(report)}${isThirdParty ? '  ·  Para $subject' : ''}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: statusColor),
                                          ),
                                        ],
                                      ],
                                    ),
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

  Widget _dateField(
    String label,
    String value,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
          filled: true,
          fillColor: isDark ? gris2Color : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          value,
          style: TextStyle(color: value == 'dd-mm-aaaa' ? Colors.grey : null),
        ),
      ),
    );
  }

  String _formatReportDateTime(Map<String, dynamic> report) {
    final date = report['createdAt'] as DateTime? ?? report['date'] as DateTime;
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  
}
