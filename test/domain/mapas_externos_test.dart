import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/domain/mapas_externos.dart';

void main() {
  const destino = LatLng(-33.52, -70.60);

  test('por defecto incluye Google Maps y Waze, en ese orden', () {
    final opciones = opcionesDeRuta(destino);

    expect(opciones.map((o) => o.nombre), ['Google Maps', 'Waze']);
  });

  test('Google Maps usa el link universal de direcciones con el destino', () {
    final opciones = opcionesDeRuta(destino);

    final googleMaps = opciones.firstWhere((o) => o.nombre == 'Google Maps');
    expect(
      googleMaps.uri,
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=-33.52,-70.6'),
    );
  });

  test('Waze usa su link universal con el destino', () {
    final opciones = opcionesDeRuta(destino);

    final waze = opciones.firstWhere((o) => o.nombre == 'Waze');
    expect(waze.uri, Uri.parse('https://waze.com/ul?ll=-33.52,-70.6&navigate=yes'));
  });

  test('sin incluirAppleMaps, no ofrece la opcion Maps (no existe en Android)', () {
    final opciones = opcionesDeRuta(destino);

    expect(opciones.any((o) => o.nombre == 'Maps'), isFalse);
  });

  test('con incluirAppleMaps: true, agrega Maps al final con su link universal', () {
    final opciones = opcionesDeRuta(destino, incluirAppleMaps: true);

    expect(opciones.map((o) => o.nombre), ['Google Maps', 'Waze', 'Maps']);
    final maps = opciones.last;
    expect(maps.uri, Uri.parse('https://maps.apple.com/?daddr=-33.52,-70.6'));
  });
}
