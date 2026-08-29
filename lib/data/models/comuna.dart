class Comuna {
  const Comuna({required this.id, required this.nombre, required this.region});

  final String id;
  final String nombre;
  final String region;

  factory Comuna.fromJson(Map<String, dynamic> json) {
    return Comuna(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      region: json['region'] as String,
    );
  }
}
