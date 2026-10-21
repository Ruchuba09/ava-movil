import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class DemoData extends ChangeNotifier {
  DemoData._() {
    _seedReports();
    notifications.addAll([
      {
        'id': 'N-1',
        'recipientId': 1,
        'reportId': reports.firstWhere(
          (report) => report['managerId'] == 1,
        )['id'],
        'title': 'Reporte pendiente de cierre',
        'message': 'Hay un reporte PARE asignado a tu cuadrilla.',
        'read': false,
      },
      {
        'id': 'N-2',
        'recipientId': 1,
        'reportId': reports.firstWhere(
          (report) => report['managerId'] == 1,
        )['id'],
        'title': 'Nuevo hallazgo registrado',
        'message': 'Revisa el detalle y completa el flujo de cierre.',
        'read': false,
      },
    ]);
  }
  static final DemoData instance = DemoData._();

  static const List<String> conditions = [
    '01. Si las condiciones de trabajo NO son seguras.',
    '02. Si NO tiene las herramientas adecuadas o están en mal estado.',
    '03. Si NO tiene los EPP adecuados.',
    '04. Si NO sabe o no está capacitado / autorizado para realizar la actividad.',
    '05. Si NO hay un procedimiento / instructivo asociado a la actividad o si existe pero no ha sido difundido.',
    '06. NO contar con el apoyo de recursos humanos y/o materiales necesarios para realizar la actividad.',
    '07. NO contar con AST, VATS, ERT.',
    '08. NO contar con el o los permisos exigidos para realizar la actividad.',
    '09. NO encontrarse en condiciones físicas o emocionales para realizar la actividad.',
    '10. Otras condiciones no consideradas que impliquen un riesgo no controlado.',
  ];

  static const List<String> projects = [
    'Mantenimiento Planta Pacifico',
    'Montaje Planta Norte',
    'Ampliación Mina Sur',
  ];

  final List<Map<String, dynamic>> _users = [
    {
      'id': 1,
      'name': 'Carlos Gómez',
      'email': 'jfcua@ejemplo.cl',
      'role': 'JEFE DE CUADRILLA',
      'project': projects[0],
    },
    {
      'id': 2,
      'name': 'Patricia Rojas',
      'email': 'patricia.rojas@empresa.cl',
      'role': 'JEFA DE CUADRILLA',
      'project': projects[1],
    },
    {
      'id': 3,
      'name': 'Administrador',
      'email': 'admin@ejemplo.cl',
      'role': 'ADMINISTRADOR',
      'project': 'Todos los proyectos',
    },
    {
      'id': 4,
      'name': 'Analista',
      'email': 'analista@ejemplo.cl',
      'role': 'ANALISTA',
      'project': 'Todos los proyectos',
    },
  ];

  final List<Map<String, dynamic>> workers = [
    {
      'id': 11,
      'name': 'Juan Pérez',
      'email': 'trabajador@ejemplo.cl',
      'role': 'Operador',
      'leaderId': 1,
    },
    {
      'id': 12,
      'name': 'María Soto',
      'email': 'maria.soto@empresa.cl',
      'role': 'Mecánica',
      'leaderId': 1,
    },
    {
      'id': 13,
      'name': 'Diego Fuentes',
      'email': 'diego.fuentes@empresa.cl',
      'role': 'Rigger',
      'leaderId': 1,
    },
    {
      'id': 14,
      'name': 'Camila Torres',
      'email': 'camila.torres@empresa.cl',
      'role': 'Prevencionista',
      'leaderId': 1,
    },
    {
      'id': 21,
      'name': 'Andrés Silva',
      'email': 'andres.silva@empresa.cl',
      'role': 'Operador',
      'leaderId': 2,
    },
    {
      'id': 22,
      'name': 'Valentina Díaz',
      'email': 'valentina.diaz@empresa.cl',
      'role': 'Soldadora',
      'leaderId': 2,
    },
    {
      'id': 23,
      'name': 'Felipe Araya',
      'email': 'felipe.araya@empresa.cl',
      'role': 'Rigger',
      'leaderId': 2,
    },
    {
      'id': 24,
      'name': 'Daniela Leiva',
      'email': 'daniela.leiva@empresa.cl',
      'role': 'Mecánica',
      'leaderId': 2,
    },
  ];

  final List<Map<String, dynamic>> reports = [];
  final List<Map<String, dynamic>> notifications = [];
  int _nextNotificationId = 3;
  int _nextEmergencyAlertId = 1;
  final List<Map<String, dynamic>> emergencyAlerts = [];
  final Map<String, int> _demoAccountUserIds = {
    'admin@ejemplo.cl': 3,
    'analista@ejemplo.cl': 4,
    'jfcua@ejemplo.cl': 1,
    'trabajador@ejemplo.cl': 11,
  };
  final Map<String, String> _demoAccountPasswords = {
    'admin@ejemplo.cl': '1234',
    'analista@ejemplo.cl': '1234',
    'jfcua@ejemplo.cl': '1234',
    'trabajador@ejemplo.cl': '1234',
  };

  Map<String, dynamic> currentUser = {
    'id': 1,
    'name': 'Carlos Gómez',
    'email': 'carlos.gomez@empresa.cl',
    'role': 'JEFE DE CUADRILLA',
    'project': projects[0],
  };

  List<Map<String, dynamic>> get currentUserWorkers => workers
      .where((worker) => worker['leaderId'] == currentUser['id'])
      .toList();

  List<Map<String, dynamic>> reportsForWorker(int workerId) => reports
      .where(
        (report) =>
            (report['subjectId'] ?? report['reporterId']) == workerId ||
            report['createdById'] == workerId,
      )
      .toList();

  List<Map<String, dynamic>> get currentUserReports {
    final userId = currentUser['id'];
    return reports
        .where(
          (report) =>
              (report['createdById'] ?? report['reporterId']) == userId ||
              report['subjectId'] == userId,
        )
        .toList();
  }

  bool get isWorker => currentUser['leaderId'] is int;

  bool get canScanReportQr {
    final role = currentUser['role'] as String;
    return role.startsWith('JEFE') || role.startsWith('JEFA');
  }

  int get currentUserLeaderId =>
      (currentUser['leaderId'] ?? currentUser['id']) as int;

  List<Map<String, dynamic>> get currentUserTeamReports =>
      isWorker ? currentUserReports : List<Map<String, dynamic>>.from(reports);

  bool get canTriggerEmergencyAlert {
    final role = currentUser['role'] as String;
    return currentUser['leaderId'] is int ||
        role.startsWith('JEFE') ||
        role.startsWith('JEFA');
  }

  List<Map<String, dynamic>> openReportsFirst(
    Iterable<Map<String, dynamic>> source,
  ) => [
    ...source.where((report) => report['status'] == 'ABIERTA'),
    ...source.where((report) => report['status'] != 'ABIERTA'),
  ];

  int leaderIdForProject(String project) {
    final manager = _users.where((user) => user['project'] == project);
    return (manager.isEmpty ? _users.first : manager.first)['id'] as int;
  }

  List<Map<String, dynamic>> workersForProject(String project) {
    final leaderId = leaderIdForProject(project);
    return workers.where((worker) => worker['leaderId'] == leaderId).toList();
  }

  bool canCloseReport(Map<String, dynamic> report) {
    final managerId = report['managerId'] as int;
    return currentUser['id'] == managerId;
  }

  String reportDisplayId(Map<String, dynamic> report) {
    final displayId = report['displayId'];
    if (displayId is String) return displayId;
    final id = report['id'] as String;
    return id.startsWith('#LOCAL-') ? _nextReportDisplayId() : id;
  }

  String _nextReportDisplayId() {
    final highestId = reports.fold<int>(200, (highest, report) {
      final displayId = report['displayId'] ?? report['id'];
      final number = int.tryParse(
        displayId.toString().replaceFirst(RegExp(r'^#'), ''),
      );
      return number != null && number > highest ? number : highest;
    });
    return '#${highestId + 1}';
  }

  Map<String, dynamic> reportForQr(Map<String, dynamic> report) => {
    'id': report['id'],
    'displayId': reportDisplayId(report),
    'project': report['project'],
    'condition': report['condition'],
    'conditionText': report['conditionText'],
    'reference': report['reference'],
    'date': _dateForQr(report['date']),
    'createdAt': _dateForQr(report['createdAt']),
    'status': report['status'],
    'hasConnectionAtCreation': report['hasConnectionAtCreation'],
    'reporterId': report['reporterId'],
    'reporter': report['reporter'],
    'createdById': report['createdById'] ?? report['reporterId'],
    'createdBy': report['createdBy'] ?? report['reporter'],
    'isThirdParty': report['isThirdParty'] == true,
    'subjectId': report['subjectId'] ?? report['reporterId'],
    'subject': report['subject'] ?? report['reporter'],
    'managerId': report['managerId'],
    'manager': report['manager'],
    'originalManager': report['originalManager'] ?? report['manager'],
    'description': report['description'],
    'evidenceCount': _attachmentCount(report, 'evidenceCount', 'evidence'),
    'closeDescription': report['closeDescription'] ?? '',
    'closedAt': _dateForQr(report['closedAt']),
    'closeEvidenceCount': _attachmentCount(
      report,
      'closeEvidenceCount',
      'closeEvidence',
    ),
    'activityLog': (report['activityLog'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_activityForQr)
        .toList(),
  };

  Map<String, dynamic> importReportFromQr(Map<dynamic, dynamic> payload) {
    final id = _requiredQrString(payload, 'id');
    final project = _requiredQrString(payload, 'project');
    final condition = _requiredQrString(payload, 'condition');
    final conditionText = _requiredQrString(payload, 'conditionText');
    final reference = _requiredQrString(payload, 'reference');
    final description = _requiredQrString(payload, 'description');
    final status = _requiredQrString(payload, 'status');
    if (status != 'ABIERTA' && status != 'CERRADA') {
      throw const FormatException('El estado de la tarjeta no es válido.');
    }

    final createdAt = _parseQrDate(payload['createdAt'] ?? payload['date']);
    if (createdAt == null) {
      throw const FormatException('La fecha de creación no es válida.');
    }
    final reporter = _requiredQrString(payload, 'reporter');
    final manager = _requiredQrString(payload, 'manager');
    final reporterId = _requiredQrInt(payload, 'reporterId');
    final managerId = _requiredQrInt(payload, 'managerId');
    final activityLog = _parseQrActivityLog(payload['activityLog']);
    final remoteReport = <String, dynamic>{
      'id': id,
      'displayId': payload['displayId'] is String
          ? payload['displayId']
          : (id.startsWith('#LOCAL-') ? _nextReportDisplayId() : id),
      'project': project,
      'condition': condition,
      'conditionText': conditionText,
      'reference': reference,
      'date': createdAt,
      'createdAt': createdAt,
      'status': status,
      'hasConnectionAtCreation': payload['hasConnectionAtCreation'] == true,
      'reporterId': reporterId,
      'reporter': reporter,
      'createdById': _optionalQrInt(payload['createdById']) ?? reporterId,
      'createdBy': payload['createdBy'] is String
          ? payload['createdBy']
          : reporter,
      'isThirdParty': payload['isThirdParty'] == true,
      'subjectId': _optionalQrInt(payload['subjectId']) ?? reporterId,
      'subject': payload['subject'] is String ? payload['subject'] : reporter,
      'managerId': managerId,
      'manager': manager,
      'originalManager': payload['originalManager'] is String
          ? payload['originalManager']
          : manager,
      'description': description,
      'evidence': <String>[],
      'evidenceCount': _optionalQrInt(payload['evidenceCount']) ?? 0,
      'closeDescription': payload['closeDescription'] is String
          ? payload['closeDescription']
          : '',
      'closeEvidence': <String>[],
      'closeEvidenceCount': _optionalQrInt(payload['closeEvidenceCount']) ?? 0,
      'activityLog': activityLog,
    };
    final closedAt = _parseQrDate(payload['closedAt']);
    if (closedAt != null) remoteReport['closedAt'] = closedAt;

    final matchingReports = reports.where((report) => report['id'] == id);
    if (matchingReports.isEmpty) {
      reports.insert(0, remoteReport);
      notifyListeners();
      return remoteReport;
    }

    final localReport = matchingReports.first;
    _mergeQrReport(localReport, remoteReport);
    notifyListeners();
    return localReport;
  }

  void recordReportQrScanned(Map<String, dynamic> report) {
    final activityLog =
        report['activityLog'] as List<Map<String, dynamic>>? ?? [];
    activityLog.add(
      _newActivityEvent(
        type: 'qr_scanned',
        description: 'Código QR escaneado por ${currentUser['name']}',
        actorId: currentUser['id'],
        actor: currentUser['name'] as String,
      ),
    );
    report['activityLog'] = activityLog;
    notifyListeners();
  }

  List<Map<String, dynamic>> get currentUserNotifications => notifications
      .where((notification) => notification['recipientId'] == currentUser['id'])
      .toList();

  int get unreadNotificationCount => currentUserNotifications
      .where((notification) => notification['read'] == false)
      .length;

  void signIn(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    final legacyEmails = {
      'carlos.gomez@empresa.cl': 1,
      'juan.perez@empresa.cl': 11,
      'admin@empresa.cl': 3,
    };
    final matchingUser = _users.where(
      (user) => user['email'] == normalizedEmail,
    );
    final matchingWorker = workers.where(
      (worker) => worker['email'] == normalizedEmail,
    );
    final userId =
        legacyEmails[normalizedEmail] ??
        (matchingUser.isNotEmpty
            ? matchingUser.first['id'] as int
            : matchingWorker.isNotEmpty
            ? matchingWorker.first['id'] as int
            : null);
    if (userId == null) {
      throw ArgumentError.value(email, 'email', 'Usuario desconocido.');
    }
    _setCurrentUserById(userId);
    notifyListeners();
  }

  bool authenticate(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    if (_demoAccountPasswords[normalizedEmail] != password) return false;
    final userId = _demoAccountUserIds[normalizedEmail];
    if (userId == null) {
      throw StateError('La cuenta de demostración no tiene usuario asociado.');
    }
    _setCurrentUserById(userId);
    notifyListeners();
    return true;
  }

  void _setCurrentUserById(int userId) {
    final matchingUser = _users.where((user) => user['id'] == userId);
    if (matchingUser.isNotEmpty) {
      currentUser = Map<String, dynamic>.from(matchingUser.first);
      return;
    }
    final worker = workers.firstWhere((item) => item['id'] == userId);
    final leaderId = worker['leaderId'] as int;
    currentUser = {
      ...worker,
      'project': _users.firstWhere((user) => user['id'] == leaderId)['project'],
    };
  }

  void addReport({
    required String project,
    required String reference,
    required String condition,
    required String description,
    required List<String> evidence,
    required bool isThirdParty,
    int? subjectWorkerId,
    bool hasConnection = true,
  }) {
    if (isThirdParty && subjectWorkerId == null) {
      throw ArgumentError('Debe seleccionar a la persona reportada.');
    }
    final subjectWorker = isThirdParty
        ? workers.firstWhere(
            (worker) =>
                worker['id'] == subjectWorkerId &&
                worker['leaderId'] == leaderIdForProject(project),
          )
        : null;
    final reporter = currentUser;
    final managerId =
        subjectWorker?['leaderId'] as int? ??
        (workers.any((worker) => worker['id'] == reporter['id'])
            ? workers.firstWhere(
                    (worker) => worker['id'] == reporter['id'],
                  )['leaderId']
                  as int
            : leaderIdForProject(project));
    final manager = _users.firstWhere((user) => user['id'] == managerId);
    final responsibleId = managerId;
    final responsible = manager;
    final reportId = '#LOCAL-${const Uuid().v4()}';
    final displayId = _nextReportDisplayId();
    final subject = subjectWorker ?? reporter;
    final createdAt = DateTime.now();
    final report = <String, dynamic>{
      'id': reportId,
      'displayId': displayId,
      'project': project,
      'condition': '#${conditions.indexOf(condition) + 1}',
      'conditionText': condition,
      'reference': reference,
      'date': createdAt,
      'createdAt': createdAt,
      'status': 'ABIERTA',
      'hasConnectionAtCreation': hasConnection,
      'reporterId': reporter['id'],
      'reporter': reporter['name'],
      'createdById': reporter['id'],
      'createdBy': reporter['name'],
      'isThirdParty': isThirdParty,
      'subjectId': subject['id'],
      'subject': subject['name'],
      'managerId': managerId,
      'manager': responsible['name'],
      'originalManager': manager['name'],
      'description': description,
      'evidence': evidence,
      'closeDescription': '',
      'activityLog': <Map<String, dynamic>>[
        _newActivityEvent(
          type: 'created',
          description: 'Tarjeta PARE creada por ${reporter['name']}',
          at: createdAt,
          actorId: reporter['id'],
          actor: reporter['name'] as String,
        ),
        _newActivityEvent(
          type: 'connection',
          description: hasConnection
              ? 'Conexión disponible al crear la tarjeta'
              : 'Tarjeta creada sin conexión; se comparte por código QR',
          at: createdAt,
        ),
      ],
    };
    reports.insert(0, report);
    if (hasConnection) {
      _addNotification(
        recipientId: responsibleId,
        reportId: reportId,
        title: 'Nuevo reporte PARE asignado',
        message: isThirdParty
            ? '${reporter['name']} registró un hallazgo para ${subject['name']} en $project.'
            : '${reporter['name']} registró un hallazgo en $project.',
      );
    }
    notifyListeners();
  }

  void closeReport(
    Map<String, dynamic> report,
    String closeDescription,
    List<String> evidence,
  ) {
    if (closeDescription.trim().isEmpty) {
      throw ArgumentError('La descripción del cierre es obligatoria.');
    }
    if (evidence.isEmpty) {
      throw ArgumentError('Debe adjuntar al menos una evidencia de cierre.');
    }
    report['status'] = 'CERRADA';
    report['closeDescription'] = closeDescription.trim();
    report['closeEvidence'] = List<String>.from(evidence);
    final closedAt = DateTime.now();
    report['closedAt'] = closedAt;
    final activityLog =
        report['activityLog'] as List<Map<String, dynamic>>? ?? [];
    activityLog.add(
      _newActivityEvent(
        type: 'closed',
        description: 'Flujo cerrado por ${currentUser['name']}',
        at: closedAt,
        actorId: currentUser['id'],
        actor: currentUser['name'] as String,
      ),
    );
    report['activityLog'] = activityLog;
    _addNotification(
      recipientId: report['reporterId'] as int,
      reportId: report['id'] as String,
      title: 'Reporte cerrado',
      message:
          'El encargado ${currentUser['name']} cerró el flujo del reporte.',
    );
    notifyListeners();
  }

  void recordReportViewed(Map<String, dynamic> report) {
    final activityLog =
        report['activityLog'] as List<Map<String, dynamic>>? ?? [];
    activityLog.add(
      _newActivityEvent(
        type: 'viewed',
        description: 'Tarjeta visualizada por ${currentUser['name']}',
        actorId: currentUser['id'],
        actor: currentUser['name'] as String,
      ),
    );
    report['activityLog'] = activityLog;
    notifyListeners();
  }

  void _mergeQrReport(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localActivity =
        local['activityLog'] as List<Map<String, dynamic>>? ?? [];
    final knownActivity = localActivity.map(_activityKey).toSet();
    for (final event
        in remote['activityLog'] as List<Map<String, dynamic>>? ?? []) {
      if (knownActivity.add(_activityKey(event))) {
        localActivity.add(event);
      }
    }
    local['activityLog'] = localActivity;

    if (remote['displayId'] is String) {
      local['displayId'] = remote['displayId'];
    }

    if (remote['status'] == 'CERRADA') {
      local['status'] = 'CERRADA';
      local['closeDescription'] = remote['closeDescription'];
      if (remote['closedAt'] is DateTime) {
        local['closedAt'] = remote['closedAt'];
      }
      local['closeEvidenceCount'] = remote['closeEvidenceCount'];
    }
    final remoteEvidenceCount = remote['evidenceCount'] as int;
    final localEvidenceCount =
        (local['evidence'] as List<dynamic>? ?? const []).length;
    local['evidenceCount'] = remoteEvidenceCount > localEvidenceCount
        ? remoteEvidenceCount
        : localEvidenceCount;
  }

  List<Map<String, dynamic>> _parseQrActivityLog(Object? value) {
    if (value == null) return [];
    if (value is! List) {
      throw const FormatException(
        'La trazabilidad de la tarjeta no es válida.',
      );
    }

    return value.map((item) {
      if (item is! Map) {
        throw const FormatException('Hay un evento de trazabilidad inválido.');
      }
      final event = Map<String, dynamic>.from(item);
      final type = _requiredQrString(event, 'type');
      final description = _requiredQrString(event, 'description');
      final at = _parseQrDate(event['at']);
      if (at == null) {
        throw const FormatException('La fecha de un evento no es válida.');
      }
      event['type'] = type;
      event['description'] = description;
      event['at'] = at;
      event['id'] = event['id'] is String ? event['id'] : _activityKey(event);
      return event;
    }).toList();
  }

  Map<String, dynamic> _activityForQr(Map<String, dynamic> event) => {
    ...event,
    'id': event['id'] is String ? event['id'] : _activityKey(event),
    'at': _dateForQr(event['at']),
  };

  String _activityKey(Map<String, dynamic> event) {
    final eventId = event['id'];
    if (eventId is String) return eventId;
    final at = _parseQrDate(event['at'])?.toIso8601String() ?? '';
    return '${event['type']}|$at|${event['actorId']}|${event['description']}';
  }

  Map<String, dynamic> _newActivityEvent({
    required String type,
    required String description,
    DateTime? at,
    Object? actorId,
    String? actor,
  }) => {
    'id': const Uuid().v4(),
    'type': type,
    'description': description,
    'at': at ?? DateTime.now(),
    'actorId': ?actorId,
    'actor': ?actor,
  };

  String _requiredQrString(Map<dynamic, dynamic> payload, String key) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Falta el dato "$key" de la tarjeta.');
    }
    return value;
  }

  int _requiredQrInt(Map<dynamic, dynamic> payload, String key) {
    final value = _optionalQrInt(payload[key]);
    if (value == null) {
      throw FormatException('El dato "$key" de la tarjeta no es válido.');
    }
    return value;
  }

  int? _optionalQrInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  DateTime? _parseQrDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String? _dateForQr(Object? value) {
    final date = _parseQrDate(value);
    return date?.toIso8601String();
  }

  int _attachmentCount(
    Map<String, dynamic> report,
    String countKey,
    String pathsKey,
  ) {
    final count = report[countKey];
    final localCount = (report[pathsKey] as List<dynamic>? ?? const []).length;
    return count is int && count > localCount ? count : localCount;
  }

  void markNotificationRead(Map<String, dynamic> notification) {
    if (notification['read'] == true) return;
    notification['read'] = true;
    final emergencyAlertId = notification['emergencyAlertId'];
    if (emergencyAlertId != null) {
      final alerts = emergencyAlerts.where(
        (alert) => alert['id'] == emergencyAlertId,
      );
      if (alerts.isNotEmpty) {
        final alert = alerts.first;
        (alert['activityLog'] as List<Map<String, dynamic>>).add({
          'type': 'notification_viewed',
          'description':
              'Alerta de emergencia visualizada por ${currentUser['name']}',
          'at': DateTime.now(),
          'actorId': currentUser['id'],
          'actor': currentUser['name'],
        });
      }
      notifyListeners();
      return;
    }
    final report = reports.where(
      (item) => item['id'] == notification['reportId'],
    );
    if (report.isNotEmpty) {
      final activityLog =
          report.first['activityLog'] as List<Map<String, dynamic>>? ?? [];
      activityLog.add({
        'type': 'notification_viewed',
        'description':
            'Notificación del reporte visualizada por ${currentUser['name']}',
        'at': DateTime.now(),
        'actorId': currentUser['id'],
        'actor': currentUser['name'],
      });
      report.first['activityLog'] = activityLog;
    }
    notifyListeners();
  }

  Map<String, dynamic> triggerEmergencyAlert() {
    final senderId = currentUser['id'] as int;
    final assignedLeaderId = currentUser['leaderId'];
    final currentRole = currentUser['role'] as String;
    final recipientId = assignedLeaderId is int
        ? assignedLeaderId
        : currentRole.startsWith('JEFE') || currentRole.startsWith('JEFA')
        ? 3
        : null;
    if (recipientId == null) {
      throw StateError('No hay un encargado asignado para esta cuenta.');
    }
    final leader = _users.firstWhere(
      (user) => user['id'] == recipientId,
      orElse: () => throw StateError('No se encontró a tu encargado.'),
    );
    final createdAt = DateTime.now();
    final alertId = 'E-${_nextEmergencyAlertId++}';
    final notificationId = 'N-${_nextNotificationId++}';
    final alert = <String, dynamic>{
      'id': alertId,
      'senderId': senderId,
      'sender': currentUser['name'],
      'senderRole': currentUser['role'],
      'recipientId': recipientId,
      'recipient': leader['name'],
      'createdAt': createdAt,
      'status': 'REGISTRADA EN LA APLICACIÓN',
      'activityLog': <Map<String, dynamic>>[
        {
          'type': 'triggered',
          'description':
              'Alerta de emergencia activada por ${currentUser['name']}',
          'at': createdAt,
          'actorId': senderId,
          'actor': currentUser['name'],
        },
        {
          'type': 'notification_registered',
          'description':
              'Notificación registrada para ${leader['name']} en la aplicación',
          'at': createdAt,
          'actorId': senderId,
          'actor': currentUser['name'],
        },
      ],
    };
    emergencyAlerts.insert(0, alert);
    notifications.insert(0, {
      'id': notificationId,
      'recipientId': recipientId,
      'emergencyAlertId': alertId,
      'title': 'ALERTA DE EMERGENCIA',
      'message': '${currentUser['name']} solicita ayuda inmediata.',
      'read': false,
      'createdAt': createdAt,
    });
    notifyListeners();
    return alert;
  }

  void deleteReadNotifications() {
    final userId = currentUser['id'];
    notifications.removeWhere(
      (notification) =>
          notification['recipientId'] == userId && notification['read'] == true,
    );
    notifyListeners();
  }

  void _addNotification({
    required int recipientId,
    required String reportId,
    required String title,
    required String message,
  }) {
    notifications.insert(0, {
      'id': 'N-${_nextNotificationId++}',
      'recipientId': recipientId,
      'reportId': reportId,
      'title': title,
      'message': message,
      'read': false,
      'createdAt': DateTime.now(),
    });
  }

  void _seedReports() {
    final seedDate = DateTime(2026, 10, 8);
    for (var index = 0; index < 72; index++) {
      final projectIndex = index % projects.length;
      final conditionIndex = index % conditions.length;
      final project = projects[projectIndex];
      final managerId = projectIndex == 1 ? 2 : 1;
      final date = seedDate.subtract(Duration(days: index % 38));
      final isClosed = index % 3 == 0;
      final createdAt = DateTime(
        date.year,
        date.month,
        date.day,
        7 + index % 11,
        (index * 7) % 60,
      );
      final closedAt = isClosed
          ? createdAt.add(Duration(minutes: 20 + (index * 13) % 120))
          : null;
      final baseReporterId = 11 + (index % 4);
      final reporterId = index == 2 ? 14 : (index < 2 ? 1 : baseReporterId);
      final reporter = reporterId == 1
          ? 'Carlos Gómez'
          : workers.firstWhere((worker) => worker['id'] == reporterId)['name']
                as String;
      final subjectId = index == 0 || index == 2 || index % 6 == 0
          ? 1
          : (index == 1 ? 21 : reporterId);
      final subject = subjectId == 1
          ? 'Carlos Gómez'
          : workers.firstWhere((worker) => worker['id'] == subjectId)['name']
                as String;
      final createdById = index == 2
          ? reporterId
          : (index < 2 ? 1 : reporterId);
      final manager = managerId == 1 ? 'Carlos Gómez' : 'Patricia Rojas';
      reports.add({
        'id': '#${200 - index}',
        'displayId': '#${200 - index}',
        'project': project,
        'condition': '#${conditionIndex + 1}',
        'conditionText': conditions[conditionIndex],
        'reference': [
          'Chancador primario, Nivel 4',
          'Correa transportadora CV-12',
          'Taller de mantenimiento',
          'Plataforma de montaje, Sector B',
        ][index % 4],
        'date': date,
        'createdAt': createdAt,
        'status': isClosed ? 'CERRADA' : 'ABIERTA',
        if (closedAt != null) 'closedAt': closedAt,
        'hasConnectionAtCreation': true,
        'reporterId': reporterId,
        'reporter': reporter,
        'createdById': createdById,
        'createdBy': reporter,
        'subjectId': subjectId,
        'subject': subject,
        'isThirdParty': subjectId != createdById,
        'managerId': managerId,
        'manager': manager,
        'originalManager': manager,
        'description': [
          'Se detectó una condición insegura durante la inspección del área de trabajo.',
          'El equipo asignado presenta desgaste y requiere revisión antes de continuar.',
          'Se observó falta de elementos de protección personal completos.',
          'La actividad comenzó sin que el procedimiento fuera difundido al equipo.',
        ][index % 4],
        'evidence': <String>[],
        'closeDescription': isClosed
            ? 'Se corrigió la condición y se verificó el área antes de reiniciar la actividad.'
            : '',
        'activityLog': <Map<String, dynamic>>[
          {
            'type': 'created',
            'description': 'Tarjeta PARE creada',
            'at': createdAt,
          },
          if (closedAt != null)
            {'type': 'closed', 'description': 'Flujo cerrado', 'at': closedAt},
        ],
      });
    }
  }
}
