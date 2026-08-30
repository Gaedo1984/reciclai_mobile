import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/data/models/material.dart' as modelo_material;
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/comuna_selector.dart';
import 'package:reciclai_mobile/ui/features/map/views/map_view.dart';

import '../../../../fakes.dart';

const _laFlorida = Comuna(
  id: 'la-florida',
  nombre: 'La Florida',
  region: 'Metropolitana',
  centro: LatLng(-33.50, -70.60),
);

RecyclingPoint _punto() {
  return RecyclingPoint(
    id: '1',
    nombre: 'Punto Limpio',
    direccion: 'Av. Siempre Viva 123',
    ubicacion: const LatLng(-33.52, -70.60),
    tipo: 'punto_limpio',
    materiales: const ['plastico'],
    horario: 'Lun-Vie 9:00-18:00',
    esEmpresa: false,
    sitioWeb: null,
    confianza: 'media',
  );
}

Future<void> _elegirComunaEnElSelector(WidgetTester tester, String nombreComuna) async {
  await tester.tap(find.byType(ComunaSelector));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nombreComuna).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('permiso concedido y comuna cubierta muestra el mapa con un marcador', (
    tester,
  ) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.recycling), findsOneWidget);
  });

  testWidgets('con iniciarAlMontar en false no arranca la carga por su cuenta', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: MapView(viewModel: viewModel, iniciarAlMontar: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.recycling), findsNothing);
  });

  testWidgets(
    'con geolocalizacion y puntos cercanos, el mapa centra en mi ubicacion, no en el promedio de los puntos',
    (tester) async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(latitude: -33.55, longitude: -70.65),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
      );
      await tester.pumpAndSettle();

      final mapa = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapa.options.initialCenter, const LatLng(-33.55, -70.65));
    },
  );

  testWidgets('el selector de comuna esta siempre visible, incluso con puntos cargados', (
    tester,
  ) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ComunaSelector), findsOneWidget);
  });

  testWidgets('sin cobertura muestra el mensaje y el selector con la comuna disponible', (
    tester,
  ) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida], resultadoCercanos: const NotCovered([])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no está cubierta'), findsOneWidget);

    await tester.tap(find.byType(ComunaSelector));
    await tester.pumpAndSettle();

    expect(find.text('La Florida'), findsOneWidget);
  });

  testWidgets('error de red muestra el estado de error con boton reintentar', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(excepcion: const ReciclaiApiException('fallo simulado')),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('tocar un punto abre su detalle', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.recycling));
    await tester.pumpAndSettle();

    expect(find.text('Punto Limpio'), findsOneWidget);
    expect(find.text('Av. Siempre Viva 123'), findsOneWidget);
  });

  testWidgets('elegir una comuna del selector la pide y muestra sus puntos', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        comunas: [_laFlorida],
        resultadoCercanos: const NotCovered([]),
        puntosPorComuna: [_punto()],
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    await _elegirComunaEnElSelector(tester, 'La Florida');

    expect(find.byIcon(Icons.recycling), findsOneWidget);
  });

  testWidgets('el selector sigue visible despues de elegir una comuna (no desaparece)', (
    tester,
  ) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        comunas: [_laFlorida],
        resultadoCercanos: const NotCovered([]),
        puntosPorComuna: [_punto()],
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    await _elegirComunaEnElSelector(tester, 'La Florida');

    expect(find.byType(ComunaSelector), findsOneWidget);
    expect(find.byIcon(Icons.recycling), findsOneWidget);
  });

  testWidgets(
      'elegir una comuna sin puntos centra el mapa en el centro de la comuna, no en Santiago', (
    tester,
  ) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida], resultadoCercanos: const NotCovered([])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    await _elegirComunaEnElSelector(tester, 'La Florida');

    final mapa = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(mapa.options.initialCenter, _laFlorida.centro);
  });

  testWidgets('el detalle de un punto muestra el nombre legible del material, no el codigo', (
    tester,
  ) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        resultadoCercanos: Covered([_punto()]),
        materiales: [const modelo_material.Material(codigo: 'plastico', nombre: 'Plástico')],
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.recycling));
    await tester.pumpAndSettle();

    expect(find.text('Plástico'), findsOneWidget);
    expect(find.text('plastico'), findsNothing);
  });
}
