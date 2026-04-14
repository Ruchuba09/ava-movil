import 'package:avamovil/database/principal.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AvaMovilDatabase {
  static final AvaMovilDatabase instance = AvaMovilDatabase._init();
  static Database? _database;
  final int version = 0;

  AvaMovilDatabase._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB('avamovil.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: version,
      onCreate: _onCreateDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future _onCreateDB(Database db, int version) async {
    final List<String> tableCreationStatements = [
      proyectoTable,
      especialidadTable,
      usuarioTable,
    ];

    for (final statement in tableCreationStatements) {
      await db.execute(statement);
    }
  }

  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {}

  Future<void> deleteDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'avamovil.db');
    await deleteDatabase(path);
  }
}
