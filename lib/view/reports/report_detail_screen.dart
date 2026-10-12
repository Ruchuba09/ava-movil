import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_qr_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final bool isLider;

  const ReportDetailScreen(
      {super.key, required this.report, this.isLider = true});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descController = TextEditingController();
  final List<File> _evidence = [];
  bool _showReportEvidence = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && _evidence.length < 3) {
      setState(() {
        _evidence.add(File(pickedFile.path));
      });
    } else if (_evidence.length >= 3 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puedes adjuntar un máximo de 3 fotos.')),
      );
    }
  }

  void _closeReport() {
    if (_formKey.currentState!.validate()) {
      DemoData.instance.closeReport(widget.report, _descController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte cerrado correctamente')),
      );
      Navigator.pop(context, true); // Retorna true para indicar que se cerró
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOpen = widget.report['status'] == 'ABIERTA';
    final reportDate = widget.report['date'] as DateTime;
    final reportEvidence = (widget.report['evidence'] as List<dynamic>? ?? [])
        .map((path) => path.toString())
        .toList();
    final dateText =
        '${reportDate.day.toString().padLeft(2, '0')}-${reportDate.month.toString().padLeft(2, '0')}-${reportDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Evento ${widget.report['id']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: isDark ? gris2Color : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Información General',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildInfoRow(
                        'Proyecto', widget.report['project'].toString()),
                    _buildInfoRow(
                        'Referencia', widget.report['reference'].toString()),
                    _buildInfoRow(
                        'Condición', widget.report['conditionText'].toString()),
                    _buildInfoRow('Fecha', dateText),
                    _buildInfoRow('Estado', widget.report['status'].toString()),
                    _buildInfoRow(
                        'Reportado por', widget.report['reporter'].toString()),
                    _buildInfoRow(
                        'Jefe de cuadrilla',
                        (widget.report['originalManager'] ??
                                widget.report['manager'])
                            .toString()),
                    _buildInfoRow('Encargado de cierre',
                        widget.report['manager'].toString()),
                    const SizedBox(height: 16),
                    const Text('Descripción',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.report['description'].toString()),
                    if (!isOpen &&
                        (widget.report['closeDescription'] as String)
                            .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Descripción del cierre',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(widget.report['closeDescription'].toString()),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: reportEvidence.isEmpty
                  ? null
                  : () => setState(
                      () => _showReportEvidence = !_showReportEvidence),
              icon: Icon(_showReportEvidence
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              label: Text(
                '${_showReportEvidence ? 'Ocultar' : 'Mostrar'} evidencia del reporte (${reportEvidence.length})',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (_showReportEvidence && reportEvidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                color: isDark ? gris2Color : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reportEvidence.map((path) {
                      final file = File(path);
                      final fileName = path.split(RegExp(r'[/\\]')).last;
                      final isImage = RegExp(r'\.(jpe?g|png|gif|webp)$',
                              caseSensitive: false)
                          .hasMatch(path);
                      return SizedBox(
                        width: 104,
                        child: Column(
                          children: [
                            if (isImage)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  file,
                                  width: 104,
                                  height: 88,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(
                                    height: 88,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(
                                height: 88,
                                child: Icon(Icons.insert_drive_file_outlined,
                                    size: 36),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportQrScreen(
                    report: widget.report,
                    isNewReport: false,
                  ),
                ),
              ),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Mostrar QR del reporte'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 24),
            if (isOpen && widget.isLider) ...[
              const Text('Cierre de Reporte',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                color: isDark ? gris2Color : Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Descripción del cierre',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: isDark ? Colors.black12 : verde1Color,
                          ),
                          validator: (value) => value!.isEmpty
                              ? 'Ingrese la descripción del cierre'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Evidencia del cierre (Fotos)'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Cámara'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Galería'),
                            ),
                          ],
                        ),
                        if (_evidence.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: _evidence.map((file) {
                              return Stack(
                                children: [
                                  Image.file(file,
                                      width: 80, height: 80, fit: BoxFit.cover),
                                  Positioned(
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _evidence.remove(file)),
                                      child: const Icon(Icons.cancel,
                                          color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          )
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _closeReport,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Cerrar Flujo del Reporte',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verde6Color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text('$title:',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
