import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/ui/features/map/views/comuna_selector.dart';
import 'package:latlong2/latlong.dart';

const _laFlorida = Comuna(
  id: 'la-florida',
  nombre: 'La Florida',
  region: 'Metropolitana',
  centro: LatLng(-33.50, -70.60),
);
const _sanJoaquin = Comuna(
  id: 'san-joaquin',
  nombre: 'San Joaquín',
  region: 'Metropolitana',
  centro: LatLng(-33.53, -70.62),
);

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('no ocupa todo el ancho de la pantalla', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: null,
          onElegirComuna: (_) {},
        ),
      ),
    );

    final anchoPantalla = tester.getSize(find.byType(MaterialApp)).width;
    final anchoBarra = tester.getSize(find.byType(ComunaSelector)).width;
    expect(anchoBarra, lessThan(anchoPantalla));
  });

  testWidgets('muestra el icono de lupa y deja un espacio reservado (invisible) para filtros', (
    tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: null,
          onElegirComuna: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byKey(const Key('espacio-filtro-reservado')), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt), findsNothing);
  });

  testWidgets('sin comuna elegida muestra el texto "Selecciona la comuna"', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: null,
          onElegirComuna: (_) {},
        ),
      ),
    );

    expect(find.text('Selecciona la comuna'), findsOneWidget);
  });

  testWidgets('con una comuna elegida muestra su nombre en la caja', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: 'la-florida',
          onElegirComuna: (_) {},
        ),
      ),
    );

    expect(find.text('La Florida'), findsOneWidget);
  });

  testWidgets('tocar la caja abre una hoja con buscador y todas las comunas', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: null,
          onElegirComuna: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(ComunaSelector));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('La Florida'), findsOneWidget);
    expect(find.text('San Joaquín'), findsOneWidget);
  });

  testWidgets('escribir en el buscador filtra la lista de comunas', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: null,
          onElegirComuna: (_) {},
        ),
      ),
    );
    await tester.tap(find.byType(ComunaSelector));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'san');
    await tester.pumpAndSettle();

    expect(find.text('San Joaquín'), findsOneWidget);
    expect(find.text('La Florida'), findsNothing);
  });

  testWidgets('elegir una comuna de la lista llama a onElegirComuna y cierra la hoja', (
    tester,
  ) async {
    String? comunaElegida;
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: null,
          onElegirComuna: (id) => comunaElegida = id,
        ),
      ),
    );
    await tester.tap(find.byType(ComunaSelector));
    await tester.pumpAndSettle();

    await tester.tap(find.text('San Joaquín'));
    await tester.pumpAndSettle();

    expect(comunaElegida, 'san-joaquin');
    expect(find.byType(TextField), findsNothing);
  });
}
