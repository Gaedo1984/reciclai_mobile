import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/como_reciclar/material_reciclable.dart';
import 'package:reciclai_mobile/ui/features/como_reciclar/views/carrusel_pasos_modal.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('muestra el titulo con el nombre del material', (tester) async {
    const material = MaterialReciclable(
      codigo: 'vidrio',
      nombre: 'Vidrio',
      emoji: '🫙',
      imagenesPasos: [],
    );

    await tester.pumpWidget(_envolver(CarruselPasosModal(material: material)));

    expect(find.text('Vidrio'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Vidrio')).textAlign, TextAlign.center);
  });

  testWidgets(
    'sin imagenes de pasos, avisa que todavia no hay contenido (en vez de un carrusel vacio)',
    (tester) async {
      const material = MaterialReciclable(
        codigo: 'vidrio',
        nombre: 'Vidrio',
        emoji: '🫙',
        imagenesPasos: [],
      );

      await tester.pumpWidget(_envolver(CarruselPasosModal(material: material)));

      expect(find.text('Todavía no hay contenido para este material.'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    },
  );

  testWidgets('con imagenes de pasos, muestra el carrusel y un punto indicador por paso', (
    tester,
  ) async {
    const material = MaterialReciclable(
      codigo: 'vidrio',
      nombre: 'Vidrio',
      emoji: '🫙',
      imagenesPasos: ['assets/como_reciclar/vidrio/paso_1.png', 'assets/como_reciclar/vidrio/paso_2.png'],
    );

    await tester.pumpWidget(_envolver(CarruselPasosModal(material: material)));

    expect(find.byType(PageView), findsOneWidget);
    expect(
      find.text('Todavía no hay contenido para este material.'),
      findsNothing,
    );
    // 2 pasos -> 2 puntos indicadores.
    expect(find.byKey(const ValueKey('punto-indicador-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('punto-indicador-1')), findsOneWidget);
  });

  testWidgets('la X cierra el modal', (tester) async {
    const material = MaterialReciclable(
      codigo: 'vidrio',
      nombre: 'Vidrio',
      emoji: '🫙',
      imagenesPasos: [],
    );

    await tester.pumpWidget(
      _envolver(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => CarruselPasosModal(material: material),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Vidrio'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Vidrio'), findsNothing);
  });

  testWidgets('en una pantalla baja, el carrusel se achica para no desbordar el modal', (
    tester,
  ) async {
    const material = MaterialReciclable(
      codigo: 'vidrio',
      nombre: 'Vidrio',
      emoji: '🫙',
      imagenesPasos: ['assets/como_reciclar/vidrio/paso_1.png'],
    );
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(_envolver(CarruselPasosModal(material: material)));

    expect(tester.takeException(), isNull);
    final caja = tester.widget<SizedBox>(
      find.ancestor(of: find.byType(PageView), matching: find.byType(SizedBox)).first,
    );
    expect(caja.height, lessThan(520.0));
  });
}
