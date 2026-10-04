import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/map/views/material_filter_chips.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('sin materiales seleccionados no muestra nada', (tester) async {
    await tester.pumpWidget(
      _envolver(
        MaterialFilterChips(
          seleccionados: const {},
          nombresDeMateriales: const {},
          onQuitar: (_) {},
        ),
      ),
    );

    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('con materiales seleccionados muestra un chip por cada uno, con su nombre legible',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        MaterialFilterChips(
          seleccionados: const {'plastico', 'vidrio'},
          nombresDeMateriales: const {'plastico': 'Plástico', 'vidrio': 'Vidrio'},
          onQuitar: (_) {},
        ),
      ),
    );

    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('Plástico'), findsOneWidget);
    expect(find.text('Vidrio'), findsOneWidget);
  });

  testWidgets('un material sin nombre legible todavia cargado muestra su codigo crudo',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        MaterialFilterChips(
          seleccionados: const {'plastico'},
          nombresDeMateriales: const {},
          onQuitar: (_) {},
        ),
      ),
    );

    expect(find.text('plastico'), findsOneWidget);
  });

  testWidgets('tocar la "x" de un chip llama a onQuitar con ese codigo', (tester) async {
    String? codigoQuitado;
    await tester.pumpWidget(
      _envolver(
        MaterialFilterChips(
          seleccionados: const {'plastico', 'vidrio'},
          nombresDeMateriales: const {'plastico': 'Plástico', 'vidrio': 'Vidrio'},
          onQuitar: (codigo) => codigoQuitado = codigo,
        ),
      ),
    );

    await tester.tap(find.descendant(
      of: find.widgetWithText(InputChip, 'Plástico'),
      matching: find.byIcon(Icons.clear),
    ));
    await tester.pump();

    expect(codigoQuitado, 'plastico');
  });

  testWidgets('multilinea: con 2 materiales, ambos chips quedan en la misma fila',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        MaterialFilterChips(
          seleccionados: const {'plastico', 'vidrio'},
          nombresDeMateriales: const {'plastico': 'Plástico', 'vidrio': 'Vidrio'},
          onQuitar: (_) {},
          multilinea: true,
        ),
      ),
    );

    final posPlastico = tester.getTopLeft(find.widgetWithText(InputChip, 'Plástico'));
    final posVidrio = tester.getTopLeft(find.widgetWithText(InputChip, 'Vidrio'));

    expect(posPlastico.dy, posVidrio.dy);
    expect(posPlastico.dx, isNot(posVidrio.dx));
  });

  testWidgets('multilinea: el tercer material pasa a una segunda fila, mas abajo',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        MaterialFilterChips(
          seleccionados: const {'plastico', 'vidrio', 'papel'},
          nombresDeMateriales: const {
            'plastico': 'Plástico',
            'vidrio': 'Vidrio',
            'papel': 'Papel',
          },
          onQuitar: (_) {},
          multilinea: true,
        ),
      ),
    );

    final filaUno = tester.getTopLeft(find.widgetWithText(InputChip, 'Plástico')).dy;
    final filaDos = tester.getTopLeft(find.widgetWithText(InputChip, 'Papel')).dy;

    expect(filaDos, greaterThan(filaUno));
  });

  testWidgets('multilinea: con mas de 2 filas, el alto queda acotado y aparece scroll propio',
      (tester) async {
    await tester.pumpWidget(
      _envolver(
        MaterialFilterChips(
          seleccionados: const {'m1', 'm2', 'm3', 'm4', 'm5', 'm6'},
          nombresDeMateriales: const {
            'm1': 'Material 1',
            'm2': 'Material 2',
            'm3': 'Material 3',
            'm4': 'Material 4',
            'm5': 'Material 5',
            'm6': 'Material 6',
          },
          onQuitar: (_) {},
          multilinea: true,
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // Con 6 materiales (3 filas de a 2), si no hubiera un tope de alto con
    // scroll propio ocuparia 3 filas completas -- el contenedor debe quedar
    // acotado a 2 filas visibles como mucho.
    final alturaContenedor = tester.getSize(find.byType(SingleChildScrollView)).height;
    final alturaUnChip = tester.getSize(find.widgetWithText(InputChip, 'Material 1')).height;
    expect(alturaContenedor, lessThan(alturaUnChip * 3));
  });
}
