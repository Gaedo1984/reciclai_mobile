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

  test('ServicioRetiro.fromJson parsea el tramo de cada calle y el horario de la zona', () {
    final json = jsonDePrueba();
    final zonas = json['zonas'] as List<dynamic>;
    // Copias con valores dynamic: los literales de jsonDePrueba infieren
    // tipos mas estrechos y no aceptan campos de otro tipo.
    final zona1 = Map<String, dynamic>.from(zonas[0] as Map);
    final calle = Map<String, dynamic>.from((zona1['calles'] as List<dynamic>)[0] as Map);
    calle['tramo'] = [
      [-70.60, -33.50],
      [-70.61, -33.51],
    ];
    zona1['calles'] = [calle];
    zona1['horario'] = 'El camión pasa entre 8:30 y 12:30 (aprox.)';
    json['zonas'] = [zona1, zonas[1]];

    final servicio = ServicioRetiro.fromJson(json);

    expect(servicio.zonas[0].horario, 'El camión pasa entre 8:30 y 12:30 (aprox.)');
    // GeoJSON viene [lng, lat].
    expect(servicio.zonas[0].calles.single.tramo, const [
      LatLng(-33.50, -70.60),
      LatLng(-33.51, -70.61),
    ]);
  });

  test('ServicioRetiro.fromJson tolera tramo y horario ausentes o nulos', () {
    final json = jsonDePrueba();
    final zonas = json['zonas'] as List<dynamic>;
    json['zonas'] = [zonas[0], Map<String, dynamic>.from(zonas[1] as Map)..['horario'] = null];

    final servicio = ServicioRetiro.fromJson(json);

    // La zona 1 no trae horario y su calle no trae tramo (version anterior del API).
    expect(servicio.zonas[0].horario, isNull);
    expect(servicio.zonas[0].calles.single.tramo, isEmpty);
    expect(servicio.zonas[0].calles.single.punto, isNull);
    expect(servicio.zonas[1].horario, isNull);
  });

  test('CalleZona.punto queda a la mitad del largo del tramo', () {
    const calle = CalleZona(
      nombre: 'Av. Uno',
      referencia: 'entre A y B',
      tramo: [LatLng(0, 0), LatLng(2, 0), LatLng(4, 0)],
    );

    expect(calle.punto, const LatLng(2, 0));
  });

  test('CalleZona.punto usa el largo acumulado, no el indice del medio', () {
    // El primer segmento mide 1 y el segundo 3: la mitad (2) cae a 1 del
    // inicio del segundo segmento.
    const calle = CalleZona(
      nombre: 'Av. Uno',
      referencia: 'entre A y B',
      tramo: [LatLng(0, 0), LatLng(0, 1), LatLng(0, 4)],
    );

    final punto = calle.punto!;
    expect(punto.latitude, moreOrLessEquals(0));
    expect(punto.longitude, moreOrLessEquals(2));
  });

  test('CalleZona.punto es null si el tramo esta vacio', () {
    const calle = CalleZona(nombre: 'Av. Uno', referencia: 'entre A y B');

    expect(calle.tramo, isEmpty);
    expect(calle.punto, isNull);
  });
}
