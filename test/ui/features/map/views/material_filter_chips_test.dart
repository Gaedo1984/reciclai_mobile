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
}
