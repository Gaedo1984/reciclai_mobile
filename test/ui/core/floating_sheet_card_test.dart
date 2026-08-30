import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/core/floating_sheet_card.dart';

void main() {
  testWidgets('envuelve el contenido en un Material con bordes redondeados en las 4 esquinas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FloatingSheetCard(child: const Text('contenido'))),
    );

    expect(find.text('contenido'), findsOneWidget);
    final material = tester.widget<Material>(find.byType(Material).last);
    final forma = material.borderRadius as BorderRadius;
    expect(forma.topLeft, forma.bottomLeft);
    expect(forma.topLeft, forma.bottomRight);
    expect(forma.topLeft.x, greaterThan(0));
  });
}
