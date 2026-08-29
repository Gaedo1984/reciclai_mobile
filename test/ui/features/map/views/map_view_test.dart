import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/data/models/material.dart' as modelo_material;
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/map_view.dart';

import '../../../../fakes.dart';

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

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('sin cobertura muestra el selector de comuna con el mensaje', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        resultadoCercanos: NotCovered([
          const Comuna(id: 'la-florida', nombre: 'La Florida', region: 'Metropolitana'),
        ]),
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    expect(find.textContaining('no está cubierta'), findsOneWidget);
    expect(find.text('La Florida'), findsOneWidget);
  });

  testWidgets('error de red muestra el estado de error con boton reintentar', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(excepcion: const ReciclaiApiException('fallo simulado')),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
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

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();

    expect(find.text('Punto Limpio'), findsOneWidget);
    expect(find.text('Av. Siempre Viva 123'), findsOneWidget);
  });

  testWidgets('elegir una comuna del selector la pide y muestra sus puntos', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        resultadoCercanos: NotCovered([
          const Comuna(id: 'la-florida', nombre: 'La Florida', region: 'Metropolitana'),
        ]),
        puntosPorComuna: [_punto()],
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('La Florida'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.location_on), findsOneWidget);
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

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();

    expect(find.text('Plástico'), findsOneWidget);
    expect(find.text('plastico'), findsNothing);
  });
}
