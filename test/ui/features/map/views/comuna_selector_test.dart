import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/ui/core/theme.dart';
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

// Usa el tema real de la app (no el default de MaterialApp) para que las
// pruebas de layout (overflow) midan las mismas dimensiones que ve el
// usuario — un TextButton por defecto mide distinto bajo el tema de la app.
Widget _envolverConTema(Widget child) =>
    MaterialApp(theme: construirTemaReciclai(Brightness.light), home: Scaffold(body: child));

// El pais tiene 345 comunas reales — una lista corta en el test no reproduce
// el overflow real, que solo aparece cuando la lista es lo bastante larga
// para llegar al alto maximo del area de resultados.
List<Comuna> _catalogoRealista() => [
  for (var i = 0; i < 345; i++)
    Comuna(id: 'comuna-$i', nombre: 'Comuna $i', region: 'Metropolitana', centro: const LatLng(-33.5, -70.6)),
];

void main() {
  testWidgets('muestra solo el icono de lupa, sin texto', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Selecciona la comuna'), findsNothing);
    expect(find.text('La Florida'), findsNothing);
  });

  testWidgets('con una comuna seleccionada sigue mostrando solo el icono de lupa', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: _laFlorida.id,
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('tocarlo abre una hoja con buscador y todas las comunas', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search));
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
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
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
          onElegirComuna: (id) => comunaElegida = id,
          onLimpiarComuna: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.tap(find.text('San Joaquín'));
    await tester.pumpAndSettle();

    expect(comunaElegida, 'san-joaquin');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('sin comunas cargadas queda deshabilitado', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(comunas: const [], onElegirComuna: (_) {}, onLimpiarComuna: () {}),
      ),
    );

    await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('la hoja de comunas muestra un boton de cerrar (X)', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('tocar la X cierra la hoja sin elegir ninguna comuna', (tester) async {
    String? comunaElegida;
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          onElegirComuna: (id) => comunaElegida = id,
          onLimpiarComuna: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(comunaElegida, isNull);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'con el teclado abierto y el catalogo completo de comunas, no hay overflow al buscar',
    (tester) async {
      // El surface de test por defecto (800x600 logicos) es mas grande que un
      // telefono real y no reproducia el overflow visto en produccion — se usa
      // el tamano y densidad de un iPhone real (390x844 logicos) mas un alto de
      // teclado iOS tipico (~336) para que la prueba mida el mismo espacio
      // disponible que ve el usuario.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _envolverConTema(
          ComunaSelector(
            comunas: _catalogoRealista(),
            comunaSeleccionadaId: 'comuna-0',
            onElegirComuna: (_) {},
            onLimpiarComuna: () {},
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // El campo ya tiene autofocus, pero simulamos igual el teclado abriendose
      // (como en material_filter_button_test.dart) para reproducir el espacio
      // realmente disponible en un dispositivo real.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'comuna');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sin comuna seleccionada la hoja no muestra boton de borrar comuna', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Borrar comuna'), findsNothing);
  });

  testWidgets('con una comuna seleccionada la hoja muestra boton de borrar comuna', (tester) async {
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: _laFlorida.id,
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Borrar comuna'), findsOneWidget);
  });

  testWidgets(
      '"Borrar comuna" no infla el alto de la fila del titulo (causaba un '
      'BOTTOM OVERFLOW real con la lista completa de 345 comunas)', (tester) async {
    await tester.pumpWidget(
      _envolverConTema(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: _laFlorida.id,
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    final alturaTitulo = tester.getSize(find.text('Selecciona la comuna')).height;
    final alturaBoton = tester.getSize(find.widgetWithText(TextButton, 'Borrar comuna')).height;

    // El boton no debe imponer el alto de toque Material completo (48px) sobre la
    // fila: eso le resta espacio a la lista de comunas, que ya usa un alto maximo
    // fijo (fraccion de la pantalla) y con las 345 comunas reales termina
    // desbordando por unos pixeles al agregarse este boton.
    expect(alturaBoton, lessThan(alturaTitulo + 12));
  });

  testWidgets('tocar "Borrar comuna" en la hoja llama a onLimpiarComuna y la cierra', (
    tester,
  ) async {
    var limpiada = false;
    await tester.pumpWidget(
      _envolver(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: _laFlorida.id,
          onElegirComuna: (_) {},
          onLimpiarComuna: () => limpiada = true,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Borrar comuna'));
    await tester.pumpAndSettle();

    expect(limpiada, isTrue);
    expect(find.byType(TextField), findsNothing);
  });
}
