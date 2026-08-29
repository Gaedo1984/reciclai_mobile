import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/material.dart';

void main() {
  test('Material.fromJson mapea los campos del backend', () {
    final material = Material.fromJson({'codigo': 'plastico', 'nombre': 'Plástico'});

    expect(material.codigo, 'plastico');
    expect(material.nombre, 'Plástico');
  });
}
