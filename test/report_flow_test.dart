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
