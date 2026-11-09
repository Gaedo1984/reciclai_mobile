import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/como_reciclar/material_reciclable.dart';
import 'package:reciclai_mobile/ui/features/materiales_especiales/material_especial.dart';

void main() {
  test('todo material tiene codigos de filtro, salvo los que no tienen donde reciclarse en Chile', () {
    for (final material in [
      ...materialesReciclables,
      ...materialesEspeciales,
    ]) {
      if (material.codigo == 'filtros_jarro_agua') {
        expect(material.codigosFiltro, isEmpty, reason: material.codigo);
      } else {
        expect(material.codigosFiltro, isNotEmpty, reason: material.codigo);
      }
    }
  });
}
