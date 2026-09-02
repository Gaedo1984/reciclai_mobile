import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/material.dart' as modelo_material;
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/material_filter_button.dart';

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
  testWidgets('sin materiales seleccionados muestra el icono de filtro sin relleno', (
    tester,
  ) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));

    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt), findsNothing);
  });

  testWidgets('con materiales seleccionados muestra el icono de filtro relleno', (tester) async {
    final viewModel = await _viewModelConMateriales();
    viewModel.aplicarFiltroMateriales({'plastico'});
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));

    expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
  });

  testWidgets('con materiales seleccionados, el icono usa el color de acento del tema', (
    tester,
  ) async {
    final viewModel = await _viewModelConMateriales();
    viewModel.aplicarFiltroMateriales({'plastico'});
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));

    final icono = tester.widget<Icon>(find.byIcon(Icons.filter_alt));
    final colorEsperado = Theme.of(
      tester.element(find.byType(MaterialFilterButton)),
    ).colorScheme.secondary;
    expect(icono.color, colorEsperado);
  });

  testWidgets('sin materiales seleccionados, el icono sigue blanco', (tester) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));

    final icono = tester.widget<Icon>(find.byIcon(Icons.filter_alt_outlined));
    expect(icono.color, Colors.white);
  });

  testWidgets('tocarlo abre una hoja con la lista de materiales y un boton Aplicar', (
    tester,
  ) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));

    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    expect(find.text('Plástico'), findsOneWidget);
    expect(find.text('Vidrio'), findsOneWidget);
    expect(find.text('Aplicar'), findsOneWidget);
  });

  testWidgets('tocar un material lo marca en la hoja pero no cambia el filtro real todavia', (
    tester,
  ) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plástico'));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).first);
    expect(checkbox.value, isTrue);
    expect(viewModel.materialesSeleccionados, isEmpty);
  });

  testWidgets('tocar Aplicar confirma la seleccion en el viewModel y cierra la hoja', (
    tester,
  ) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plástico'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(viewModel.materialesSeleccionados, {'plastico'});
    expect(find.text('Aplicar'), findsNothing);
  });

  testWidgets('cerrar la hoja sin tocar Aplicar descarta la seleccion en borrador', (
    tester,
  ) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plástico'));
    await tester.pumpAndSettle();

    // Cierra tocando afuera de la hoja (el scrim), no el boton Aplicar.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(viewModel.materialesSeleccionados, isEmpty);
  });

  testWidgets('sin materiales seleccionados no muestra "Borrar filtros"', (tester) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    expect(find.text('Borrar filtros'), findsNothing);
  });

  testWidgets(
    'con materiales ya aplicados, tocar "Borrar filtros" y luego Aplicar limpia el filtro real',
    (tester) async {
      final viewModel = await _viewModelConMateriales();
      viewModel.aplicarFiltroMateriales({'plastico', 'vidrio'});
      await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
      await tester.tap(find.byType(MaterialFilterButton));
      await tester.pumpAndSettle();

      expect(find.text('Borrar filtros'), findsOneWidget);
      await tester.tap(find.text('Borrar filtros'));
      await tester.pumpAndSettle();

      // Todavia no se aplico - el filtro real sigue como estaba.
      expect(viewModel.materialesSeleccionados, {'plastico', 'vidrio'});

      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(viewModel.materialesSeleccionados, isEmpty);
    },
  );

  testWidgets('sin catalogo de materiales cargado queda deshabilitado', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));

    await tester.tap(find.byType(MaterialFilterButton), warnIfMissed: false);
    await tester.pump();

    expect(find.text('Filtrar por material'), findsNothing);
  });
}
