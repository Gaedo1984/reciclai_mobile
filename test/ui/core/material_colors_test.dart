import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/core/material_colors.dart';

void main() {
  test('devuelve un color distinto para cada categoria conocida', () {
    final colores = {
      colorParaMaterial('plastico'),
      colorParaMaterial('vidrio'),
      colorParaMaterial('papel_carton'),
      colorParaMaterial('aluminio'),
      colorParaMaterial('pilas'),
    };

    expect(colores, hasLength(5));
  });

  test('reconoce variantes con sufijo del mismo material base', () {
    expect(colorParaMaterial('papel_carton_grande'), colorParaMaterial('papel_carton'));
  });

  test('devuelve un color de respaldo neutro para un codigo desconocido', () {
    expect(colorParaMaterial('material_totalmente_nuevo'), Colors.blueGrey);
  });
}
