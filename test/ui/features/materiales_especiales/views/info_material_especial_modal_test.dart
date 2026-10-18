import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/materiales_especiales/material_especial.dart';
import 'package:reciclai_mobile/ui/features/materiales_especiales/views/info_material_especial_modal.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

const _material = MaterialEspecial(
  codigo: 'pilas',
  nombre: 'Pilas',
  emoji: '🔋',
  descripcion: 'Descripcion de prueba.',
  comoPrepararlo: 'Preparacion de prueba.',
  dondeReciclar: 'Donde reciclar de prueba.',
);

void main() {
  testWidgets('muestra el nombre del material centrado como titulo', (tester) async {
    await tester.pumpWidget(_envolver(const InfoMaterialEspecialModal(material: _material)));

    expect(find.text('Pilas'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Pilas')).textAlign, TextAlign.center);
  });

  testWidgets('muestra la descripcion, como prepararlo y donde reciclar', (tester) async {
    await tester.pumpWidget(_envolver(const InfoMaterialEspecialModal(material: _material)));

    expect(find.text('Descripcion de prueba.'), findsOneWidget);
    expect(find.text('Preparacion de prueba.'), findsOneWidget);
    expect(find.text('Donde reciclar de prueba.'), findsOneWidget);
    expect(find.text('Cómo prepararlo'), findsOneWidget);
    expect(find.text('Dónde reciclar'), findsOneWidget);
  });

  testWidgets('la X cierra el modal', (tester) async {
    await tester.pumpWidget(
      _envolver(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const InfoMaterialEspecialModal(material: _material),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Pilas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Pilas'), findsNothing);
  });
}
