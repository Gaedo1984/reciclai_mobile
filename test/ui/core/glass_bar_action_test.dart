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

  testWidgets(
    'tiene un contorno negro solido (8 sombras sin blur) mas un resplandor difuso, '
    'para notarse tanto sobre vidrio claro como oscuro',
    (tester) async {
      await tester.pumpWidget(_envolver(GlassBarAction(icon: Icons.search, onTap: () {})));

      final icono = tester.widget<Icon>(find.byIcon(Icons.search));
      final sombras = icono.shadows!;

      final contorno = sombras.where((s) => s.blurRadius <= 1).toList();
      final resplandor = sombras.where((s) => s.blurRadius > 1).toList();

      // 8 direcciones alrededor del icono, bien opacas, sin difuminar -> se
      // ve como un borde solido en vez de un halo.
      expect(contorno, hasLength(8));
      for (final s in contorno) {
        expect(s.offset, isNot(Offset.zero));
        expect(s.color.a, greaterThan(0.8));
      }
      final direcciones = contorno.map((s) => s.offset).toSet();
      expect(direcciones, hasLength(8));

      expect(resplandor, hasLength(1));
    },
  );

  testWidgets('con un color dado, lo usa en vez del blanco', (tester) async {
    await tester.pumpWidget(
      _envolver(GlassBarAction(icon: Icons.search, onTap: () {}, color: Colors.red)),
    );

    final icono = tester.widget<Icon>(find.byIcon(Icons.search));
    expect(icono.color, Colors.red);
  });

  testWidgets('con onTap null queda deshabilitado (no revienta al tocarlo)', (tester) async {
    await tester.pumpWidget(_envolver(const GlassBarAction(icon: Icons.search, onTap: null)));

    await tester.tap(find.byType(GlassBarAction), warnIfMissed: false);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
