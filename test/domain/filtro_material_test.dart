import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/domain/filtro_material.dart';

RecyclingPoint _punto({required String id, required List<String> materiales}) {
  return RecyclingPoint(
    id: id,
    nombre: 'Punto $id',
    direccion: 'Direccion $id',
    ubicacion: const LatLng(-33.50, -70.60),
    tipo: 'punto_limpio',
    materiales: materiales,
    horario: null,
    esEmpresa: false,
    sitioWeb: null,
    confianza: 'media',
  );
}

void main() {
  test('sin materiales seleccionados devuelve todos los puntos sin cambios', () {
    final puntos = [
      _punto(id: '1', materiales: ['plastico']),
      _punto(id: '2', materiales: ['vidrio']),
    ];

    final resultado = filtrarPorMateriales(puntos, const {});

    expect(resultado, puntos);
  });

  test('con un material seleccionado deja solo los puntos que lo aceptan', () {
    final puntoConPlastico = _punto(id: '1', materiales: ['plastico']);
    final puntoConVidrio = _punto(id: '2', materiales: ['vidrio']);

    final resultado = filtrarPorMateriales([puntoConPlastico, puntoConVidrio], {'plastico'});

    expect(resultado, [puntoConPlastico]);
  });

  test('con varios materiales seleccionados deja puntos que acepten cualquiera de ellos', () {
    final puntoConPlastico = _punto(id: '1', materiales: ['plastico']);
    final puntoConVidrio = _punto(id: '2', materiales: ['vidrio']);
    final puntoConAceite = _punto(id: '3', materiales: ['aceite_usado']);

    final resultado = filtrarPorMateriales(
      [puntoConPlastico, puntoConVidrio, puntoConAceite],
      {'plastico', 'vidrio'},
    );

    expect(resultado, [puntoConPlastico, puntoConVidrio]);
  });

  test('un punto con varios materiales coincide si acepta al menos uno de los elegidos', () {
    final punto = _punto(id: '1', materiales: ['plastico', 'vidrio', 'aceite_usado']);

    final resultado = filtrarPorMateriales([punto], {'vidrio'});

    expect(resultado, [punto]);
  });

  test('si ningun punto acepta los materiales elegidos devuelve lista vacia', () {
    final puntos = [_punto(id: '1', materiales: ['plastico'])];

    final resultado = filtrarPorMateriales(puntos, {'aceite_usado'});

    expect(resultado, isEmpty);
  });
}
