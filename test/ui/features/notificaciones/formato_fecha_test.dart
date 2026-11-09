import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/formato_fecha.dart';

void main() {
  test('formatea dia y mes abreviado en espanol, ej. "12 oct."', () {
    expect(formatearFechaCorta(DateTime(2026, 10, 12)), '12 oct.');
  });

  test('cubre los 12 meses', () {
    expect(formatearFechaCorta(DateTime(2026, 1, 1)), '1 ene.');
    expect(formatearFechaCorta(DateTime(2026, 2, 1)), '1 feb.');
    expect(formatearFechaCorta(DateTime(2026, 3, 1)), '1 mar.');
    expect(formatearFechaCorta(DateTime(2026, 4, 1)), '1 abr.');
    expect(formatearFechaCorta(DateTime(2026, 5, 1)), '1 may.');
    expect(formatearFechaCorta(DateTime(2026, 6, 1)), '1 jun.');
    expect(formatearFechaCorta(DateTime(2026, 7, 1)), '1 jul.');
    expect(formatearFechaCorta(DateTime(2026, 8, 1)), '1 ago.');
    expect(formatearFechaCorta(DateTime(2026, 9, 1)), '1 sep.');
    expect(formatearFechaCorta(DateTime(2026, 11, 1)), '1 nov.');
    expect(formatearFechaCorta(DateTime(2026, 12, 1)), '1 dic.');
  });
}
