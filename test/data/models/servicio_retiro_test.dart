import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/servicio_retiro.dart';

void main() {
  Map<String, dynamic> jsonDePrueba() => {
        'comuna_id': '13129',
        'comuna_nombre': 'San Joaquín',
        'operador': 'Municipalidad',
        'horario': '08:00 a 14:00',
        'materiales': ['vidrio', 'papel'],
        'fuente_nombre': 'Municipalidad de San Joaquín',
        'fuente_url': 'https://example.cl',
        'actualizado': '2026-11-16',
        'zona_actual_id': null,
        'zonas': [
          {
            'id': 'z1',
            'nombre': 'Zona 1',
            'dias': ['lunes', 'jueves'],
            'calles': [
              {'nombre': 'Av. Uno', 'referencia': 'entre A y B'},
            ],
            'geometria': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [-70.60, -33.50],
                  [-70.61, -33.50],
                  [-70.61, -33.51],
                  [-70.60, -33.50],
                ],
              ],
            },
          },
          {
            'id': 'z2',
            'nombre': 'Zona 2',
            'dias': ['martes'],
            'calles': <Map<String, dynamic>>[],
            'geometria': {
              'type': 'MultiPolygon',
              'coordinates': [
                [
                  [
                    [-70.60, -33.50],
                    [-70.61, -33.50],
                    [-70.61, -33.51],
                    [-70.60, -33.50],
                  ],
                  // hueco: se ignora
                  [
                    [-70.605, -33.504],
                    [-70.606, -33.504],
                    [-70.606, -33.505],
                    [-70.605, -33.504],
                  ],
                ],
                [
                  [
                    [-70.70, -33.60],
                    [-70.71, -33.60],
                    [-70.71, -33.61],
                    [-70.70, -33.60],
                  ],
                ],
              ],
            },
          },
        ],
      };

  test('ServicioRetiro.fromJson parsea servicio, zonas, calles y poligonos', () {
    final servicio = ServicioRetiro.fromJson(jsonDePrueba());

    expect(servicio.comunaId, '13129');
    expect(servicio.comunaNombre, 'San Joaquín');
    expect(servicio.horario, '08:00 a 14:00');
    expect(servicio.materiales, ['vidrio', 'papel']);
    expect(servicio.fuenteNombre, 'Municipalidad de San Joaquín');
    expect(servicio.actualizado, DateTime(2026, 11, 16));
    expect(servicio.zonaActualId, isNull);
    expect(servicio.zonas, hasLength(2));
    expect(servicio.zonas[0].dias, ['lunes', 'jueves']);
    expect(servicio.zonas[0].calles.single.nombre, 'Av. Uno');
    expect(servicio.zonas[0].calles.single.referencia, 'entre A y B');
    // Polygon tambien se acepta: un unico poligono.
    expect(servicio.zonas[0].poligonos, hasLength(1));
    // MultiPolygon con 2 partes; el hueco de la primera se ignora.
    expect(servicio.zonas[1].poligonos, hasLength(2));
    expect(servicio.zonas[1].poligonos[0], hasLength(4));
    // GeoJSON viene [lng, lat].
    expect(servicio.zonas[1].poligonos[0][0], const LatLng(-33.50, -70.60));
  });

  test('ServicioRetiro.fromJson conserva zona_actual_id cuando viene', () {
    final json = jsonDePrueba()..['zona_actual_id'] = 'z2';

    expect(ServicioRetiro.fromJson(json).zonaActualId, 'z2');
  });
}
