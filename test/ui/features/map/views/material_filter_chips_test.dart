import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/material.dart' as modelo_material;
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/material_filter_chips.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<MapViewModel> _viewModelConMateriales() async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(
      materiales: const [
        modelo_material.Material(codigo: 'plastico', nombre: 'Plástico'),
        modelo_material.Material(codigo: 'vidrio', nombre: 'Vidrio'),
      ],
    ),
    locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
  );
  await viewModel.iniciar();
  return viewModel;
}

void main() {
  testWidgets('sin materiales seleccionados no muestra nada', (tester) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterChips(viewModel: viewModel)));

    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('con materiales seleccionados muestra un chip por cada uno, con su nombre legible',
      (tester) async {
    final viewModel = await _viewModelConMateriales();
    viewModel.aplicarFiltroMateriales({'plastico', 'vidrio'});
    await tester.pumpWidget(_envolver(MaterialFilterChips(viewModel: viewModel)));

    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('Plástico'), findsOneWidget);
    expect(find.text('Vidrio'), findsOneWidget);
  });

  testWidgets('tocar la "x" de un chip saca solo ese material del filtro', (tester) async {
    final viewModel = await _viewModelConMateriales();
    viewModel.aplicarFiltroMateriales({'plastico', 'vidrio'});
    await tester.pumpWidget(_envolver(MaterialFilterChips(viewModel: viewModel)));

    await tester.tap(find.descendant(
      of: find.widgetWithText(InputChip, 'Plástico'),
      matching: find.byIcon(Icons.clear),
    ));
    await tester.pump();

    expect(viewModel.materialesSeleccionados, {'vidrio'});
  });
}
