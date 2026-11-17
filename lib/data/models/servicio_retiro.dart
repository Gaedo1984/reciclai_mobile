import 'package:latlong2/latlong.dart';

class CalleZona {
  const CalleZona({required this.nombre, required this.referencia});

  final String nombre;
  final String referencia;

  factory CalleZona.fromJson(Map<String, dynamic> json) {
    return CalleZona(
      nombre: json['nombre'] as String,
      referencia: json['referencia'] as String,
    );
  }
}

class ZonaRetiro {
  const ZonaRetiro({
    required this.id,
    required this.nombre,
    required this.dias,
    required this.calles,
    required this.poligonos,
  });

  final String id;
  final String nombre;
  final List<String> dias;
  final List<CalleZona> calles;

  /// Anillo exterior de cada poligono de la geometria; se ignoran los huecos.
  final List<List<LatLng>> poligonos;

  factory ZonaRetiro.fromJson(Map<String, dynamic> json) {
    return ZonaRetiro(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      dias: (json['dias'] as List<dynamic>).map((e) => e as String).toList(),
      calles: (json['calles'] as List<dynamic>)
          .map((e) => CalleZona.fromJson(e as Map<String, dynamic>))
          .toList(),
      poligonos: _poligonosDeGeometria(json['geometria'] as Map<String, dynamic>),
    );
  }

  // El backend siempre guarda MultiPolygon, pero un Polygon suelto tambien vale.
  static List<List<LatLng>> _poligonosDeGeometria(Map<String, dynamic> geometria) {
    final coordenadas = geometria['coordinates'] as List<dynamic>;
    final poligonos = geometria['type'] == 'Polygon' ? [coordenadas] : coordenadas;
    return poligonos.map((poligono) {
      final anilloExterior = (poligono as List<dynamic>).first as List<dynamic>;
      // GeoJSON viene [lng, lat].
      return anilloExterior.map((punto) {
        final par = punto as List<dynamic>;
        return LatLng((par[1] as num).toDouble(), (par[0] as num).toDouble());
      }).toList();
    }).toList();
  }
}

class ServicioRetiro {
  const ServicioRetiro({
    required this.comunaId,
    required this.comunaNombre,
    required this.horario,
    required this.materiales,
    required this.fuenteNombre,
    required this.actualizado,
    required this.zonaActualId,
    required this.zonas,
  });

  final String comunaId;
  final String comunaNombre;
  final String horario;
  final List<String> materiales;
  final String fuenteNombre;
  final DateTime actualizado;
  final String? zonaActualId;
  final List<ZonaRetiro> zonas;

  factory ServicioRetiro.fromJson(Map<String, dynamic> json) {
    return ServicioRetiro(
      comunaId: json['comuna_id'] as String,
      comunaNombre: json['comuna_nombre'] as String,
      horario: json['horario'] as String,
      materiales: (json['materiales'] as List<dynamic>).map((e) => e as String).toList(),
      fuenteNombre: json['fuente_nombre'] as String,
      actualizado: DateTime.parse(json['actualizado'] as String),
      zonaActualId: json['zona_actual_id'] as String?,
      zonas: (json['zonas'] as List<dynamic>)
          .map((e) => ZonaRetiro.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
