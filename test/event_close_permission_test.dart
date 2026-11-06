import 'package:avamovil/dev/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void iniciarSesionCon(List<Object> roles) {
    DemoData.instance.setAuthenticatedUser({
      'id_user': 1,
      'email': 'usuario@ejemplo.cl',
      'roles': roles,
    }, fallbackEmail: 'usuario@ejemplo.cl');
  }

  test('Solo un administrador puede cerrar eventos', () {
    iniciarSesionCon([
      {'id_rol': 1, 'nombre': 'Administrador'},
    ]);
    expect(DemoData.instance.puedeCerrarEventos, isTrue);

    iniciarSesionCon([
      {'id_rol': 2, 'nombre': 'Supervisor'},
    ]);
    expect(DemoData.instance.puedeCerrarEventos, isFalse);
  });

  test('Reconoce el rol guardado en el perfil offline', () {
    iniciarSesionCon([
      {'name': 'Administrador'},
    ]);
    expect(DemoData.instance.puedeCerrarEventos, isTrue);
  });
}
