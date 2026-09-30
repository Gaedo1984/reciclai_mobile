import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/tour/views/tour_trigger_button.dart';

void main() {
  testWidgets('muestra el icono de tour y llama a onTap al tocarlo', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TourTriggerButton(onTap: () => tocado = true))),
    );

    expect(find.byIcon(Icons.tour_outlined), findsOneWidget);
    expect(find.text('Tour'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-trigger-button')));
    expect(tocado, isTrue);
  });

  testWidgets('el pulso de escala anima en loop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TourTriggerButton(onTap: () {}))),
    );

    // find.byType(ScaleTransition) sin acotar encuentra 2: el nuestro y uno que
    // agrega el PageTransitionsTheme por defecto de MaterialApp — se acota al
    // descendiente de TourTriggerButton para apuntar al correcto.
    final finderDeNuestraEscala = find.descendant(
      of: find.byType(TourTriggerButton),
      matching: find.byType(ScaleTransition),
    );

    await tester.pump();
    final escalaInicial = tester.widget<ScaleTransition>(finderDeNuestraEscala).scale.value;

    await tester.pump(const Duration(milliseconds: 750));
    final escalaAMitadDeCamino = tester.widget<ScaleTransition>(finderDeNuestraEscala).scale.value;

    expect(escalaAMitadDeCamino, greaterThan(escalaInicial));
  });
}
