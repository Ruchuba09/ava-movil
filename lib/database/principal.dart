const String usuarioTable = '''CREATE TABLE usuario (
  id INTEGER NOT NULL,
  nombre_1 TEXT,
  apellido_1 TEXT,
  cargo TEXT NOT NULL,
  email TEXT,
  password TEXT NOT NULL,
  rut TEXT NOT NULL,
  fecha_nacimiento TEXT NOT NULL,
  primera_conexion TEXT,

  id_especialidad INTEGER,
  rol TEXT NOT NULL,

  roles TEXT DEFAULT '[]',

  foto_primera_conexion TEXT
);''';

const String proyectoTable = '''CREATE TABLE proyecto (
  id INTEGER PRIMARY KEY, 
  Nombre TEXT NOT NULL,
  centroCosto TEXT,
  Alias TEXT NOT NULL,
  seleccionado INTEGER NOT NULL DEFAULT 0
);''';

const String especialidadTable = '''CREATE TABLE especialidad (
  id INTEGER PRIMARY KEY, 
  nombre TEXT NOT NULL,
  seleccionado INTEGER NOT NULL DEFAULT 0
);''';
