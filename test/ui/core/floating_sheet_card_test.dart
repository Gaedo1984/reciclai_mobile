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

  testWidgets(
    'con el teclado abierto, tambien deja el mismo margen visible arriba',
    (tester) async {
      // El tope de alto de FloatingSheetCard se calculaba solo con
      // MediaQuery.size.height, sin restar el teclado — cuando el teclado
      // aparecia (buscador de materiales/comunas), ese tope dejaba de ser el
      // mas restrictivo (la restriccion real, ya reducida por el teclado via
      // el Padding que envuelve la tarjeta en los buscadores, pasaba a ser
      // mayor que el tope), asi que la tarjeta volvia a crecer hasta pegarse
      // arriba — justo donde antes quedaba, dificultando alcanzar la cruz
      // para cerrar.
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (contextDeLaHoja) => Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(contextDeLaHoja).viewInsets.bottom),
                    child: FloatingSheetCard(child: const SizedBox(height: 5000, width: 10)),
                  ),
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
      final margenSinTeclado = tester.getTopLeft(find.byType(Material).last).dy;

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final margenConTeclado = tester.getTopLeft(find.byType(Material).last).dy;

      expect(margenConTeclado, greaterThan(alturaPantalla * 0.05));
      // El margen no deberia achicarse notoriamente solo porque aparecio el teclado.
      expect(margenConTeclado, greaterThanOrEqualTo(margenSinTeclado - 5));
    },
  );
}
