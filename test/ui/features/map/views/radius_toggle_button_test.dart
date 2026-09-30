import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/radius_toggle_button.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<MapViewModel> _viewModelConPermiso(LocationPermissionStatus permiso) async {
  final viewModel = MapViewModel(
    // resultadoCercanos lo consume la carga inicial de iniciar() cuando el
    // permiso es concedido — sin esto, ApiClientFalso.obtenerPuntosCercanos
    // revienta con un null-check error antes de llegar a lo que el test prueba.
    apiClient: ApiClientFalso(resultadoCercanos: const Covered([])),
    locationService: LocationServiceFalsa(
      permiso: permiso,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  return viewModel;
}

void main() {
  testWidgets('con el radio inactivo muestra el icono sin relleno', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    expect(find.byIcon(Icons.social_distance_outlined), findsOneWidget);
    expect(find.byIcon(Icons.social_distance), findsNothing);
  });

  testWidgets('con el radio activo muestra el icono relleno', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await viewModel.alternarRadio(true);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    expect(find.byIcon(Icons.social_distance), findsOneWidget);
    expect(find.byIcon(Icons.social_distance_outlined), findsNothing);
  });

  testWidgets('tocarlo con permiso concedido activa el radio', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.social_distance_outlined));
    await tester.pumpAndSettle();

    expect(viewModel.radioActivo, isTrue);
  });

  testWidgets('sin permiso de ubicacion no responde al toque', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.denegado);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.social_distance_outlined));
    await tester.pumpAndSettle();

    expect(viewModel.radioActivo, isFalse);
  });
}
