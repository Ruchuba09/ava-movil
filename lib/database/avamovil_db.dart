import 'package:avamovil/database/principal.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AvaMovilDatabase {
  static final AvaMovilDatabase instance =
      AvaMovilDatabase._init();

  static Database? _database;

  static const int version = 2;
  static const String _databaseName = 'avamovil.db';

  AvaMovilDatabase._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database =
        await _initDB(_databaseName);

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

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_sincronizacion_estado_fecha
      ON sincronizacion(estado, fecha_creacion, id);
    ''');

    await db.execute('''
      CREATE INDEX
      IF NOT EXISTS
      idx_sincronizacion_registro
      ON sincronizacion(tabla, registro_id);
    ''');
  }


  Future<void> _onUpgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute('''
        ALTER TABLE sincronizacion
        ADD COLUMN payload_json TEXT;
      ''');
      await db.execute('''
        ALTER TABLE sincronizacion
        ADD COLUMN intentos INTEGER NOT NULL DEFAULT 0;
      ''');
      await db.execute('''
        ALTER TABLE sincronizacion
        ADD COLUMN fecha_actualizacion TEXT;
      ''');
      await db.execute('''
        UPDATE sincronizacion
        SET fecha_actualizacion = fecha_creacion
        WHERE fecha_actualizacion IS NULL;
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sincronizacion_estado_fecha
        ON sincronizacion(estado, fecha_creacion, id);
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sincronizacion_registro
        ON sincronizacion(tabla, registro_id);
      ''');
    }
  }


  Future<void> deleteDB() async {
    final dbPath =
        await getDatabasesPath();

    final path =
        join(
      dbPath,
      _databaseName,
    );

    final openDatabase = _database;
    if (openDatabase != null) {
      await openDatabase.close();
      _database = null;
    }

    await deleteDatabase(path);
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) {
      return;
    }
    await db.close();
    _database = null;
  }
}