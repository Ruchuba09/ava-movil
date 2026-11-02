import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/database/sync_queue.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/camera_access.dart';
import 'package:avamovil/view/reports/report_qr_screen.dart';
import 'package:avamovil/view/widgets/selection_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:http/http.dart' as http;

class NewReportScreen extends StatefulWidget {
  final String accessToken;
  final String? userKey;

  const NewReportScreen({super.key, required this.accessToken, this.userKey});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<XFile> _evidence = [];
  int? _selectedProjectId;
  List<Map<String, dynamic>> _proyectosReales = [];
  List<Map<String, dynamic>> _trabajadoresReales = [];
  List<Map<String, dynamic>> _condicionesReales = [];
  bool _cargandoProyectos = true;
  String? _errorProyectos;
  int? _selectedConditionId;
  int? _selectedSubjectId;
  bool _isThirdParty = false;
  bool _isSubmitting = false;
  int _tipoEventoPare = 4;
  final OfflineStore _offlineStore = OfflineStore();

  String get _userKey =>
      widget.userKey ?? OfflineStore.userKeyFor(DemoData.instance.currentUser);

  List<Map<String, dynamic>> get _condicionesPare {
    if (_condicionesReales.isNotEmpty) return _condicionesReales;
    return DemoData.conditions
        .asMap()
        .entries
        .map((entry) => {'id_condicion': entry.key + 1, 'nombre': entry.value})
        .toList();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarProyectos();
  }

  Future<void> _cargarProyectos() async {
    final servicio = ApiService(accessToken: widget.accessToken);

    try {
      final opciones = await servicio.obtenerOpcionesEventos();
      _applyEventOptions(opciones);
      try {
        await _offlineStore.saveJson(
          userKey: _userKey,
          key: OfflineStore.eventOptionsKey,
          value: opciones,
        );
      } catch (error) {
        debugPrint(
          'No se pudieron guardar localmente las opciones PARE: $error',
        );
      }
    } catch (error) {
      debugPrint('Error al cargar opciones PARE: $error');
      if (error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        if (mounted) {
          setState(() {
            _cargandoProyectos = false;
            _errorProyectos =
                'La sesión ya no está autorizada. Inicia sesión en línea.';
          });
        }
        return;
      }

      try {
        final cachedOptions = await _offlineStore.readJson(
          userKey: _userKey,
          key: OfflineStore.eventOptionsKey,
        );
        if (cachedOptions is Map) {
          _applyEventOptions(Map<String, dynamic>.from(cachedOptions));
          debugPrint('Opciones PARE cargadas desde la caché local.');
        } else if (mounted) {
          setState(() {
            _cargandoProyectos = false;
            _errorProyectos =
                'No hay opciones sincronizadas para usar offline.';
          });
        }
      } catch (cacheError) {
        debugPrint(
          'No se pudieron leer las opciones PARE locales: $cacheError',
        );
        if (mounted) {
          setState(() {
            _cargandoProyectos = false;
            _errorProyectos = 'No se pudieron leer las opciones guardadas.';
          });
        }
      }
    } finally {
      servicio.close();
    }
  }

  void _applyEventOptions(Map<String, dynamic> opciones) {
    final proyectos = ((opciones['proyectos'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final trabajadores = ((opciones['trabajadores'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final tiposEvento = ((opciones['tiposEvento'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final tiposParePorNombre = tiposEvento.where((tipo) {
      final nombre =
          (tipo['nombre'] ?? tipo['name'] ?? tipo['descripcion'] ?? '')
              .toString();
      return nombre.toLowerCase().contains('pare');
    });
    final tiposParePorId = tiposEvento.where(
      (tipo) => num.tryParse('${tipo['id_tipo_evento']}') == 4,
    );
    final tipoPare = tiposParePorNombre.isNotEmpty
        ? tiposParePorNombre.first
        : tiposParePorId.isNotEmpty
        ? tiposParePorId.first
        : null;
    final condiciones =
        (opciones['condiciones'] ??
                opciones['condicionesPare'] ??
                opciones['condiciones_pare'])
            as List?;
    final condicionesReales = (condiciones ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              (item['id_condicion'] ?? item['id']) is num &&
              (item['nombre'] ?? item['descripcion'] ?? item['detalle'])
                  is String,
        )
        .toList();

    if (!mounted) return;

    setState(() {
      _proyectosReales = proyectos;
      _trabajadoresReales = trabajadores;
      _condicionesReales = condicionesReales;
      if (tipoPare?['id_tipo_evento'] is num) {
        _tipoEventoPare = (tipoPare!['id_tipo_evento'] as num).toInt();
      }
      _cargandoProyectos = false;
      _errorProyectos = null;
    });
    debugPrint(
      'Opciones PARE disponibles: ${proyectos.length} proyectos, '
      '${trabajadores.length} trabajadores.',
    );
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
        if (!await ensureCameraPermission(context) || !mounted) return;
        final image = await ImagePicker().pickImage(source: ImageSource.camera);
        if (image != null) picked.add(image);
      } else if (source == 'gallery') {
        picked.addAll(await ImagePicker().pickMultiImage());
      } else {
        final result = await FilePicker.pickFiles(
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
            content: Text('Puedes adjuntar un máximo de 3 archivos.'),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo cargar la evidencia: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final proyectoId = _selectedProjectId;
    final condicionId = _selectedConditionId;

    if (proyectoId == null || condicionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un proyecto y una condición.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final servicio = ApiService(accessToken: widget.accessToken);

    try {
      final evento = await servicio.registrarEvento(
        idTipoEvento: _tipoEventoPare,
        condicion: condicionId,
        descripcion: _descriptionController.text.trim(),
        referencia: _referenceController.text.trim(),
        idProyecto: proyectoId,
        esParaMi: !_isThirdParty,
        idTrabajador: _isThirdParty ? _selectedSubjectId : null,
        evidencias: _evidence,
      );

      if (!mounted) return;

      final idEvento = evento['id_evento'];
      final proyecto = _proyectosReales.firstWhere(
        (item) => item['id_proyecto'] == proyectoId,
      );
      final fecha = DateTime.now();
      final reporte = <String, dynamic>{
        'id_evento': idEvento,
        'id': 'EVENTO-$idEvento',
        'displayId': '#$idEvento',
        'project': proyecto['nombre'],
        'condition': '#$condicionId',
        'conditionText': _conditionLabel(condicionId),
        'reference': _referenceController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': 'ABIERTA',
        'date': fecha,
        'createdAt': fecha,
        'hasConnectionAtCreation': true,
        'isThirdParty': _isThirdParty,
        'reporter': 'Usuario autenticado',
        'createdBy': 'Usuario autenticado',
        'subject': 'No especificado',
        'evidence': evento['evidencia'] ?? [],
      };

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              ReportQrScreen(report: reporte, isNewReport: true),
        ),
      );
    } on SocketException catch (error) {
      await _queueReportOffline(proyectoId, condicionId, error);
    } on http.ClientException catch (error) {
      await _queueReportOffline(proyectoId, condicionId, error);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el evento: $error')),
      );
    } finally {
      servicio.close();

      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _queueReportOffline(
    int projectId,
    int conditionId,
    Object networkError,
  ) async {
    try {
      final project = _proyectosReales.firstWhere(
        (item) => item['id_proyecto'] == projectId,
      );
      final evidence = <Map<String, Object?>>[];
      for (final file in _evidence) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw ArgumentError('Cada evidencia debe pesar máximo 5 MB.');
        }
        evidence.add({'name': file.name, 'bytes_base64': base64Encode(bytes)});
      }

      final payload = <String, Object?>{
        'user_key': _userKey,
        'id_tipo_evento': _tipoEventoPare,
        'condicion': conditionId,
        'descripcion': _descriptionController.text.trim(),
        'referencia': _referenceController.text.trim(),
        'id_proyecto': projectId,
        'proyecto_nombre': project['nombre'],
        'es_para_mi': !_isThirdParty,
        if (_isThirdParty) 'id_trabajador': _selectedSubjectId,
        'evidencias': evidence,
        'fecha_creacion_local': DateTime.now().toUtc().toIso8601String(),
      };

      final db = await AvaMovilDatabase.instance.database;
      await db.transaction((transaction) async {
        await const SyncQueue().enqueue(
          executor: transaction,
          entity: 'eventos',
          operation: 'crear',
          payload: payload,
        );
      });

      debugPrint('Reporte guardado para sincronizar luego: $networkError');
      if (!mounted) return;

      _referenceController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedProjectId = null;
        _selectedConditionId = null;
        _selectedSubjectId = null;
        _isThirdParty = false;
        _evidence.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reporte guardado en este dispositivo. Se sincronizará al recuperar conexión.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('No se pudo guardar el reporte offline: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el reporte local: $error'),
          ),
        );
      }
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
            const Text(
              'Ingreso de Tarjeta Pare',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra un evento detallando la condición y la descripción.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
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

  String _conditionLabel(int conditionId) {
    final matchingCondition = _condicionesPare.where(
      (condition) =>
          (condition['id_condicion'] ?? condition['id']) == conditionId,
    );
    if (matchingCondition.isEmpty) return 'Condición #$conditionId';
    final condition = matchingCondition.first;
    return (condition['nombre'] ??
            condition['descripcion'] ??
            condition['detalle'])
        .toString();
  }

  Widget _buildForm(bool isDark) => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_cargandoProyectos)
              const Center(child: CircularProgressIndicator())
            else if (_errorProyectos != null)
              Text(_errorProyectos!, style: const TextStyle(color: Colors.red))
            else
              SelectionField<int>(
                label: 'PROYECTO',
                hint: 'Selecciona un proyecto',
                value: _selectedProjectId,
                options: _proyectosReales
                    .map(
                      (proyecto) => SelectionOption<int>(
                        value: proyecto['id_proyecto'] as int,
                        label: proyecto['nombre'] as String,
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                    _selectedSubjectId = null;
                  });
                },
                validator: (value) =>
                    value == null ? 'Selecciona un proyecto' : null,
              ),

            const SizedBox(height: 14),
            const Text(
              '¿PARA QUIÉN ES EL REPORTE?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
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
                key: ValueKey(_selectedProjectId),
                label: 'PERSONA REPORTADA',
                hint: 'Selecciona a la persona reportada',
                value: _selectedSubjectId,
                options: _trabajadoresReales
                    .where((trabajador) {
                      final proyectos = trabajador['proyectos'] as List? ?? [];

                      return proyectos.any(
                        (proyecto) =>
                            proyecto['id_proyecto'] == _selectedProjectId,
                      );
                    })
                    .map(
                      (trabajador) => SelectionOption<int>(
                        value: trabajador['id_trabajador'] as int,
                        label: trabajador['nombre'] as String,
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedSubjectId = value);
                },
                validator: (value) {
                  if (_isThirdParty && value == null) {
                    return 'Selecciona a la persona reportada';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'REFERENCIA (LUGAR)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _referenceController,
              decoration: _inputDecoration(
                isDark,
                hint: 'Ej: Chancador primario, Nivel 4...',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo requerido'
                  : null,
            ),
            const SizedBox(height: 14),

            SelectionField<int>(
              label: 'CONDICIÓN DEL EVENTO (PARE)',
              wrapOptionLabels: true,
              hint: 'Seleccione la condición identificada',
              value: _selectedConditionId,
              options: _condicionesPare.map((condition) {
                final id = condition['id_condicion'] ?? condition['id'];
                final label =
                    condition['nombre'] ??
                    condition['descripcion'] ??
                    condition['detalle'];
                return SelectionOption<int>(
                  value: (id as num).toInt(),
                  label: label.toString(),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedConditionId = value);
              },
              validator: (value) =>
                  value == null ? 'Seleccione una condición' : null,
            ),

            const SizedBox(height: 14),
            const Text(
              'DESCRIPCIÓN DETALLADA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _inputDecoration(
                isDark,
                hint: 'Describe el contexto del hallazgo...',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo requerido'
                  : null,
            ),
            const SizedBox(height: 14),
            const Text(
              'EVIDENCIA ADJUNTA (MÁX. 3 ARCHIVOS)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickEvidence,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Agregar evidencia'),
                ),
                Text(
                  _evidence.isEmpty
                      ? 'Ningún archivo seleccionado'
                      : '${_evidence.length} archivo(s) seleccionado(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (_evidence.isNotEmpty)
              ..._evidence.map(
                (file) => Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
  }) => Material(
    color: selected ? verde5Color.withValues(alpha: 0.2) : Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? verde6Color : Colors.grey.shade500,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? verde6Color : null),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: isDark ? Colors.black12 : verde1Color,
      );
}
