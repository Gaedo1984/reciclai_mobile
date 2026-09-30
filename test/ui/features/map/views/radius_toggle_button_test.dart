import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/radius_toggle_button.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<MapViewModel> _viewModelConPermiso(LocationPermissionStatus permiso) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(),
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

    expect(find.byIcon(Icons.wifi_tethering_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering), findsNothing);
  });

  testWidgets('con el radio activo muestra el icono relleno', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await viewModel.alternarRadio(true);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    expect(find.byIcon(Icons.wifi_tethering), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering_outlined), findsNothing);
  });

  testWidgets('tocarlo con permiso concedido activa el radio', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pumpAndSettle();

    expect(viewModel.radioActivo, isTrue);
  });

  testWidgets('sin permiso de ubicacion no responde al toque', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.denegado);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pumpAndSettle();

    expect(viewModel.radioActivo, isFalse);
  });
}
