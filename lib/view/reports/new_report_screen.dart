import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_qr_screen.dart';
import 'package:image_picker/image_picker.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<XFile> _evidence = [];
  String _selectedProject = DemoData.projects.first;
  String? _selectedCondition;

  @override
  void dispose() {
    _referenceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty && mounted) {
      setState(() => _evidence
        ..clear()
        ..addAll(images.take(3)));
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      DemoData.instance.addReport(
        project: _selectedProject,
        reference: _referenceController.text.trim(),
        condition: _selectedCondition!,
        description: _descriptionController.text.trim(),
        evidence: _evidence.map((file) => file.path).toList(),
      );
      final report = DemoData.instance.reports.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReportQrScreen(
            reportData: jsonEncode({
              'id': report['id'],
              'project': report['project'],
              'manager': report['manager'],
              'action': 'close_report',
            }),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingreso de Reporte',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Registra un evento detallando la condición y la descripción.',
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700])),
            const SizedBox(height: 16),
            if (constraints.maxWidth > 850)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildForm(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: 320, child: _buildGuide(isDark)),
                ],
              )
            else ...[
              _buildForm(isDark),
              const SizedBox(height: 12),
              _buildGuide(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) => Card(
        elevation: 1,
        color: isDark ? gris2Color : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PROYECTO',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProject,
                  isExpanded: true,
                  decoration: _inputDecoration(isDark),
                  items: DemoData.projects
                      .map((project) => DropdownMenuItem(
                          value: project,
                          child:
                              Text(project, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedProject = value);
                  },
                ),
                const SizedBox(height: 14),
                const Text('REFERENCIA',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _referenceController,
                  decoration: _inputDecoration(isDark,
                      hint: 'Ej: Chancador primario, Nivel 4...'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Campo requerido'
                      : null,
                ),
                const SizedBox(height: 14),
                const Text('CONDICIÓN DEL EVENTO (PARE)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration(isDark),
                  hint: const Text('Seleccione la condición identificada'),
                  initialValue: _selectedCondition,
                  items: DemoData.conditions
                      .map((condition) => DropdownMenuItem(
                          value: condition,
                          child: Text(condition,
                              maxLines: 2, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCondition = value),
                  validator: (value) =>
                      value == null ? 'Seleccione una condición' : null,
                ),
                const SizedBox(height: 14),
                const Text('DESCRIPCIÓN DETALLADA',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: _inputDecoration(isDark,
                      hint: 'Describe el contexto del hallazgo...'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Campo requerido'
                      : null,
                ),
                const SizedBox(height: 14),
                const Text('EVIDENCIA ADJUNTA (MÁX. 3 ARCHIVOS)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                        onPressed: _pickEvidence,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Elegir archivos')),
                    Text(
                        _evidence.isEmpty
                            ? 'Ningún archivo seleccionado'
                            : '${_evidence.length} archivo(s) seleccionado(s)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                if (_evidence.isNotEmpty)
                  ..._evidence.map((file) => Text(file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.check),
                    label: const Text('Registrar evento',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: verde6Color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildGuide(bool isDark) => Card(
        elevation: 1,
        color: isDark ? gris2Color : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GUÍA DE CONDICIONES DE USO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              ...DemoData.conditions.map((condition) {
                final selected = condition == _selectedCondition;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: selected
                        ? verde5Color.withValues(alpha: 0.3)
                        : (isDark ? Colors.white10 : verde1Color),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () =>
                          setState(() => _selectedCondition = condition),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(condition.substring(0, 3),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(condition.substring(4),
                                    style: const TextStyle(fontSize: 11))),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );

  InputDecoration _inputDecoration(bool isDark, {String? hint}) =>
      InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: isDark ? Colors.black12 : verde1Color,
      );
}
