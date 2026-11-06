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

  group('La vista depende del rol aunque exista id_trabajador', () {
    void iniciarComoTrabajadorDe(List<Object> roles) {
      DemoData.instance.setAuthenticatedUser({
        'id_user': 1,
        'id_trabajador': 1,
        'email': 'usuario@ejemplo.cl',
        'roles': roles,
      }, fallbackEmail: 'usuario@ejemplo.cl');
    }

    test('Administrador y Supervisor usan la vista de gestión', () {
      for (final rol in ['Administrador', 'Supervisor']) {
        iniciarComoTrabajadorDe([
          {'id_rol': 1, 'nombre': rol},
        ]);
        expect(DemoData.instance.isWorker, isFalse, reason: rol);
      }
    });

    test('Una sesión real no recibe notificaciones de la demo', () {
      iniciarComoTrabajadorDe([
        {'id_rol': 1, 'nombre': 'Administrador'},
      ]);
      expect(DemoData.instance.isApiSession, isTrue);
      expect(DemoData.instance.unreadNotificationCount, 0);
    });

    test('Se reconoce también en el perfil offline', () {
      iniciarComoTrabajadorDe([
        {'name': 'Supervisor'},
      ]);
      expect(DemoData.instance.isWorker, isFalse);
    });

    test('Trabajador y Jefe de zona siguen en la vista de trabajador', () {
      for (final rol in ['Trabajador', 'Jefe de zona']) {
        iniciarComoTrabajadorDe([
          {'id_rol': 3, 'nombre': rol},
        ]);
        expect(DemoData.instance.isWorker, isTrue, reason: rol);
      }
    });
  });
}
