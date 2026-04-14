class Proyecto {
  final int id;
  final String nombre;
  final String? centroCosto;
  final String alias;
  final int seleccionado;

  Proyecto({
    required this.id,
    required this.nombre,
    this.centroCosto,
    required this.alias,
    this.seleccionado = 0,
  });

  Map<String, dynamic> _toMap() {
    return {
      'id': id,
      'Nombre': nombre,
      'centroCosto': centroCosto,
      'Alias': alias,
      'seleccionado': seleccionado,
    };
  }

  Map<String, dynamic> toMap() => _toMap();

  Map<String, dynamic> toJson() => _toMap();

  factory Proyecto._from(Map<String, dynamic> map) {
    return Proyecto(
      id: map['id'],
      nombre: map['Nombre'],
      centroCosto: map['centroCosto'],
      alias: map['Alias'],
      seleccionado: map['seleccionado'] ?? 0,
    );
  }

  factory Proyecto.fromMap(Map<String, dynamic> map) => Proyecto._from(map);

  factory Proyecto.fromJson(Map<String, dynamic> json) => Proyecto._from(json);
}
