import 'package:flutter/foundation.dart';

class DemoData extends ChangeNotifier {
  DemoData._() {
    _seedReports();
    notifications.addAll([
      {
        'id': 'N-1',
        'recipientId': 1,
        'reportId':
            reports.firstWhere((report) => report['managerId'] == 1)['id'],
        'title': 'Reporte pendiente de cierre',
        'message': 'Hay un reporte PARE asignado a tu cuadrilla.',
        'read': false,
      },
      {
        'id': 'N-2',
        'recipientId': 1,
        'reportId':
            reports.firstWhere((report) => report['managerId'] == 1)['id'],
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
      'email': 'carlos.gomez@empresa.cl',
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
      'name': 'admin@empresa.cl',
      'email': 'admin@empresa.cl',
      'role': 'ADMINISTRADOR',
      'project': 'Todos los proyectos',
    },
  ];

  final List<Map<String, dynamic>> workers = [
    {
      'id': 11,
      'name': 'Juan Pérez',
      'email': 'juan.perez@empresa.cl',
      'role': 'Operador',
      'leaderId': 1
    },
    {
      'id': 12,
      'name': 'María Soto',
      'email': 'maria.soto@empresa.cl',
      'role': 'Mecánica',
      'leaderId': 1
    },
    {
      'id': 13,
      'name': 'Diego Fuentes',
      'email': 'diego.fuentes@empresa.cl',
      'role': 'Rigger',
      'leaderId': 1
    },
    {
      'id': 14,
      'name': 'Camila Torres',
      'email': 'camila.torres@empresa.cl',
      'role': 'Prevencionista',
      'leaderId': 1
    },
    {
      'id': 21,
      'name': 'Andrés Silva',
      'email': 'andres.silva@empresa.cl',
      'role': 'Operador',
      'leaderId': 2
    },
    {
      'id': 22,
      'name': 'Valentina Díaz',
      'email': 'valentina.diaz@empresa.cl',
      'role': 'Soldadora',
      'leaderId': 2
    },
    {
      'id': 23,
      'name': 'Felipe Araya',
      'email': 'felipe.araya@empresa.cl',
      'role': 'Rigger',
      'leaderId': 2
    },
    {
      'id': 24,
      'name': 'Daniela Leiva',
      'email': 'daniela.leiva@empresa.cl',
      'role': 'Mecánica',
      'leaderId': 2
    },
  ];

  final List<Map<String, dynamic>> reports = [];
  final List<Map<String, dynamic>> notifications = [];
  int _nextNotificationId = 3;

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
      .where((report) =>
          (report['subjectId'] ?? report['reporterId']) == workerId ||
          report['createdById'] == workerId)
      .toList();

  List<Map<String, dynamic>> openReportsFirst(
          Iterable<Map<String, dynamic>> source) =>
      [
        ...source.where((report) => report['status'] == 'ABIERTA'),
        ...source.where((report) => report['status'] != 'ABIERTA'),
      ];

  int leaderIdForProject(String project) {
    final manager = _users.where((user) => user['project'] == project);
    return (manager.isEmpty ? _users.first : manager.first)['id'] as int;
  }

  List<Map<String, dynamic>> workersForProject(String project) {
    final leaderId = leaderIdForProject(project);
    return workers
        .where((worker) => worker['leaderId'] == leaderId)
        .toList();
  }

  bool canCloseReport(Map<String, dynamic> report) {
    final managerId = report['managerId'] as int;
    return currentUser['id'] == managerId;
  }

  List<Map<String, dynamic>> get currentUserNotifications => notifications
      .where((notification) => notification['recipientId'] == currentUser['id'])
      .toList();

  int get unreadNotificationCount => currentUserNotifications
      .where((notification) => notification['read'] == false)
      .length;

  void signIn(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    final user = _users.where((user) => user['email'] == normalizedEmail);
    if (user.isNotEmpty) {
      currentUser = Map<String, dynamic>.from(user.first);
    } else {
      final worker =
          workers.where((worker) => worker['email'] == normalizedEmail);
      if (worker.isNotEmpty) {
        final leaderId = worker.first['leaderId'] as int;
        currentUser = {
          ...worker.first,
          'project':
              _users.firstWhere((user) => user['id'] == leaderId)['project'],
        };
      } else {
        currentUser = Map<String, dynamic>.from(_users.first);
      }
    }
    notifyListeners();
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
        ? workers.firstWhere((worker) =>
            worker['id'] == subjectWorkerId &&
            worker['leaderId'] == leaderIdForProject(project))
        : null;
    final reporter = currentUser;
    final managerId = subjectWorker?['leaderId'] as int? ??
        (workers.any((worker) => worker['id'] == reporter['id'])
            ? workers.firstWhere((worker) => worker['id'] == reporter['id'])[
                'leaderId'] as int
            : leaderIdForProject(project));
    final manager = _users.firstWhere((user) => user['id'] == managerId);
    final responsibleId = managerId;
    final responsible = manager;
    final reportId = '#${200 + reports.length}';
    final subject = subjectWorker ?? reporter;
    final createdAt = DateTime.now();
    final report = <String, dynamic>{
      'id': reportId,
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
        {
          'type': 'created',
          'description': 'Tarjeta PARE creada',
          'at': createdAt,
        },
        {
          'type': 'connection',
          'description': hasConnection
              ? 'Conexión disponible; notificación interna registrada para el encargado'
              : 'Sin conexión; se debe informar al encargado para completar el cierre',
          'at': createdAt,
        },
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
    activityLog.add({
      'type': 'closed',
      'description': 'Flujo cerrado por ${currentUser['name']}',
      'at': closedAt,
    });
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

  void markNotificationRead(Map<String, dynamic> notification) {
    notification['read'] = true;
    notifyListeners();
  }

  void deleteReadNotifications() {
    final userId = currentUser['id'];
    notifications.removeWhere((notification) =>
        notification['recipientId'] == userId && notification['read'] == true);
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
    const reporters = [
      'Juan Pérez',
      'María Soto',
      'Diego Fuentes',
      'Camila Torres'
    ];
    final seedDate = DateTime(2026, 10, 8);
    for (var index = 0; index < 48; index++) {
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
      reports.add({
        'id': '#${200 - index}',
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
        'reporterId': 11 + (index % 4),
        'reporter': reporters[index % reporters.length],
        'managerId': managerId,
        'manager': managerId == 1 ? 'Carlos Gómez' : 'Patricia Rojas',
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
            {
              'type': 'closed',
              'description': 'Flujo cerrado',
              'at': closedAt,
            },
        ],
      });
    }
  }
}
