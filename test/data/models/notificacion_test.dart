import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';

void main() {
  test('Notificacion.fromJson parsea los 4 campos del backend', () {
    final json = {
      'id': 'abc-123',
      'titulo': 'Nueva versión disponible',
      'texto': 'Ya podés buscar por 3, 5 o 7 km.',
      'creada_en': '2026-10-12T15:30:00+00:00',
    };

    final notificacion = Notificacion.fromJson(json);

    expect(notificacion.id, 'abc-123');
    expect(notificacion.titulo, 'Nueva versión disponible');
    expect(notificacion.texto, 'Ya podés buscar por 3, 5 o 7 km.');
    expect(notificacion.creadaEn, DateTime.parse('2026-10-12T15:30:00+00:00'));
  });
}
