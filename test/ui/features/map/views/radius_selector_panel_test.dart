import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/core/theme.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/radius_selector_panel.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) =>
    MaterialApp(theme: construirTemaReciclai(Brightness.light), home: Scaffold(body: child));

Future<MapViewModel> _viewModelConPermiso() async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(resultadoEnRadio: []),
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  return viewModel;
}

void main() {
  testWidgets('muestra los 4 botones: Off, 3 km, 5 km, 7 km', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () {})),
    );

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('3 km'), findsOneWidget);
    expect(find.text('5 km'), findsOneWidget);
    expect(find.text('7 km'), findsOneWidget);
  });

  testWidgets('sin radio activo, "Off" no responde al toque', (tester) async {
    final viewModel = await _viewModelConPermiso();
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.text('Off'), warnIfMissed: false);
    await tester.pump();

    expect(viewModel.radioMetrosSeleccionado, isNull);
    expect(cerrado, isFalse);
  });

  testWidgets('con un radio activo, tocar "Off" lo apaga y cierra el panel', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await viewModel.seleccionarRadio(3000);
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.text('Off'));
    await tester.pump();

    expect(viewModel.radioMetrosSeleccionado, isNull);
    expect(cerrado, isTrue);
  });

  testWidgets('tocar "5 km" selecciona ese radio y cierra el panel', (tester) async {
    final viewModel = await _viewModelConPermiso();
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.text('5 km'));
    await tester.pump();

    expect(viewModel.radioMetrosSeleccionado, 5000);
    expect(cerrado, isTrue);
  });

  testWidgets('el radio activo se ve resaltado en verde', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await viewModel.seleccionarRadio(7000);
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () {})),
    );

    final material = tester.widget<Material>(
      find.ancestor(of: find.text('7 km'), matching: find.byType(Material)).first,
    );
    final colorEsperado =
        Theme.of(tester.element(find.byType(RadiusSelectorPanel))).colorScheme.primary;
    expect(material.color, colorEsperado);
  });

  testWidgets('tiene su propia X para cerrar sin elegir nada', (tester) async {
    final viewModel = await _viewModelConPermiso();
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cerrado, isTrue);
    expect(viewModel.radioMetrosSeleccionado, isNull);
  });

  testWidgets('los 4 botones tienen 1.5px de separacion entre si', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () {})),
    );

    // "3 km" y "5 km" son vecinos directos en la fila (a diferencia de "Off",
    // que va al final, despues de "7 km") -- se verifica que esten pegados
    // (sin un hueco grande entre ellos), no un valor exacto de texto a
    // texto, que depende del padding horizontal propio de cada boton.
    final derecha3km = tester.getTopRight(find.text('3 km')).dx;
    final izquierda5km = tester.getTopLeft(find.text('5 km')).dx;
    expect(izquierda5km, greaterThanOrEqualTo(derecha3km));
    expect(izquierda5km - derecha3km, lessThan(20));
  });
}
