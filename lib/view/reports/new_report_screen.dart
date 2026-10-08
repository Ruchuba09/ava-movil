import 'package:flutter/material.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_qr_screen.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCondition;

  final List<String> _conditions = [
    '01. Si las condiciones de trabajo NO son seguras.',
    '02. Si NO tiene las herramientas adecuadas...',
    '03. Si NO tiene los EPP adecuados.',
    '04. Si NO sabe o no está capacitado...',
  ];

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Simulate saving locally for offline support
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardando datos localmente...')),
      );
      
      // Navigate to QR Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReportQrScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingreso de Reporte',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra un evento detallando la condición y la descripción.',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            color: isDark ? gris2Color : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REFERENCIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Ej: Chancador primario, Nivel 4...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDark ? Colors.black12 : verde1Color,
                      ),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('CONDICIÓN DEL EVENTO (PARE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDark ? Colors.black12 : verde1Color,
                      ),
                      hint: const Text('Seleccione la condición identificada'),
                      value: _selectedCondition,
                      items: _conditions.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => _selectedCondition = val),
                      validator: (value) => value == null ? 'Seleccione una condición' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('DESCRIPCIÓN DETALLADA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextFormField(
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe el contexto del hallazgo...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDark ? Colors.black12 : verde1Color,
                      ),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('EVIDENCIA ADJUNTA (MÁX 3 ARCHIVOS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Elegir archivos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verde1Color,
                            foregroundColor: verde6Color,
                            elevation: 0,
                            side: const BorderSide(color: verde3Color),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Ningún archivo seleccionado')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.check),
                        label: const Text('Registrar evento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: verde6Color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

