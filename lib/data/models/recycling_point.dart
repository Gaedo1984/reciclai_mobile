import 'package:latlong2/latlong.dart';

class RecyclingPoint {
  const RecyclingPoint({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.ubicacion,
    required this.tipo,
    required this.materiales,
    required this.horario,
    required this.esEmpresa,
    required this.sitioWeb,
    required this.confianza,
  });

  final String id;
  final String nombre;
  final String direccion;
  final LatLng ubicacion;
  final String tipo;
  final List<String> materiales;
  final String? horario;
  final bool esEmpresa;
  final String? sitioWeb;
  final String confianza;

  factory RecyclingPoint.fromJson(Map<String, dynamic> json) {
    final ubicacionJson = json['ubicacion'] as Map<String, dynamic>;
    return RecyclingPoint(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String,
      ubicacion: LatLng(
        (ubicacionJson['lat'] as num).toDouble(),
        (ubicacionJson['lng'] as num).toDouble(),
      ),
      tipo: json['tipo'] as String,
      materiales: (json['materiales'] as List<dynamic>).cast<String>(),
      horario: json['horario'] as String?,
      esEmpresa: json['es_empresa'] as bool,
      sitioWeb: json['sitio_web'] as String?,
      confianza: json['confianza'] as String,
    );
  }
}
