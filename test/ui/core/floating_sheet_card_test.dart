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

  testWidgets(
    'con contenido muy alto, no crece hasta tocar el borde superior de la pantalla',
    (tester) async {
      // Reproduce como showModalBottomSheet(isScrollControlled: true) le da al
      // builder casi toda la altura de la pantalla como maxHeight disponible —
      // sin un tope propio, la tarjeta llegaba hasta arriba con contenido largo
      // (lista de materiales/comunas completa), dejando los controles del
      // encabezado (filtros, boton de cerrar) pegados al borde superior.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FloatingSheetCard(child: const SizedBox(height: 5000, width: 10)),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      final alturaPantalla = tester.getSize(find.byType(MaterialApp)).height;
      final topoDeLaTarjeta = tester.getTopLeft(find.byType(Material).last).dy;

      expect(topoDeLaTarjeta, greaterThan(alturaPantalla * 0.05));
    },
  );
}
