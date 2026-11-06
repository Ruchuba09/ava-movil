import 'dart:io';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/offline_reports_sync.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const usuario = 'trabajador@ejemplo.cl';
const clave = OfflineStore.myReportsKey;

Map<String, dynamic> evento(int id) => {
  'id_evento': id,
  'estado': 'abierto',
  'fecha_creacion': '2026-11-05T10:00:00.000000Z',
  'referencia': 'Lugar $id',
  'campo_no_usado': 'no se guarda',
  'proyecto': {'id_proyecto': 1, 'nombre': 'Proyecto', 'presupuesto': 99},
};

PaginaEventos pagina(int numero, int ultima, int porPagina) => PaginaEventos(
  eventos: [
    for (var i = 0; i < porPagina; i++) evento((numero - 1) * porPagina + i + 1),
  ],
  pagina: numero,
  ultimaPagina: ultima,
  total: ultima * porPagina,
  proyectos: const [],
);

void main() {
  late Directory directorio;
  late OfflineStore store;
  late List<Duration> esperas;
  late DateTime ahora;
  late OfflineReportsSync sync;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directorio = await Directory.systemTemp.createTemp('avamovil-sync-');
    await databaseFactoryFfi.setDatabasesPath(directorio.path);
  });

  setUp(() async {
    await AvaMovilDatabase.instance.deleteDB();
    store = OfflineStore();
    esperas = [];
    ahora = DateTime(2026, 11, 5, 12);
    sync = OfflineReportsSync(
      store: store,
      esperar: (duracion) async => esperas.add(duracion),
      ahora: () => ahora,
    );
  });

  tearDown(() => AvaMovilDatabase.instance.close());

  tearDownAll(() => directorio.delete(recursive: true));

  Future<List<dynamic>?> guardados() =>
      store.readJsonList(userKey: usuario, key: clave);

  test('Guarda todas las páginas en orden, con pausas y sin campos de más', () async {
    final pedidas = <int>[];
    final ok = await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async {
        pedidas.add(n);
        return pagina(n, 12, 100);
      },
    );

    expect(ok, isTrue);
    expect(pedidas, List.generate(12, (i) => i + 1));
    expect(esperas, hasLength(11));

    final lista = (await guardados())!;
    expect(lista, hasLength(1200));
    expect(lista.map((e) => e['id_evento']), List.generate(1200, (i) => i + 1));
    expect(lista.first.containsKey('campo_no_usado'), isFalse);
    expect(lista.first['proyecto'], {'id_proyecto': 1, 'nombre': 'Proyecto'});

    final estado = await sync.estado(userKey: usuario, clave: clave);
    expect(estado!.completa, isTrue);
  });

  test('Ninguna fila queda cerca del límite de 2 MB de Android', () async {
    await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async => pagina(n, 41, 100),
    );

    final db = await AvaMovilDatabase.instance.database;
    final filas = await db.rawQuery(
      'SELECT COUNT(*) AS partes, MAX(LENGTH(payload_json)) AS mayor '
      "FROM offline_cache WHERE cache_key LIKE '$clave.parte.%'",
    );
    expect(filas.single['partes'], 9);
    expect(filas.single['mayor'] as int, lessThan(1024 * 1024));
    expect(await guardados(), hasLength(4100));
  });

  test('Una lista más corta reemplaza por completo a la anterior', () async {
    await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async => pagina(n, 12, 100),
    );
    await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      forzar: true,
      pedirPagina: (n) async => pagina(n, 1, 3),
    );

    expect(await guardados(), hasLength(3));
  });

  test('Espera lo que pide Laravel ante un 429 y continúa', () async {
    var intentos = 0;
    final ok = await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async {
        if (n == 2 && intentos++ == 0) {
          throw const ApiException(
            statusCode: 429,
            message: 'Too Many Attempts.',
            retryAfter: 37,
          );
        }
        return pagina(n, 3, 100);
      },
    );

    expect(ok, isTrue);
    expect(esperas, contains(const Duration(seconds: 37)));
    expect(await guardados(), hasLength(300));
  });

  test('Si la descarga se corta, conserva la copia completa anterior', () async {
    await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async => pagina(n, 2, 100),
    );

    final ok = await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      forzar: true,
      pedirPagina: (n) async {
        if (n == 2) throw const SocketException('sin red');
        return pagina(n, 5, 100);
      },
    );

    expect(ok, isFalse);
    expect(await guardados(), hasLength(200));
    expect((await sync.estado(userKey: usuario, clave: clave))!.completa, isTrue);
  });

  test('Sin copia previa, guarda lo descargado y lo marca incompleto', () async {
    final ok = await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async {
        if (n == 2) throw const SocketException('sin red');
        return pagina(n, 5, 100);
      },
    );

    expect(ok, isFalse);
    expect(await guardados(), hasLength(100));
    expect((await sync.estado(userKey: usuario, clave: clave))!.completa, isFalse);
  });

  test('No repite la descarga antes de 15 minutos, salvo que esté incompleta', () async {
    var pedidas = 0;
    Future<PaginaEventos> pedir(int n) async {
      pedidas++;
      return pagina(n, 1, 1);
    }

    await sync.sincronizar(userKey: usuario, clave: clave, pedirPagina: pedir);
    await sync.sincronizar(userKey: usuario, clave: clave, pedirPagina: pedir);
    expect(pedidas, 1);

    ahora = ahora.add(const Duration(minutes: 16));
    await sync.sincronizar(userKey: usuario, clave: clave, pedirPagina: pedir);
    expect(pedidas, 2);
  });

  test('Un 401 no borra la copia y detiene la descarga', () async {
    await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async => pagina(n, 1, 5),
    );

    final ok = await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      forzar: true,
      pedirPagina: (_) async => throw const ApiException(
        statusCode: 401,
        message: 'Unauthenticated.',
      ),
    );

    expect(ok, isFalse);
    expect(await guardados(), hasLength(5));
  });

  test('Lee copias antiguas guardadas en una sola fila', () async {
    await store.saveJson(
      userKey: usuario,
      key: clave,
      value: [evento(1), evento(2)],
    );

    expect(await guardados(), hasLength(2));
  });

  test('Separa las copias de cada usuario', () async {
    await sync.sincronizar(
      userKey: usuario,
      clave: clave,
      pedirPagina: (n) async => pagina(n, 1, 5),
    );

    expect(
      await store.readJsonList(userKey: 'otro@ejemplo.cl', key: clave),
      isNull,
    );
  });
}
