import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/material.dart' as modelo_material;
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/core/theme.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/material_filter_button.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

// Usa el tema real de la app (no el default de MaterialApp) para que las
// pruebas de layout (overflow) midan las mismas dimensiones que ve el
// usuario — mismo motivo que en comuna_selector_test.dart.
Widget _envolverConTema(Widget child) =>
    MaterialApp(theme: construirTemaReciclai(Brightness.light), home: Scaffold(body: child));

// El catálogo real del backend trae ~160 materiales (ver curl de producción) —
// una lista corta en el test no reproduce el overflow real, que solo aparece
// cuando la lista es lo bastante larga para llegar al alto máximo del
// ConstrainedBox.
List<modelo_material.Material> _catalogoRealista() => [
  for (var i = 0; i < 160; i++) modelo_material.Material(codigo: 'material_$i', nombre: 'Material $i'),
];

Future<MapViewModel> _viewModelConMateriales({List<modelo_material.Material>? materiales}) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(
      materiales:
          materiales ??
          const [
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

  testWidgets('la hoja de materiales muestra un buscador', (tester) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Busca un material'), findsOneWidget);
  });

  testWidgets('escribir en el buscador filtra la lista de materiales', (tester) async {
    final viewModel = await _viewModelConMateriales(
      materiales: const [
        modelo_material.Material(codigo: 'plastico', nombre: 'Plástico'),
        modelo_material.Material(codigo: 'vidrio', nombre: 'Vidrio'),
        modelo_material.Material(codigo: 'papel', nombre: 'Papel'),
      ],
    );
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pla');
    await tester.pumpAndSettle();

    expect(find.text('Plástico'), findsOneWidget);
    expect(find.text('Vidrio'), findsNothing);
    expect(find.text('Papel'), findsNothing);
  });

  testWidgets('la busqueda no distingue mayusculas ni tildes', (tester) async {
    final viewModel = await _viewModelConMateriales(
      materiales: const [modelo_material.Material(codigo: 'plastico', nombre: 'Plástico')],
    );
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'PLASTICO');
    await tester.pumpAndSettle();

    expect(find.text('Plástico'), findsOneWidget);
  });

  testWidgets(
    'filtrar por texto y marcar un material conserva la seleccion aunque se borre la busqueda',
    (tester) async {
      final viewModel = await _viewModelConMateriales(
        materiales: const [
          modelo_material.Material(codigo: 'plastico', nombre: 'Plástico'),
          modelo_material.Material(codigo: 'vidrio', nombre: 'Vidrio'),
        ],
      );
      await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
      await tester.tap(find.byType(MaterialFilterButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'plas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plástico'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Plástico'),
      );
      expect(checkbox.value, isTrue);

      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(viewModel.materialesSeleccionados, {'plastico'});
    },
  );

  testWidgets('sin resultados de busqueda muestra un mensaje', (tester) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();

    expect(find.text('No se encontraron materiales.'), findsOneWidget);
  });

  testWidgets('la hoja de materiales muestra un boton de cerrar (X)', (tester) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('tocar la X cierra la hoja y descarta la seleccion en borrador', (tester) async {
    final viewModel = await _viewModelConMateriales();
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));
    await tester.tap(find.byType(MaterialFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plástico'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Aplicar'), findsNothing);
    expect(viewModel.materialesSeleccionados, isEmpty);
  });

  testWidgets(
    '"Borrar filtros" no infla el alto de la fila del titulo (mismo bug que '
    '"Borrar comuna" con el listado completo)',
    (tester) async {
      final viewModel = await _viewModelConMateriales(materiales: _catalogoRealista());
      viewModel.aplicarFiltroMateriales({'material_0'});
      await tester.pumpWidget(_envolverConTema(MaterialFilterButton(viewModel: viewModel)));
      await tester.tap(find.byType(MaterialFilterButton));
      await tester.pumpAndSettle();

      final alturaTitulo = tester.getSize(find.text('Filtrar por material')).height;
      final alturaBoton = tester.getSize(find.widgetWithText(TextButton, 'Borrar filtros')).height;

      expect(alturaBoton, lessThan(alturaTitulo + 12));
    },
  );

  testWidgets(
    'con el teclado abierto y el catalogo completo de materiales, no hay overflow al buscar',
    (tester) async {
      final viewModel = await _viewModelConMateriales(materiales: _catalogoRealista());
      viewModel.aplicarFiltroMateriales({'material_0'});
      await tester.pumpWidget(_envolverConTema(MaterialFilterButton(viewModel: viewModel)));
      await tester.tap(find.byType(MaterialFilterButton));
      await tester.pumpAndSettle();

      // Simula el teclado abriéndose al tocar el buscador — reproduce el reporte
      // real: el overflow solo aparecía "al buscar", no al abrir la hoja.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'material');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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
