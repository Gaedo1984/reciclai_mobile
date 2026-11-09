import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/core/theme.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/radius_selector_trigger.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) =>
    MaterialApp(theme: construirTemaReciclai(Brightness.light), home: Scaffold(body: child));

Future<MapViewModel> _viewModelConPermiso(LocationPermissionStatus permiso) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(),
    locationService: LocationServiceFalsa(permiso: permiso, posicion: posicionDePrueba()),
  );
  await viewModel.iniciar();
  return viewModel;
}

void main() {
  testWidgets('sin radio seleccionado muestra el icono sin relleno', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () {})),
    );

    expect(find.byIcon(Icons.wifi_tethering_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering), findsNothing);
  });

  testWidgets('con un radio seleccionado muestra el icono relleno en verde', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await viewModel.seleccionarRadio(3000);
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () {})),
    );

    final icono = tester.widget<Icon>(find.byIcon(Icons.wifi_tethering));
    final colorEsperado =
        Theme.of(tester.element(find.byType(RadiusSelectorTrigger))).colorScheme.primary;
    expect(icono.color, colorEsperado);
  });

  testWidgets('tocarlo con permiso concedido llama a onTap', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    var tocado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () => tocado = true)),
    );

    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    expect(tocado, isTrue);
  });

  testWidgets('sin permiso de ubicacion no responde al toque', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.denegado);
    var tocado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () => tocado = true)),
    );

    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    expect(tocado, isFalse);
  });
}
