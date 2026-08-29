class Material {
  const Material({required this.codigo, required this.nombre});

  final String codigo;
  final String nombre;

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }
}
