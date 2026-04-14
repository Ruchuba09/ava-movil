import 'dart:convert';

import 'package:avamovil/database/avamovil_db.dart';
import 'package:avamovil/models/abstract.dart';

class User implements Identifiable {
  @override
  final int id;
  final String? nombre1;
  final String? apellido1;
  final String cargo;
  final String? email;
  final String password;
  final String rut;
  final DateTime? fechaNacimiento;
  final DateTime? primeraConexion;

  final int? idEspecialidad;
  final String rol;
  final List<String>? roles;

  final String? fotoPrimeraConexion;

  String especialidadValue = "";

  User({
    required this.id,
    this.nombre1,
    this.apellido1,
    required this.cargo,
    this.email,
    required this.password,
    required this.rut,
    this.fechaNacimiento,
    this.primeraConexion,
    this.idEspecialidad,
    required this.rol,
    this.roles,
    this.fotoPrimeraConexion,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_1': nombre1,
      'apellido_1': apellido1,
      'cargo': cargo,
      'email': email,
      'password': password,
      'rut': rut,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T').first,
      'primera_conexion': primeraConexion?.toIso8601String(),
      'id_especialidad': idEspecialidad,
      'rol': rol,
      'roles': roles,
      'foto_primera_conexion': fotoPrimeraConexion,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre_1': nombre1,
      'apellido_1': apellido1,
      'cargo': cargo,
      'email': email,
      'password': password,
      'rut': rut,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
      'primera_conexion': primeraConexion?.toIso8601String(),
      'id_especialidad': idEspecialidad,
      'rol': rol,
      'roles': jsonEncode(roles),
      'foto_primera_conexion': fotoPrimeraConexion,
    };
  }

  factory User.fromMap(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nombre1: json['nombre_1'] as String?,
      apellido1: json['apellido_1'] as String?,
      cargo: json['cargo'] as String,
      email: json['email'] as String?,
      password: json['password'] as String,
      rut: json['rut'] as String,
      fechaNacimiento: json['fecha_nacimiento'] != null
          ? DateTime.parse(json['fecha_nacimiento'] as String)
          : null,
      primeraConexion: json['primera_conexion'] != null
          ? DateTime.parse(json['primera_conexion'] as String)
          : null,
      idEspecialidad: json['id_especialidad'] as int?,
      rol: json['rol'] as String,
      roles: json['roles'] != null
          ? List<String>.from(jsonDecode(json['roles']))
          : [json['rol'] as String], // fallback
      fotoPrimeraConexion: json['foto_primera_conexion'] as String?,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nombre1: json['nombre_1'] as String?,
      apellido1: json['apellido_1'] as String?,
      cargo: json['cargo'] as String,
      email: json['email'] as String?,
      password: json['password'] as String,
      rut: json['rut'] as String,
      fechaNacimiento: json['fecha_nacimiento'] != null
          ? DateTime.parse(json['fecha_nacimiento'] as String)
          : null,
      primeraConexion: json['primera_conexion'] != null
          ? DateTime.parse(json['primera_conexion'] as String)
          : null,
      idEspecialidad: json['id_especialidad'] as int?,
      rol: json['rol'] as String,
      roles: json['roles'] != null
          ? List<String>.from(json['roles'])
          : [json['rol'] as String],
      fotoPrimeraConexion: json['foto_primera_conexion'] as String?,
    );
  }

  Future<String> especialidad() async {
    if (idEspecialidad == null) {
      return "Sin especialidad";
    }
    final db = await AvaMovilDatabase.instance.database;
    final result = await db.query(
      'especialidad',
      columns: ['nombre'],
      where: 'id = ?',
      whereArgs: [idEspecialidad],
    );

    if (result.isNotEmpty) {
      return result.first['nombre'] as String;
    } else {
      return "";
    }
  }
}
