import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/core/glass_bar_action.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('muestra el icono dado', (tester) async {
    await tester.pumpWidget(_envolver(GlassBarAction(icon: Icons.search, onTap: () {})));

    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('tocarlo llama a onTap', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      _envolver(GlassBarAction(icon: Icons.search, onTap: () => tocado = true)),
    );

    await tester.tap(find.byType(GlassBarAction));

    expect(tocado, isTrue);
  });

  testWidgets('el icono es blanco intenso, para que se note sobre el vidrio', (tester) async {
    await tester.pumpWidget(_envolver(GlassBarAction(icon: Icons.search, onTap: () {})));

    final icono = tester.widget<Icon>(find.byIcon(Icons.search));
    expect(icono.color, Colors.white);
  });

  testWidgets('con onTap null queda deshabilitado (no revienta al tocarlo)', (tester) async {
    await tester.pumpWidget(_envolver(const GlassBarAction(icon: Icons.search, onTap: null)));

    await tester.tap(find.byType(GlassBarAction), warnIfMissed: false);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
