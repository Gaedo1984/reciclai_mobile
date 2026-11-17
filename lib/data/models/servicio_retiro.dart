import 'dart:math';

import 'package:latlong2/latlong.dart';

class CalleZona {
  const CalleZona({
    required this.nombre,
    required this.referencia,
    this.tramo = const [],
  });

  final String nombre;
  final String referencia;

  /// Trazado de la calle dentro de la zona; vacio si no se encontro en OSM.
  final List<LatLng> tramo;

  /// Punto a la mitad del largo del tramo, donde va el numero de la calle en
  /// el mapa; null si la calle no tiene tramo. Mide en grados lat/lng: a la
  /// escala de una calle la deformacion no se nota.
  LatLng? get punto {
    if (tramo.isEmpty) return null;
    final largos = [
      for (var i = 1; i < tramo.length; i++) _distancia(tramo[i - 1], tramo[i]),
    ];
    var restante = largos.fold(0.0, (suma, largo) => suma + largo) / 2;
    for (var i = 0; i < largos.length; i++) {
      final largo = largos[i];
      if (restante <= largo && largo > 0) {
        final t = restante / largo;
        final a = tramo[i];
        final b = tramo[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      restante -= largo;
    }
    // Tramo de un solo punto o de largo cero.
    return tramo.first;
  }

  static double _distancia(LatLng a, LatLng b) {
    final dLat = b.latitude - a.latitude;
    final dLng = b.longitude - a.longitude;
    return sqrt(dLat * dLat + dLng * dLng);
  }

  factory CalleZona.fromJson(Map<String, dynamic> json) {
    // `tramo` llego despues que el resto: si falta, la calle va sin tramo.
    final tramo = json['tramo'] as List<dynamic>? ?? const [];
    return CalleZona(
      nombre: json['nombre'] as String,
      referencia: json['referencia'] as String,
      tramo: tramo.map(_latLngDeGeoJson).toList(),
    );
  }
}

/// GeoJSON viene [lng, lat].
LatLng _latLngDeGeoJson(dynamic punto) {
  final par = punto as List<dynamic>;
  return LatLng((par[1] as num).toDouble(), (par[0] as num).toDouble());
}

class ZonaRetiro {
  const ZonaRetiro({
    required this.id,
    required this.nombre,
    required this.dias,
    required this.calles,
    required this.poligonos,
    this.horario,
  });

  final String id;
  final String nombre;
  final List<String> dias;
  final List<CalleZona> calles;

  /// Anillo exterior de cada poligono de la geometria; se ignoran los huecos.
  final List<List<LatLng>> poligonos;

  /// Horario propio de la zona; null si vale el del servicio.
  final String? horario;

  factory ZonaRetiro.fromJson(Map<String, dynamic> json) {
    return ZonaRetiro(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      dias: (json['dias'] as List<dynamic>).map((e) => e as String).toList(),
      calles: (json['calles'] as List<dynamic>)
          .map((e) => CalleZona.fromJson(e as Map<String, dynamic>))
          .toList(),
      poligonos: _poligonosDeGeometria(json['geometria'] as Map<String, dynamic>),
      horario: json['horario'] as String?,
    );
  }

  // El backend siempre guarda MultiPolygon, pero un Polygon suelto tambien vale.
  static List<List<LatLng>> _poligonosDeGeometria(Map<String, dynamic> geometria) {
    final coordenadas = geometria['coordinates'] as List<dynamic>;
    final poligonos = geometria['type'] == 'Polygon' ? [coordenadas] : coordenadas;
    return poligonos.map((poligono) {
      final anilloExterior = (poligono as List<dynamic>).first as List<dynamic>;
      return anilloExterior.map(_latLngDeGeoJson).toList();
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
