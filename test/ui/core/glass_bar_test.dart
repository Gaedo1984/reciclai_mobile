import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/core/glass_bar.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('muestra todos sus hijos en fila', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const GlassBar(children: [Icon(Icons.search), Icon(Icons.filter_alt)]),
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    expect(find.byType(Row), findsOneWidget);
  });

  testWidgets('tiene extremos totalmente redondeados (forma pildora)', (tester) async {
    await tester.pumpWidget(
      _envolver(const GlassBar(children: [Icon(Icons.search)])),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    final radio = (clip.borderRadius as BorderRadius).topLeft.x;
    expect(radio, greaterThan(100));
  });

  testWidgets('tiene un tinte translucido visible y un borde, no queda invisible', (tester) async {
    await tester.pumpWidget(
      _envolver(const GlassBar(children: [Icon(Icons.search)])),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoracion = container.decoration! as BoxDecoration;
    expect(decoracion.color, isNotNull);
    expect(decoracion.color!.a, greaterThan(0));
    expect(decoracion.border, isNotNull);
  });
}
