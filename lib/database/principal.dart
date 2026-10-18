// ============================================================
// PERSONAS
// ============================================================

const String personasTable = '''
CREATE TABLE personas (
  id_persona INTEGER PRIMARY KEY,
  rut TEXT NOT NULL UNIQUE,
  nombre_1 TEXT NOT NULL,
  nombre_2 TEXT,
  apellido_1 TEXT NOT NULL,
  apellido_2 TEXT
);
''';


// ============================================================
// ROLES
// ============================================================

const String rolesTable = '''
CREATE TABLE roles (
  id_rol INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  estado TEXT NOT NULL DEFAULT 'activo'
);
''';


// ============================================================
// PERMISOS
// ============================================================

const String permisosTable = '''
CREATE TABLE permisos (
  id_permiso INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  descripcion TEXT
);
''';


// ============================================================
// CLIENTES
// ============================================================

const String clientesTable = '''
CREATE TABLE clientes (
  id_cliente INTEGER PRIMARY KEY,
  rut TEXT NOT NULL UNIQUE,
  razon_social TEXT NOT NULL,
  nombre TEXT,
  email TEXT,
  telefono TEXT,
  direccion TEXT,
  estado TEXT NOT NULL DEFAULT 'activo'
);
''';


// ============================================================
// FAENAS
// ============================================================

const String faenasTable = '''
CREATE TABLE faenas (
  id_faena INTEGER PRIMARY KEY,
  codigo_faena TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL
);
''';


// ============================================================
// DEPARTAMENTOS
// ============================================================

const String departamentosTable = '''
CREATE TABLE departamentos (
  id_departamento INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  estado TEXT NOT NULL DEFAULT 'activo'
);
''';


// ============================================================
// TIPOS DE EVENTO
// ============================================================

const String tipoEventosTable = '''
CREATE TABLE tipo_eventos (
  id_tipo_evento INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE
);
''';


// ============================================================
// TIPOS DE OBRERO
// ============================================================

const String tipoObrerosTable = '''
CREATE TABLE tipo_obreros (
  id_tipo_obrero INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  estado TEXT NOT NULL DEFAULT 'activo'
);
''';


// ============================================================
// TRABAJADORES
// ============================================================

const String trabajadoresTable = '''
CREATE TABLE trabajadores (
  id_trabajador INTEGER PRIMARY KEY,
  id_persona INTEGER NOT NULL UNIQUE,
  cargo TEXT,
  estado TEXT NOT NULL DEFAULT 'activo',
  fecha_creacion TEXT,
  ultima_actualizacion TEXT,

  FOREIGN KEY (id_persona)
    REFERENCES personas(id_persona)
    ON DELETE CASCADE
);
''';


// ============================================================
// ADMINISTRATIVOS
// ============================================================

const String administrativosTable = '''
CREATE TABLE administrativos (
  id_trabajador INTEGER PRIMARY KEY,

  FOREIGN KEY (id_trabajador)
    REFERENCES trabajadores(id_trabajador)
    ON DELETE CASCADE
);
''';


// ============================================================
// SUPERVISORES
// ============================================================

const String supervisoresTable = '''
CREATE TABLE supervisores (
  id_trabajador INTEGER PRIMARY KEY,

  FOREIGN KEY (id_trabajador)
    REFERENCES trabajadores(id_trabajador)
    ON DELETE CASCADE
);
''';


// ============================================================
// USERS
// ============================================================
//
// IMPORTANTE:
// No guardaremos password en SQLite.
// La autenticación real debe hacerse en Laravel.
//

const String usersTable = '''
CREATE TABLE users (
  id_user INTEGER PRIMARY KEY,
  id_trabajador INTEGER NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  email_verified_at TEXT,
  fecha_creacion TEXT,
  created_at TEXT,
  updated_at TEXT,

  FOREIGN KEY (id_trabajador)
    REFERENCES trabajadores(id_trabajador)
    ON DELETE CASCADE
);
''';


// ============================================================
// AREAS
// ============================================================

const String areasTable = '''
CREATE TABLE areas (
  id_area INTEGER PRIMARY KEY,
  id_faena INTEGER NOT NULL,
  codigo_area TEXT NOT NULL,
  descripcion TEXT,

  UNIQUE(id_faena, codigo_area),

  FOREIGN KEY (id_faena)
    REFERENCES faenas(id_faena)
    ON DELETE CASCADE
);
''';


// ============================================================
// PROYECTOS
// ============================================================

const String proyectosTable = '''
CREATE TABLE proyectos (
  id_proyecto INTEGER PRIMARY KEY,
  id_faena INTEGER NOT NULL,
  id_cliente INTEGER NOT NULL,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  ubicacion TEXT,
  fecha_inicio TEXT,
  fecha_termino TEXT,
  estado TEXT NOT NULL DEFAULT 'activo',

  FOREIGN KEY (id_cliente)
    REFERENCES clientes(id_cliente)
    ON DELETE RESTRICT,

  FOREIGN KEY (id_faena)
    REFERENCES faenas(id_faena)
    ON DELETE RESTRICT
);
''';


// ============================================================
// CUADRILLAS
// ============================================================

const String cuadrillasTable = '''
CREATE TABLE cuadrillas (
  id_cuadrilla INTEGER PRIMARY KEY,
  id_supervisor INTEGER NOT NULL,
  numero_cuadrilla TEXT NOT NULL UNIQUE,

  FOREIGN KEY (id_supervisor)
    REFERENCES supervisores(id_trabajador)
    ON DELETE RESTRICT
);
''';


// ============================================================
// OBREROS
// ============================================================

const String obrerosTable = '''
CREATE TABLE obreros (
  id_trabajador INTEGER PRIMARY KEY,
  id_tipo_obrero INTEGER NOT NULL,
  id_cuadrilla INTEGER,

  FOREIGN KEY (id_trabajador)
    REFERENCES trabajadores(id_trabajador)
    ON DELETE CASCADE,

  FOREIGN KEY (id_tipo_obrero)
    REFERENCES tipo_obreros(id_tipo_obrero)
    ON DELETE RESTRICT,

  FOREIGN KEY (id_cuadrilla)
    REFERENCES cuadrillas(id_cuadrilla)
    ON DELETE SET NULL
);
''';


// ============================================================
// ASIGNACIONES
// ============================================================

const String asignacionesTable = '''
CREATE TABLE asignaciones (
  id_asignacion INTEGER PRIMARY KEY,
  id_administrador INTEGER NOT NULL,
  id_proyecto INTEGER NOT NULL,
  id_cuadrilla INTEGER NOT NULL,
  fecha_creacion TEXT,
  fecha_inicio TEXT NOT NULL,
  fecha_termino TEXT,

  FOREIGN KEY (id_administrador)
    REFERENCES administrativos(id_trabajador)
    ON DELETE RESTRICT,

  FOREIGN KEY (id_proyecto)
    REFERENCES proyectos(id_proyecto)
    ON DELETE CASCADE,

  FOREIGN KEY (id_cuadrilla)
    REFERENCES cuadrillas(id_cuadrilla)
    ON DELETE RESTRICT
);
''';


// ============================================================
// ACTIVIDADES
// ============================================================
//
// Cada actividad pertenece a una asignación.
// Por tanto, indirectamente sabemos:
// actividad → asignación → cuadrilla + proyecto
//

const String actividadesTable = '''
CREATE TABLE actividades (
  id_actividad INTEGER PRIMARY KEY,
  id_asignacion INTEGER NOT NULL,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  fecha_inicio TEXT,
  fecha_termino TEXT,
  estado TEXT NOT NULL DEFAULT 'pendiente',
  fecha_creacion TEXT,
  fecha_actualizacion TEXT,

  FOREIGN KEY (id_asignacion)
    REFERENCES asignaciones(id_asignacion)
    ON DELETE CASCADE
);
''';


// ============================================================
// ROL - PERMISO
// ============================================================

const String rolPermisoTable = '''
CREATE TABLE rol_permiso (
  id_rol INTEGER NOT NULL,
  id_permiso INTEGER NOT NULL,

  PRIMARY KEY (id_rol, id_permiso),

  FOREIGN KEY (id_rol)
    REFERENCES roles(id_rol)
    ON DELETE CASCADE,

  FOREIGN KEY (id_permiso)
    REFERENCES permisos(id_permiso)
    ON DELETE CASCADE
);
''';


// ============================================================
// USUARIO - ROL
// ============================================================

const String usuarioRolTable = '''
CREATE TABLE usuario_rol (
  id_user INTEGER NOT NULL,
  id_rol INTEGER NOT NULL,

  PRIMARY KEY (id_user, id_rol),

  FOREIGN KEY (id_user)
    REFERENCES users(id_user)
    ON DELETE CASCADE,

  FOREIGN KEY (id_rol)
    REFERENCES roles(id_rol)
    ON DELETE CASCADE
);
''';


// ============================================================
// TRABAJADOR - DEPARTAMENTO
// ============================================================

const String trabajadorDepartamentoTable = '''
CREATE TABLE trabajador_departamento (
  id_trabajador INTEGER NOT NULL,
  id_departamento INTEGER NOT NULL,

  PRIMARY KEY (
    id_trabajador,
    id_departamento
  ),

  FOREIGN KEY (id_trabajador)
    REFERENCES trabajadores(id_trabajador)
    ON DELETE CASCADE,

  FOREIGN KEY (id_departamento)
    REFERENCES departamentos(id_departamento)
    ON DELETE CASCADE
);
''';


// ============================================================
// EVENTOS
// ============================================================

const String eventosTable = '''
CREATE TABLE eventos (
  id_evento INTEGER PRIMARY KEY,

  id_tipo_evento INTEGER NOT NULL,

  id_administrador INTEGER,
  id_area INTEGER,
  id_proyecto INTEGER NOT NULL,

  fecha_creacion TEXT,
  fecha_actualizacion TEXT,

  descripcion TEXT NOT NULL,

  estado TEXT NOT NULL DEFAULT 'abierto',

  condicion REAL,

  evidencia TEXT,

  referencia TEXT,

  id_trabajador INTEGER,
  id_supervisor INTEGER,

  fecha_cierre TEXT,

  justificacion TEXT,

  evidencia_cierre TEXT,

  FOREIGN KEY (id_tipo_evento)
    REFERENCES tipo_eventos(id_tipo_evento)
    ON DELETE RESTRICT,

  FOREIGN KEY (id_administrador)
    REFERENCES administrativos(id_trabajador)
    ON DELETE RESTRICT,

  FOREIGN KEY (id_area)
    REFERENCES areas(id_area)
    ON DELETE RESTRICT,

  FOREIGN KEY (id_proyecto)
    REFERENCES proyectos(id_proyecto)
    ON DELETE CASCADE
);
''';


// ============================================================
// EVENTO - TRABAJADOR
// ============================================================

const String eventoTrabajadorTable = '''
CREATE TABLE evento_trabajador (
  id_evento INTEGER NOT NULL,
  id_trabajador INTEGER NOT NULL,

  PRIMARY KEY (
    id_evento,
    id_trabajador
  ),

  FOREIGN KEY (id_evento)
    REFERENCES eventos(id_evento)
    ON DELETE CASCADE,

  FOREIGN KEY (id_trabajador)
    REFERENCES trabajadores(id_trabajador)
    ON DELETE CASCADE
);
''';


// ============================================================
// EVIDENCIAS
// ============================================================

const String evidenciasTable = '''
CREATE TABLE evidencias (
  id_evidencia INTEGER PRIMARY KEY,

  id_evento INTEGER NOT NULL,

  nombre TEXT NOT NULL,
  ruta TEXT NOT NULL,
  tipo_archivo TEXT,
  fecha_creacion TEXT,

  FOREIGN KEY (id_evento)
    REFERENCES eventos(id_evento)
    ON DELETE CASCADE
);
''';


// ============================================================
// CONTROL DE SINCRONIZACION
// ============================================================
//
// Esta tabla NO existe en PostgreSQL.
// Es exclusiva del celular.
//

const String sincronizacionTable = '''
CREATE TABLE sincronizacion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  tabla TEXT NOT NULL,

  registro_id INTEGER,

  operacion TEXT NOT NULL,

  estado TEXT NOT NULL DEFAULT 'pendiente',

  fecha_creacion TEXT NOT NULL,

  fecha_sincronizacion TEXT,

  ultimo_error TEXT
);
''';