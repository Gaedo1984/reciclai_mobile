import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/como_reciclar/views/carrusel_pasos_modal.dart';
import 'package:reciclai_mobile/ui/features/como_reciclar/views/menu_lateral.dart';

Widget _envolver() => MaterialApp(
  home: Scaffold(
    appBar: AppBar(),
    drawer: const MenuLateral(),
    body: const SizedBox(),
  ),
);

void main() {
  testWidgets('el drawer arranca con "Como reciclar" colapsado, sin los materiales visibles', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Cómo reciclar'), findsOneWidget);
    expect(find.text('Vidrio'), findsNothing);
  });

  testWidgets('al tocar "Como reciclar" se despliegan los 3 materiales', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cómo reciclar'));
    await tester.pumpAndSettle();

    expect(find.text('Vidrio'), findsOneWidget);
    expect(find.text('Aluminio (latas de bebida)'), findsOneWidget);
    expect(find.text('Botellas de plástico'), findsOneWidget);
  });

  testWidgets('tocar un material cierra el drawer y abre su modal de pasos', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cómo reciclar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vidrio'));
    await tester.pumpAndSettle();

    // El drawer ya no esta (se cerro).
    expect(find.text('Botellas de plástico'), findsNothing);
    // El modal del material tocado esta abierto.
    expect(find.byType(CarruselPasosModal), findsOneWidget);
    expect(find.text('Cómo reciclar: Vidrio'), findsOneWidget);
  });
}
