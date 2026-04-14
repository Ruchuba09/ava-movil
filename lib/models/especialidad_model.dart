class Especialidad {
  final int id;
  final String nombre;
  final int seleccionado;

  Especialidad({
    required this.id,
    required this.nombre,
    this.seleccionado = 0,
  });

  Map<String, dynamic> _toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'seleccionado': seleccionado,
    };
  }

  Map<String, dynamic> toMap() => _toMap();

  Map<String, dynamic> toJson() => _toMap();

  factory Especialidad._from(Map<String, dynamic> map) {
    return Especialidad(
      id: map['id'],
      nombre: map['nombre'],
      seleccionado: map['seleccionado'] ?? 0,
    );
  }

  factory Especialidad.fromMap(Map<String, dynamic> map) =>
      Especialidad._from(map);

  factory Especialidad.fromJson(Map<String, dynamic> json) =>
      Especialidad._from(json);
}
