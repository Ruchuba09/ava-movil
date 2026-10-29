import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/reports/camera_access.dart';
import 'package:avamovil/view/reports/report_qr_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final bool isLider;

  const ReportDetailScreen({
    super.key,
    required this.report,
    this.isLider = true,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descController = TextEditingController();
  final List<String> _evidence = [];
  bool _showReportEvidence = false;
  bool _showActivityLog = false;

  @override
  void initState() {
    super.initState();
    DemoData.instance.recordReportViewed(widget.report);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    if (_evidence.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puedes adjuntar un máximo de 3 evidencias.'),
        ),
      );
      return;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
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
              title: const Text('Elegir archivos o videos'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final paths = <String>[];
      if (source == 'camera') {
        if (!await ensureCameraPermission(context) || !mounted) return;
        final image = await ImagePicker().pickImage(source: ImageSource.camera);
        if (image != null) paths.add(image.path);
      } else if (source == 'gallery') {
        paths.addAll(
          (await ImagePicker().pickMultiImage()).map((file) => file.path),
        );
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.any,
          allowMultiple: true,
        );
        paths.addAll(
          (result?.files ?? <PlatformFile>[])
              .where((file) => file.path != null)
              .map((file) => file.path!),
        );
      }
      if (paths.isEmpty || !mounted) return;
      final availableSlots = 3 - _evidence.length;
      setState(() => _evidence.addAll(paths.take(availableSlots)));
      if (paths.length > availableSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Puedes adjuntar un máximo de 3 evidencias.'),
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

  void _closeReport() {
    if (!_formKey.currentState!.validate()) return;
    if (_evidence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adjunta al menos una evidencia para cerrar.'),
        ),
      );
      return;
    }
    DemoData.instance.closeReport(
      widget.report,
      _descController.text.trim(),
      _evidence,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte cerrado correctamente')),
    );
    final isOffline = widget.report['hasConnectionAtCreation'] == false;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (context) => isOffline
            ? ReportQrScreen(report: widget.report, isNewReport: false)
            : ReportDetailScreen(report: widget.report, isLider: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOpen = widget.report['status'] == 'ABIERTA';
    final reportDate =
        widget.report['createdAt'] as DateTime? ??
        widget.report['date'] as DateTime;
    final reportEvidence = (widget.report['evidence'] as List<dynamic>? ?? [])
        .map((path) => path.toString())
        .toList();
    final closeEvidence =
        (widget.report['closeEvidence'] as List<dynamic>? ?? [])
            .map((path) => path.toString())
            .toList();
    final activityLog =
        (widget.report['activityLog'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalle de Evento ${DemoData.instance.reportDisplayId(widget.report)}',
        ),
        actions: [
          IconButton(
            tooltip: 'Mostrar QR del reporte',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReportQrScreen(report: widget.report, isNewReport: false),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información General',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildInfoRow(
                      'Proyecto',
                      widget.report['project'].toString(),
                    ),
                    _buildInfoRow(
                      'Referencia (lugar)',
                      widget.report['reference'].toString(),
                    ),
                    _buildInfoRow(
                      'Condición',
                      widget.report['conditionText'].toString(),
                    ),
                    _buildInfoRow('Creado', _formatDateTime(reportDate)),
                    if (widget.report['closedAt'] is DateTime)
                      _buildInfoRow(
                        'Cerrado',
                        _formatDateTime(widget.report['closedAt'] as DateTime),
                      ),
                    _buildInfoRow('Estado', widget.report['status'].toString()),
                    if (widget.report['isThirdParty'] == true) ...[
                      _buildInfoRow(
                        'Persona reportada',
                        (widget.report['subject'] ?? widget.report['reporter'])
                            .toString(),
                      ),
                      _buildInfoRow(
                        'Creado por',
                        (widget.report['createdBy'] ??
                                widget.report['reporter'])
                            .toString(),
                      ),
                    ] else
                      _buildInfoRow(
                        'Reportado por',
                        widget.report['reporter'].toString(),
                      ),
                    _buildInfoRow(
                      'Jefe de cuadrilla',
                      (widget.report['originalManager'] ??
                              widget.report['manager'])
                          .toString(),
                    ),
                    _buildInfoRow(
                      'Encargado de cierre',
                      widget.report['manager'].toString(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Descripción',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.report['description'].toString()),
                    if (!isOpen &&
                        (widget.report['closeDescription'] as String)
                            .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Descripción del cierre',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.report['closeDescription'].toString()),
                    ],
                  ],
                ),
              ),
            ),
            if (!isOpen && closeEvidence.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Evidencia del cierre',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildEvidenceGrid(closeEvidence),
            ],
            if (isOpen && widget.isLider) ...[
              const SizedBox(height: 24),
              const Text(
                'Cierre de Reporte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.black12 : verde1Color,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Ingrese la descripción del cierre'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Evidencia del cierre (máx. 3 archivos)'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickEvidence,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Agregar evidencia'),
                        ),
                        if (_evidence.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildEvidenceGrid(_evidence, removable: true),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _closeReport,
                            icon: const Icon(Icons.check_circle),
                            label: const Text(
                              'Cerrar Flujo del Reporte',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
            ],
            const SizedBox(height: 24),
            if (activityLog.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _showActivityLog = !_showActivityLog,
                ),
                icon: Icon(
                  _showActivityLog
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                label: Text(
                  '${_showActivityLog ? 'Ocultar' : 'Mostrar'} registro de actividad',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              if (_showActivityLog) ...[
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registro de actividad',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        ...activityLog.map((activity) {
                          final at = activity['at'];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              activity['type'] == 'closed'
                                  ? Icons.task_alt
                                  : activity['type'] == 'connection'
                                  ? Icons.wifi
                                  : activity['type'] == 'qr_scanned'
                                  ? Icons.qr_code_scanner
                                  : Icons.assignment_outlined,
                              color: activity['type'] == 'closed'
                                  ? Colors.cyan
                                  : verde6Color,
                            ),
                            title: Text(activity['description'].toString()),
                            subtitle: at is DateTime
                                ? Text(_formatDateTime(at))
                                : null,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: reportEvidence.isEmpty
                  ? null
                  : () => setState(
                      () => _showReportEvidence = !_showReportEvidence,
                    ),
              icon: Icon(
                _showReportEvidence
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildEvidenceGrid(reportEvidence),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReportQrScreen(report: widget.report, isNewReport: false),
                ),
              ),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Mostrar QR del reporte'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
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
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Widget _buildEvidenceGrid(List<String> paths, {bool removable = false}) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: paths.map((path) {
          final fileName = path.split(RegExp(r'[/\\]')).last;
          final isImage = _isImagePath(path);
          final isVideo = _isVideoPath(path);
          return SizedBox(
            width: 104,
            child: Stack(
              children: [
                Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? gris2Color
                      : verde1Color,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openEvidence(path),
                    child: SizedBox(
                      width: 104,
                      child: Column(
                        children: [
                          if (isImage)
                            Image.file(
                              File(path),
                              width: 104,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(
                                    height: 88,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 36,
                                    ),
                                  ),
                            )
                          else
                            SizedBox(
                              height: 88,
                              child: Icon(
                                isVideo
                                    ? Icons.play_circle_outline
                                    : Icons.insert_drive_file_outlined,
                                size: 36,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (removable)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar evidencia',
                      onPressed: () => setState(() => _evidence.remove(path)),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      );

  bool _isImagePath(String path) => RegExp(
    r'\.(jpe?g|png|gif|bmp|webp)$',
    caseSensitive: false,
  ).hasMatch(path);

  bool _isVideoPath(String path) => RegExp(
    r'\.(mp4|mov|m4v|webm|mkv|avi)$',
    caseSensitive: false,
  ).hasMatch(path);

  Future<void> _openEvidence(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El archivo ya no está disponible.')),
        );
      }
      return;
    }

    if (_isImagePath(path)) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (_isVideoPath(path)) {
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => _VideoEvidenceScreen(file: file),
        ),
      );
      return;
    }

    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el archivo: ${result.message}'),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir el archivo: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }
}

class _VideoEvidenceScreen extends StatefulWidget {
  final File file;

  const _VideoEvidenceScreen({required this.file});

  @override
  State<_VideoEvidenceScreen> createState() => _VideoEvidenceScreenState();
}

class _VideoEvidenceScreenState extends State<_VideoEvidenceScreen> {
  late final VideoPlayerController _controller = VideoPlayerController.file(
    widget.file,
  );
  late final Future<void> _initialized = _controller.initialize();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reproducir video')),
    body: Center(
      child: FutureBuilder<void>(
        future: _initialized,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('No se pudo cargar el video.');
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                IconButton.filled(
                  iconSize: 48,
                  onPressed: () => setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  }),
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(playedColor: verde6Color),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}