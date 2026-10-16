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

  testWidgets('tiene una X en la esquina superior derecha que cierra el drawer', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // El drawer ya no esta -- su contenido no aparece.
    expect(find.text('Cómo reciclar'), findsNothing);
  });

  testWidgets('la X usa el color de icono del tema, visible en claro y oscuro', (tester) async {
    for (final brillo in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brillo),
          home: Scaffold(appBar: AppBar(), drawer: const MenuLateral(), body: const SizedBox()),
        ),
      );
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      final icono = tester.widget<Icon>(find.byIcon(Icons.close));
      // Sin color fijo -- toma el color de icono ambiente del tema, que ya
      // se adapta solo entre claro/oscuro (a diferencia de una imagen
      // rasterizada con colores fijos, ver el logo de notificaciones).
      expect(icono.color, isNull);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
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

  testWidgets('Botellas de plastico ya tiene sus 5 pasos reales, no el aviso de contenido pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cómo reciclar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Botellas de plástico'));
    await tester.pumpAndSettle();

    expect(find.text('Cómo reciclar: Botellas de plástico'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
    }
  });
}
