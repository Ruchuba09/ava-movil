import 'package:flutter/material.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _statusFilter = 'Todos';
  String _projectFilter = 'Todos los proyectos';

  final List<Map<String, dynamic>> _allReports = [
    {'id': '#17', 'project': 'Mantenimiento Planta Pacifico', 'condition': '#3', 'date': '01-10-2026', 'status': 'ABIERTA'},
    {'id': '#16', 'project': 'Mantenimiento Planta Pacifico', 'condition': '#3', 'date': '01-10-2026', 'status': 'ABIERTA'},
    {'id': '#15', 'project': 'Mantenimiento Planta Pacifico', 'condition': '#4', 'date': '01-10-2026', 'status': 'ABIERTA'},
    {'id': '#14', 'project': 'Montaje Planta Norte', 'condition': '#8', 'date': '29-09-2026', 'status': 'CERRADA'},
    {'id': '#13', 'project': 'Montaje Planta Norte', 'condition': '#3', 'date': '29-09-2026', 'status': 'ABIERTA'},
    {'id': '#12', 'project': 'Montaje Planta Norte', 'condition': '#1', 'date': '29-09-2026', 'status': 'CERRADA'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredReports = _allReports.where((r) {
      final passStatus = _statusFilter == 'Todos' || r['status'] == _statusFilter.toUpperCase();
      final passProject = _projectFilter == 'Todos los proyectos' || r['project'] == _projectFilter;
      return passStatus && passProject;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Eventos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Listado de reportes registrados.',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Proyecto',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      value: _projectFilter,
                      items: ['Todos los proyectos', 'Mantenimiento Planta Pacifico', 'Montaje Planta Norte']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) => setState(() => _projectFilter = val!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      value: _statusFilter,
                      items: ['Todos', 'Abierta', 'Cerrada']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _statusFilter = val!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredReports.length,
            itemBuilder: (context, index) {
              final report = filteredReports[index];
              final isAbierta = report['status'] == 'ABIERTA';
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? gris2Color : Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: verde1Color,
                    child: Text(
                      report['id'],
                      style: const TextStyle(color: verde6Color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    report['project'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Condición: ${report['condition']}  |  Fecha: ${report['date']}'),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAbierta ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isAbierta ? verde6Color : Colors.grey,
                      ),
                    ),
                    child: Text(
                      report['status'],
                      style: TextStyle(
                        color: isAbierta ? verde6Color : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () async {
                    final isClosed = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportDetailScreen(report: report, isLider: true),
                      ),
                    );
                    if (isClosed == true) {
                      setState(() {
                        report['status'] = 'CERRADA';
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

