import 'package:avamovil/database/principal.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AvaMovilDatabase {
  static final AvaMovilDatabase instance =
      AvaMovilDatabase._init();

  static Database? _database;

  static const int version = 1;

  AvaMovilDatabase._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database =
        await _initDB('avamovil.db');

    return _database!;
  }


  Future<Database> _initDB(
    String filePath,
  ) async {
    final dbPath =
        await getDatabasesPath();

    final path =
        join(
      dbPath,
      filePath,
    );

    return openDatabase(
      path,

      version: version,

      onConfigure: (db) async {
        await db.execute(
          'PRAGMA foreign_keys = ON;',
        );
      },

      onCreate: _onCreateDB,

      onUpgrade: _onUpgradeDB,
    );
  }


  Future<void> _onCreateDB(
    Database db,
    int version,
  ) async {
    final List<String>
        tableCreationStatements = [

      // Tablas base
      personasTable,
      rolesTable,
      permisosTable,
      clientesTable,
      faenasTable,
      departamentosTable,
      tipoEventosTable,
      tipoObrerosTable,

      // Personas / usuarios
      trabajadoresTable,
      administrativosTable,
      supervisoresTable,
      usersTable,

      // Estructura organizacional
      areasTable,
      proyectosTable,
      cuadrillasTable,
      obrerosTable,

      // Asignaciones
      asignacionesTable,

      // IMPORTANTE:
      // actividades debe crearse
      // después de asignaciones.
      actividadesTable,

      // Roles y relaciones
      rolPermisoTable,
      usuarioRolTable,
      trabajadorDepartamentoTable,

      // Eventos
      eventosTable,
      eventoTrabajadorTable,
      evidenciasTable,

      // Solo móvil
      sincronizacionTable,
    ];

    for (
      final statement
      in tableCreationStatements
    ) {
      await db.execute(statement);
    }

    await _crearIndices(db);
  }


  Future<void> _crearIndices(
    Database db,
  ) async {
    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_actividades_asignacion
      ON actividades(id_asignacion);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_areas_faena
      ON areas(id_faena);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_proyectos_cliente
      ON proyectos(id_cliente);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_proyectos_faena
      ON proyectos(id_faena);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_cuadrillas_supervisor
      ON cuadrillas(id_supervisor);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_obreros_cuadrilla
      ON obreros(id_cuadrilla);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_asignaciones_proyecto
      ON asignaciones(id_proyecto);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_asignaciones_cuadrilla
      ON asignaciones(id_cuadrilla);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_eventos_proyecto
      ON eventos(id_proyecto);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_eventos_estado
      ON eventos(estado);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_evidencias_evento
      ON evidencias(id_evento);
    ''');
  }


  Future<void> _onUpgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Lo usaremos cuando cambiemos
    // la versión de SQLite.
  }


  Future<void> deleteDB() async {
    final dbPath =
        await getDatabasesPath();

    final path =
        join(
      dbPath,
      'avamovil.db',
    );

    await deleteDatabase(path);

    _database = null;
  }


  Future<void> close() async {
    final db = await database;

    await db.close();

    _database = null;
  }
}