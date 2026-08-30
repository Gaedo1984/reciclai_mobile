import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/map/views/map_attribution.dart';

void main() {
  testWidgets('no muestra el credito de flutter_map', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapAttribution(
                atribuciones: [vt.StyleAttribution.parse('© OpenStreetMap contributors')],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('flutter_map'), findsNothing);
  });

  testWidgets('muestra el texto de atribucion del estilo sin duplicar el simbolo de copyright', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapAttribution(
                atribuciones: [vt.StyleAttribution.parse('© OpenStreetMap contributors')],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });
}
