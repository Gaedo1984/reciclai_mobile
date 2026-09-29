import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/splash/splash_readiness.dart';

void main() {
  test('no avisa si solo se cumplio el tiempo minimo', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarTiempoMinimoCumplido();

    expect(avisos, 0);
  });

  test('no avisa si solo los datos estan listos', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarDatosListos();

    expect(avisos, 0);
  });

  test('avisa cuando el tiempo minimo se cumple despues de que los datos ya estaban listos', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarDatosListos();
    readiness.marcarTiempoMinimoCumplido();

    expect(avisos, 1);
  });

  test('avisa cuando los datos quedan listos despues de que el tiempo minimo ya se cumplio', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarTiempoMinimoCumplido();
    readiness.marcarDatosListos();

    expect(avisos, 1);
  });

  test('avisa una sola vez aunque las señales lleguen varias veces', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarTiempoMinimoCumplido();
    readiness.marcarDatosListos();
    readiness.marcarDatosListos();
    readiness.marcarTiempoMinimoCumplido();

    expect(avisos, 1);
  });
}
