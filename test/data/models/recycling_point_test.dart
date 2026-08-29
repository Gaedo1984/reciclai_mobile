import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';

void main() {
  test('RecyclingPoint.fromJson mapea todos los campos del backend', () {
    final punto = RecyclingPoint.fromJson({
      'id': 'abc-123',
      'nombre': 'Punto Limpio Municipal',
      'direccion': 'Av. Vicuña Mackenna 7000',
      'ubicacion': {'lat': -33.52, 'lng': -70.60},
      'tipo': 'punto_limpio',
      'materiales': ['plastico', 'vidrio'],
      'horario': 'Lun-Vie 9:00-18:00',
      'es_empresa': false,
      'sitio_web': 'https://example.cl',
      'confianza': 'media',
    });

    expect(punto.id, 'abc-123');
    expect(punto.nombre, 'Punto Limpio Municipal');
    expect(punto.direccion, 'Av. Vicuña Mackenna 7000');
    expect(punto.ubicacion.latitude, -33.52);
    expect(punto.ubicacion.longitude, -70.60);
    expect(punto.tipo, 'punto_limpio');
    expect(punto.materiales, ['plastico', 'vidrio']);
    expect(punto.horario, 'Lun-Vie 9:00-18:00');
    expect(punto.esEmpresa, false);
    expect(punto.sitioWeb, 'https://example.cl');
    expect(punto.confianza, 'media');
  });

  test('RecyclingPoint.fromJson soporta horario y sitio_web nulos', () {
    final punto = RecyclingPoint.fromJson({
      'id': 'abc-123',
      'nombre': 'Punto Limpio Municipal',
      'direccion': 'Av. Vicuña Mackenna 7000',
      'ubicacion': {'lat': -33.52, 'lng': -70.60},
      'tipo': 'punto_limpio',
      'materiales': <String>[],
      'horario': null,
      'es_empresa': false,
      'sitio_web': null,
      'confianza': 'media',
    });

    expect(punto.horario, isNull);
    expect(punto.sitioWeb, isNull);
  });
}
