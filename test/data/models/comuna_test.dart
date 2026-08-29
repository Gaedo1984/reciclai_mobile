import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';

void main() {
  test('Comuna.fromJson mapea los campos del backend', () {
    final comuna = Comuna.fromJson({
      'id': 'la-florida',
      'nombre': 'La Florida',
      'region': 'Metropolitana',
    });

    expect(comuna.id, 'la-florida');
    expect(comuna.nombre, 'La Florida');
    expect(comuna.region, 'Metropolitana');
  });
}
