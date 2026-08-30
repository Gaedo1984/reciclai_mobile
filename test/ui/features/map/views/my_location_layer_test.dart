import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/ui/features/map/views/my_location_layer.dart';

import '../../../../fakes.dart';

Widget _envolverEnMapa(Widget child) {
  return MaterialApp(
    home: FlutterMap(
      options: const MapOptions(initialCenter: LatLng(-33.5, -70.6), initialZoom: 12),
      children: [child],
    ),
  );
}

List<Marker> _marcadores(WidgetTester tester) =>
    tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;

void main() {
  testWidgets('no muestra ningun marcador hasta recibir la primera posicion', (tester) async {
    final controlador = StreamController<Position>();
    addTearDown(controlador.close);

    await tester.pumpWidget(_envolverEnMapa(MiUbicacionLayer(posiciones: controlador.stream)));

    expect(_marcadores(tester), isEmpty);
  });

  testWidgets('muestra un marcador en la posicion recibida', (tester) async {
    final controlador = StreamController<Position>();
    addTearDown(controlador.close);

    await tester.pumpWidget(_envolverEnMapa(MiUbicacionLayer(posiciones: controlador.stream)));
    controlador.add(posicionDePrueba(latitude: -33.50, longitude: -70.60));
    await tester.pump();

    final marcadores = _marcadores(tester);
    expect(marcadores, hasLength(1));
    expect(marcadores.single.point.latitude, -33.50);
    expect(marcadores.single.point.longitude, -70.60);
  });

  testWidgets('mueve el marcador cuando el stream emite una posicion nueva', (tester) async {
    final controlador = StreamController<Position>();
    addTearDown(controlador.close);

    await tester.pumpWidget(_envolverEnMapa(MiUbicacionLayer(posiciones: controlador.stream)));
    controlador.add(posicionDePrueba(latitude: -33.50, longitude: -70.60));
    await tester.pump();
    controlador.add(posicionDePrueba(latitude: -33.55, longitude: -70.65));
    await tester.pump();

    final marcadores = _marcadores(tester);
    expect(marcadores, hasLength(1));
    expect(marcadores.single.point.latitude, -33.55);
    expect(marcadores.single.point.longitude, -70.65);
  });
}
