class Notificacion {
  const Notificacion({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.creadaEn,
  });

  final String id;
  final String titulo;
  final String texto;
  final DateTime creadaEn;

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      texto: json['texto'] as String,
      creadaEn: DateTime.parse(json['creada_en'] as String),
    );
  }
}
