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
}
