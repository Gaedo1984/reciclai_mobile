import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/splash/splash_readiness.dart';

void main() {
  test('no avisa si solo el video termino', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarVideoTerminado();

    expect(avisos, 0);
  });

  test('no avisa si solo los datos estan listos', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarDatosListos();

    expect(avisos, 0);
  });

  test('avisa cuando el video termina despues de que los datos ya estaban listos', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarDatosListos();
    readiness.marcarVideoTerminado();

    expect(avisos, 1);
  });

  test('avisa cuando los datos quedan listos despues de que el video ya termino', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarVideoTerminado();
    readiness.marcarDatosListos();

    expect(avisos, 1);
  });

  test('avisa una sola vez aunque las señales lleguen varias veces', () {
    var avisos = 0;
    final readiness = SplashReadiness(onListo: () => avisos++);

    readiness.marcarVideoTerminado();
    readiness.marcarDatosListos();
    readiness.marcarDatosListos();
    readiness.marcarVideoTerminado();

    expect(avisos, 1);
  });
}
