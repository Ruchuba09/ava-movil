import 'package:avamovil/dev/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(report['activityLog'], hasLength(3));
  });

  test('offline report keeps QR connection status without notifying manager',
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
  });

  test('current user reports include cards assigned to the signed-in worker',
      () {
    final data = DemoData.instance;
    data.signIn('andres.silva@empresa.cl');

    expect(
      data.currentUserReports.any((report) => report['subjectId'] == 21),
      isTrue,
    );
  });

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

  test('unfiltered worker report lists keep open reports first', () {
    final data = DemoData.instance;
    final sorted = data.openReportsFirst([
      {'id': '#closed', 'status': 'CERRADA'},
      {'id': '#open', 'status': 'ABIERTA'},
      {'id': '#closed-2', 'status': 'CERRADA'},
      {'id': '#open-2', 'status': 'ABIERTA'},
    ]);

    expect(
      sorted.map((report) => report['id']),
      ['#open', '#open-2', '#closed', '#closed-2'],
    );
  });
}
