import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:avamovil/view/reports/report_qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  test('demo login authenticates the four configured accounts', () {
    final data = DemoData.instance;
    final accounts = <String, String>{
      'admin@ejemplo.cl': 'ADMINISTRADOR',
      'analista@ejemplo.cl': 'ANALISTA',
      'jfcua@ejemplo.cl': 'JEFE DE CUADRILLA',
      'trabajador@ejemplo.cl': 'Operador',
    };

    for (final account in accounts.entries) {
      expect(data.authenticate(account.key, '1234'), isTrue);
      expect(data.currentUser['role'], account.value);
    }
    expect(data.authenticate('admin@ejemplo.cl', '1234'), isTrue);
    expect(data.currentUserTeamReports.length, data.reports.length);
    expect(data.canTriggerEmergencyAlert, isFalse);
    expect(data.canScanReportQr, isFalse);
    expect(data.authenticate('analista@ejemplo.cl', '1234'), isTrue);
    expect(data.currentUserTeamReports.length, data.reports.length);
    expect(data.canTriggerEmergencyAlert, isFalse);
    expect(data.canScanReportQr, isFalse);
    expect(data.authenticate('jfcua@ejemplo.cl', '1234'), isTrue);
    expect(data.currentUserTeamReports.length, data.reports.length);
    expect(data.canTriggerEmergencyAlert, isTrue);
    expect(data.canScanReportQr, isTrue);
    expect(data.authenticate('trabajador@ejemplo.cl', '1234'), isTrue);
    expect(data.isWorker, isTrue);
    expect(data.canScanReportQr, isFalse);
    expect(data.currentUserTeamReports, data.currentUserReports);
    expect(data.currentUserReports, isNotEmpty);
    expect(
      data.currentUserReports.every(
        (report) =>
            report['createdById'] == data.currentUser['id'] ||
            report['subjectId'] == data.currentUser['id'],
      ),
      isTrue,
    );
    expect(data.canTriggerEmergencyAlert, isTrue);

    final currentUserId = data.currentUser['id'];
    expect(data.authenticate('admin@ejemplo.cl', 'incorrecta'), isFalse);
    expect(data.currentUser['id'], currentUserId);
    expect(data.authenticate('desconocido@ejemplo.cl', '1234'), isFalse);
  });

  test(
    'third-party reports route to the subject manager and require close data',
    () {
      final data = DemoData.instance;

      data.addReport(
        project: DemoData.projects[1],
        reference: 'Equipo de prueba',
        condition: DemoData.conditions.first,
        description: 'Descripción de prueba',
        evidence: const [],
        isThirdParty: true,
        subjectWorkerId: 21,
      );

      final report = data.reports.first;
      expect(report['isThirdParty'], isTrue);
      expect(report['createdBy'], data.currentUser['name']);
      expect(report['subject'], 'Andrés Silva');
      expect(report['managerId'], 2);
      expect(report['originalManager'], 'Patricia Rojas');
      expect(data.reportsForWorker(21), contains(report));
      expect(data.currentUserReports, contains(report));
      expect(report['createdAt'], isA<DateTime>());
      expect(report['hasConnectionAtCreation'], isTrue);
      expect(report['activityLog'], hasLength(2));

      data.recordReportViewed(report);
      expect(report['activityLog'], hasLength(3));
      expect(report['activityLog'].last['type'], 'viewed');

      expect(
        () => data.closeReport(report, ' ', const ['evidencia.jpg']),
        throwsArgumentError,
      );
      expect(
        () => data.closeReport(report, 'Cierre válido', const []),
        throwsArgumentError,
      );
      expect(report['status'], 'ABIERTA');

      data.closeReport(report, 'Cierre válido', const ['evidencia.jpg']);
      expect(report['status'], 'CERRADA');
      expect(report['closeDescription'], 'Cierre válido');
      expect(report['closeEvidence'], ['evidencia.jpg']);
      expect(report['closedAt'], isA<DateTime>());
      expect(report['activityLog'], hasLength(4));
    },
  );

  test(
    'offline report keeps QR connection status without notifying manager',
    () {
      final data = DemoData.instance;
      final managerNotificationsBefore = data.notifications
          .where((notification) => notification['recipientId'] == 2)
          .length;
      data.addReport(
        project: DemoData.projects[1],
        reference: 'Equipo offline',
        condition: DemoData.conditions.first,
        description: 'Descripción de prueba',
        evidence: const [],
        isThirdParty: true,
        subjectWorkerId: 22,
        hasConnection: false,
      );

      final report = data.reports.first;
      final managerNotificationsAfter = data.notifications
          .where((notification) => notification['recipientId'] == 2)
          .length;
      expect(report['hasConnectionAtCreation'], isFalse);
      expect(managerNotificationsAfter, managerNotificationsBefore);
    },
  );

  test(
    'offline QR transfers unique reports and scan/closure trace both ways',
    () {
      final data = DemoData.instance;
      data.authenticate('trabajador@ejemplo.cl', '1234');
      data.addReport(
        project: DemoData.projects.first,
        reference: 'Acceso norte',
        condition: DemoData.conditions.first,
        description: 'Reporte creado sin conexión',
        evidence: const ['foto-trabajador.jpg'],
        isThirdParty: false,
        hasConnection: false,
      );

      final workerReport = data.reports.first;
      final workerQr = data.reportForQr(workerReport);
      expect(workerReport['id'], startsWith('#LOCAL-'));
      expect(workerReport['displayId'], matches(RegExp(r'^#\d+$')));
      expect(workerQr['displayId'], workerReport['displayId']);
      expect(workerQr['evidenceCount'], 1);

      data.reports.remove(workerReport);
      data.authenticate('jfcua@ejemplo.cl', '1234');
      final supervisorReport = data.importReportFromQr(workerQr);
      expect(supervisorReport['id'], workerReport['id']);
      expect(supervisorReport['reference'], 'Acceso norte');
      expect(supervisorReport['evidence'], isEmpty);

      data.recordReportQrScanned(supervisorReport);
      expect(supervisorReport['activityLog'].last['type'], 'qr_scanned');
      expect(supervisorReport['activityLog'].last['actor'], 'Carlos Gómez');

      data.closeReport(supervisorReport, 'Área asegurada', const [
        'foto-cierre.jpg',
      ]);
      final supervisorQr = data.reportForQr(supervisorReport);

      data.reports.remove(supervisorReport);
      data.reports.add(workerReport);
      data.authenticate('trabajador@ejemplo.cl', '1234');
      final updatedWorkerReport = data.importReportFromQr(supervisorQr);
      expect(updatedWorkerReport, same(workerReport));
      expect(updatedWorkerReport['status'], 'CERRADA');
      expect(updatedWorkerReport['closeDescription'], 'Área asegurada');
      expect(
        updatedWorkerReport['activityLog'].where(
          (event) => event['type'] == 'qr_scanned',
        ),
        hasLength(1),
      );
      expect(updatedWorkerReport['activityLog'].last['type'], 'closed');
      expect(updatedWorkerReport['closeEvidenceCount'], 1);

      final activityCount = updatedWorkerReport['activityLog'].length;
      data.importReportFromQr(supervisorQr);
      expect(updatedWorkerReport['activityLog'], hasLength(activityCount));

      data.addReport(
        project: DemoData.projects.first,
        reference: 'Acceso sur',
        condition: DemoData.conditions.first,
        description: 'Segundo reporte sin conexión',
        evidence: const [],
        isThirdParty: false,
        hasConnection: false,
      );
      expect(data.reports.first['id'], isNot(workerReport['id']));
      expect(
        int.parse(
              (data.reports.first['displayId'] as String).substring(1),
            ),
        int.parse((workerReport['displayId'] as String).substring(1)) + 1,
      );
    },
  );

  testWidgets('QR sharing is only shown for offline reports', (tester) async {
    final data = DemoData.instance;
    data.addReport(
      project: DemoData.projects.first,
      reference: 'Reporte con conexión',
      condition: DemoData.conditions.first,
      description: 'Reporte online',
      evidence: const [],
      isThirdParty: false,
      hasConnection: true,
    );
    final onlineReport = data.reports.first;
    data.addReport(
      project: DemoData.projects.first,
      reference: 'Reporte sin conexión',
      condition: DemoData.conditions.first,
      description: 'Reporte offline',
      evidence: const [],
      isThirdParty: false,
      hasConnection: false,
    );
    final offlineReport = data.reports.first;

    await tester.pumpWidget(
      MaterialApp(
        home: ReportDetailScreen(report: onlineReport, isLider: false),
      ),
    );
    expect(find.byIcon(Icons.qr_code_2), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: ReportDetailScreen(report: offlineReport, isLider: false),
      ),
    );
    expect(find.byIcon(Icons.qr_code_2), findsNWidgets(2));
  });

  testWidgets('workers cannot open the QR scanner directly', (tester) async {
    final data = DemoData.instance;
    data.authenticate('trabajador@ejemplo.cl', '1234');

    await tester.pumpWidget(const MaterialApp(home: ReportQrScannerScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Solo el supervisor puede escanear tarjetas PARE.'),
      findsOneWidget,
    );
    expect(find.byType(MobileScanner), findsNothing);
  });

  test(
    'current user reports include cards assigned to the signed-in worker',
    () {
      final data = DemoData.instance;
      data.signIn('andres.silva@empresa.cl');

      expect(
        data.currentUserReports.any((report) => report['subjectId'] == 21),
        isTrue,
      );
    },
  );

  test('default user has self and third-party seeded reports', () {
    final data = DemoData.instance;
    data.signIn('carlos.gomez@empresa.cl');
    final reports = data.currentUserReports;

    expect(
      reports.map((report) => report['id']),
      containsAll(['#200', '#199', '#198']),
    );
    expect(
      reports.firstWhere((report) => report['id'] == '#199')['isThirdParty'],
      isTrue,
    );
    expect(
      reports.firstWhere((report) => report['id'] == '#198')['subject'],
      'Carlos Gómez',
    );
  });

  test('management sees all reports while workers only see their own', () {
    final data = DemoData.instance;
    for (final email in [
      'admin@ejemplo.cl',
      'analista@ejemplo.cl',
      'jfcua@ejemplo.cl',
    ]) {
      expect(data.authenticate(email, '1234'), isTrue);
      expect(data.currentUserTeamReports, data.reports);
    }

    expect(data.authenticate('trabajador@ejemplo.cl', '1234'), isTrue);
    expect(data.currentUserTeamReports, data.currentUserReports);
    expect(data.currentUserReports.length, lessThan(data.reports.length));
  });

  test(
    'emergency alert records its recipient and notification audit trail',
    () {
      final data = DemoData.instance;
      data.authenticate('trabajador@ejemplo.cl', '1234');

      final alert = data.triggerEmergencyAlert();
      expect(alert['sender'], 'Juan Pérez');
      expect(alert['recipient'], 'Carlos Gómez');
      expect(alert['status'], 'REGISTRADA EN LA APLICACIÓN');
      expect(alert['activityLog'], hasLength(2));

      final notification = data.notifications.firstWhere(
        (item) => item['emergencyAlertId'] == alert['id'],
      );
      expect(notification['recipientId'], 1);
      expect(notification['read'], isFalse);
      expect(notification['emergencyAlertId'], alert['id']);

      data.authenticate('jfcua@ejemplo.cl', '1234');
      expect(data.currentUserNotifications, contains(notification));
      data.markNotificationRead(notification);
      expect(notification['read'], isTrue);
      expect(alert['activityLog'], hasLength(3));
      expect(alert['activityLog'].last['type'], 'notification_viewed');

      data.authenticate('jfcua@ejemplo.cl', '1234');
      final supervisorAlert = data.triggerEmergencyAlert();
      expect(supervisorAlert['recipient'], 'Administrador');
      expect(supervisorAlert['recipientId'], 3);

      data.signIn('admin@empresa.cl');
      expect(() => data.triggerEmergencyAlert(), throwsA(isA<StateError>()));
    },
  );

  test('unfiltered worker report lists keep open reports first', () {
    final data = DemoData.instance;
    final sorted = data.openReportsFirst([
      {'id': '#closed', 'status': 'CERRADA'},
      {'id': '#open', 'status': 'ABIERTA'},
      {'id': '#closed-2', 'status': 'CERRADA'},
      {'id': '#open-2', 'status': 'ABIERTA'},
    ]);

    expect(sorted.map((report) => report['id']), [
      '#open',
      '#open-2',
      '#closed',
      '#closed-2',
    ]);
  });
}
