import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/chile_bounds.dart';

void main() {
  test('Santiago (dentro de la zona piloto) esta en Chile', () {
    expect(estaEnChile(-33.45, -70.65), isTrue);
  });

  test('Arica (extremo norte) esta en Chile', () {
    expect(estaEnChile(-18.48, -70.30), isTrue);
  });

  test('Punta Arenas (extremo sur) esta en Chile', () {
    expect(estaEnChile(-53.16, -70.91), isTrue);
  });

  test('Buenos Aires (Argentina, al este) no esta en Chile', () {
    expect(estaEnChile(-34.60, -58.38), isFalse);
  });

  test('Lima (Peru, al norte) no esta en Chile', () {
    expect(estaEnChile(-12.05, -77.04), isFalse);
  });

  test('Nueva York (muy lejos) no esta en Chile', () {
    expect(estaEnChile(40.71, -74.01), isFalse);
  });
}
