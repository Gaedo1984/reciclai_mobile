import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/tour/tour_step.dart';
import 'package:reciclai_mobile/ui/features/tour/views/tour_overlay.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('un paso sin anchorKey muestra una tarjeta centrada con su texto', (tester) async {
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [TourStep(titulo: 'El mapa', cuerpo: 'Los pines son puntos de reciclaje.')],
          onCerrar: () {},
        ),
      ),
    );

    expect(find.text('El mapa'), findsOneWidget);
    expect(find.text('Los pines son puntos de reciclaje.'), findsOneWidget);
  });

  testWidgets('Siguiente avanza al segundo paso', (tester) async {
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [
            TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso dos', cuerpo: 'Dos'),
          ],
          onCerrar: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(find.text('Paso dos'), findsOneWidget);
    expect(find.text('Paso uno'), findsNothing);
  });

  testWidgets('el ultimo paso dice Listo y cierra el tour al tocarlo', (tester) async {
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [TourStep(titulo: 'Unico paso', cuerpo: 'Contenido')],
          onCerrar: () => cerrado = true,
        ),
      ),
    );

    expect(find.text('Listo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(cerrado, isTrue);
  });

  testWidgets('Atras no aparece en el primer paso, aparece despues y retrocede', (tester) async {
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [
            TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso dos', cuerpo: 'Dos'),
          ],
          onCerrar: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('tour-atras')), findsNothing);

    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();
    expect(find.byKey(const Key('tour-atras')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-atras')));
    await tester.pump();
    expect(find.text('Paso uno'), findsOneWidget);
  });

  testWidgets('Saltar cierra el tour inmediatamente desde cualquier paso', (tester) async {
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [
            TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso dos', cuerpo: 'Dos'),
          ],
          onCerrar: () => cerrado = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tour-saltar')));
    await tester.pump();

    expect(cerrado, isTrue);
  });

  testWidgets('Atras no aparece si no hay ningun paso montado antes (aunque el indice sea > 0)', (
    tester,
  ) async {
    final keyNoMontado = GlobalKey();
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: [
            TourStep(titulo: 'Paso fantasma', cuerpo: '-', anchorKey: keyNoMontado),
            const TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
          ],
          onCerrar: () {},
        ),
      ),
    );

    // El tour arranca saltando el paso fantasma (indice interno queda en 1).
    expect(find.text('Paso uno'), findsOneWidget);
    // No hay ningun paso montado antes del actual — Atras no debe aparecer,
    // aunque el indice interno sea 1 (> 0).
    expect(find.byKey(const Key('tour-atras')), findsNothing);
  });

  testWidgets('un paso con anchorKey no montado se salta solo', (tester) async {
    final keyNoMontado = GlobalKey();
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: [
            const TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso saltado', cuerpo: 'No deberia verse', anchorKey: keyNoMontado),
            const TourStep(titulo: 'Paso tres', cuerpo: 'Tres'),
          ],
          onCerrar: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(find.text('Paso tres'), findsOneWidget);
    expect(find.text('Paso saltado'), findsNothing);
  });

  testWidgets('si todos los pasos tienen anclas sin montar, se cierra solo', (tester) async {
    var cerrado = false;
    final keyNoMontado = GlobalKey();
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: [TourStep(titulo: 'Nunca visible', cuerpo: '-', anchorKey: keyNoMontado)],
          onCerrar: () => cerrado = true,
        ),
      ),
    );
    await tester.pump();

    expect(cerrado, isTrue);
    expect(find.text('Nunca visible'), findsNothing);
  });

  testWidgets('las acciones no se desbordan con letra grande (accesibilidad)', (tester) async {
    // Pantalla angosta real (360dp, un Android tipico) — con el tamano por
    // defecto del test (800 logico) el desborde no se reproduce.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(
          body: TourOverlay(
            pasos: const [
              TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
              TourStep(titulo: 'Paso dos', cuerpo: 'Dos'),
            ],
            onCerrar: () {},
          ),
        ),
      ),
    );

    // Con los 3 botones visibles (Saltar, Atras, Siguiente) es cuando mas
    // espacio horizontal se necesita.
    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar el area oscurecida no cierra ni cambia de paso', (tester) async {
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [TourStep(titulo: 'Paso uno', cuerpo: 'Uno')],
          onCerrar: () => cerrado = true,
        ),
      ),
    );

    // Esquina superior izquierda: fuera de la tarjeta centrada.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(cerrado, isFalse);
    expect(find.text('Paso uno'), findsOneWidget);
  });
}
