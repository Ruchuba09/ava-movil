import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/report_qr_screen.dart';
import 'package:avamovil/view/widgets/selection_field.dart';
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
  int? _selectedSubjectId;
  bool _isThirdParty = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _referenceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir fotos'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Elegir archivos'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = <XFile>[];
      if (source == 'camera') {
        final image = await ImagePicker().pickImage(source: ImageSource.camera);
        if (image != null) picked.add(image);
      } else if (source == 'gallery') {
        picked.addAll(await ImagePicker().pickMultiImage());
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: true,
        );
        for (final file in result?.files ?? <PlatformFile>[]) {
          if (file.path != null) picked.add(XFile(file.path!, name: file.name));
        }
      }
      if (picked.isEmpty || !mounted) return;
      final availableSlots = 3 - _evidence.length;
      setState(() => _evidence.addAll(picked.take(availableSlots)));
      if (picked.length > availableSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Puedes adjuntar un máximo de 3 archivos.')),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se pudo cargar la evidencia: ${error.message ?? error.code}')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    var hasSignal = false;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      hasSignal =
          connectivity.any((result) => result != ConnectivityResult.none);
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se pudo verificar la conexión: ${error.message ?? error.code}')),
        );
      }
    }
    final demoData = DemoData.instance;
    demoData.addReport(
      project: _selectedProject,
      reference: _referenceController.text.trim(),
      condition: _selectedCondition!,
      description: _descriptionController.text.trim(),
      evidence: _evidence.map((file) => file.path).toList(),
      isThirdParty: _isThirdParty,
      subjectWorkerId: _isThirdParty ? _selectedSubjectId : null,
      hasConnection: hasSignal,
    );
    final report = demoData.reports.first;
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportQrScreen(report: report),
      ),
    );
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
            const Text('Ingreso de Tarjeta Pare',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Registra un evento detallando la condición y la descripción.',
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700])),
            const SizedBox(height: 16),
            SizedBox(
              width: constraints.maxWidth > 850 ? 720 : double.infinity,
              child: _buildForm(isDark),
            ),
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
                SelectionField<String>(
                  label: 'PROYECTO',
                  value: _selectedProject,
                  options: DemoData.projects
                      .map((project) =>
                          SelectionOption(value: project, label: project))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedProject = value;
                      _selectedSubjectId = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                const Text('¿PARA QUIÉN ES EL REPORTE?',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _reportSubjectChoice(
                        label: 'Para mí',
                        icon: Icons.person_outline,
                        selected: !_isThirdParty,
                        onTap: () => setState(() {
                          _isThirdParty = false;
                          _selectedSubjectId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _reportSubjectChoice(
                        label: 'Para un tercero',
                        icon: Icons.people_outline,
                        selected: _isThirdParty,
                        onTap: () => setState(() => _isThirdParty = true),
                      ),
                    ),
                  ],
                ),
                if (_isThirdParty) ...[
                  const SizedBox(height: 10),
                  SelectionField<int>(
                    key: ValueKey(_selectedProject),
                    label: 'PERSONA REPORTADA',
                    hint: 'Selecciona a la persona reportada',
                    value: _selectedSubjectId,
                    options: DemoData.instance
                        .workersForProject(_selectedProject)
                        .map((worker) => SelectionOption<int>(
                              value: worker['id'] as int,
                              label: worker['name'] as String,
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSubjectId = value),
                    validator: (value) => _isThirdParty && value == null
                        ? DemoData.instance
                                .workersForProject(_selectedProject)
                                .isEmpty
                            ? 'No hay personas disponibles para este proyecto'
                            : 'Selecciona a la persona reportada'
                        : null,
                  ),
                ],
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
                SelectionField<String>(
                  label: 'CONDICIÓN DEL EVENTO (PARE)',
                  wrapOptionLabels: true,
                  hint: 'Seleccione la condición identificada',
                  value: _selectedCondition,
                  options: DemoData.conditions
                      .map((condition) => SelectionOption(
                            value: condition,
                            label: condition,
                          ))
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
                        label: const Text('Agregar evidencia')),
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
                    onPressed: _isSubmitting ? null : _submitForm,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _isSubmitting ? 'Guardando...' : 'Registrar evento',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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

  Widget _reportSubjectChoice({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Material(
        color:
            selected ? verde5Color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(
                  color: selected ? verde6Color : Colors.grey.shade500),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? verde6Color : null),
                const SizedBox(width: 6),
                Flexible(
                  child:
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
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
