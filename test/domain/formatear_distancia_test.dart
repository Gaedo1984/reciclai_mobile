import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/formatear_distancia.dart';

void main() {
  test('bajo 1 km, redondea a metros enteros', () {
    expect(formatearDistancia(450), '450 m');
    expect(formatearDistancia(999), '999 m');
  });

  test('desde 1 km, muestra kilometros con un decimal', () {
    expect(formatearDistancia(1000), '1.0 km');
    expect(formatearDistancia(2345), '2.3 km');
    expect(formatearDistancia(15800), '15.8 km');
  });
}
