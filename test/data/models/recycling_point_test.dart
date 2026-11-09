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

  test('RecyclingPoint.fromJson lee el telefono, y es null si el backend no lo manda', () {
    Map<String, dynamic> json({Object? telefono, bool incluir = true}) => {
      'id': 'abc-123',
      'nombre': 'Reciclajes Huaquén',
      'direccion': 'Ruta E-251, La Ligua',
      'ubicacion': {'lat': -32.35, 'lng': -71.41},
      'tipo': 'empresa_reciclaje',
      'materiales': <String>[],
      'horario': null,
      'es_empresa': true,
      'sitio_web': null,
      'confianza': 'alta',
      if (incluir) 'telefono': telefono,
    };

    expect(
      RecyclingPoint.fromJson(json(telefono: '+56 9 6527 9301')).telefono,
      '+56 9 6527 9301',
    );
    expect(RecyclingPoint.fromJson(json(telefono: null)).telefono, isNull);
    // Backend anterior al campo: la respuesta no trae la clave.
    expect(RecyclingPoint.fromJson(json(incluir: false)).telefono, isNull);
  });
}
