import 'package:latlong2/latlong.dart';

class Comuna {
  const Comuna({required this.id, required this.nombre, required this.region, required this.centro});

  final String id;
  final String nombre;
  final String region;
  final LatLng centro;

  factory Comuna.fromJson(Map<String, dynamic> json) {
    final centroJson = json['centro'] as Map<String, dynamic>;
    return Comuna(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      region: json['region'] as String,
      centro: LatLng(
        (centroJson['lat'] as num).toDouble(),
        (centroJson['lng'] as num).toDouble(),
      ),
    );
  }
}
