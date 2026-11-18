import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/servicio_retiro.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/ui/features/camion_reciclaje/view_models/camion_reciclaje_view_model.dart';
import 'package:reciclai_mobile/ui/features/camion_reciclaje/views/hoja_camion_reciclaje.dart';

import '../../../../fakes.dart';

List<CalleZona> _calles(List<String> nombres) => [
  for (final (i, nombre) in nombres.indexed)
    CalleZona(
      nombre: nombre,
      referencia: const [
        'Límite norte',
        'Límite oriente',
        'Límite sur',
        'Límite poniente',
      ][i],
    ),
];

ZonaRetiro _zona(String id, String nombre, String dia, List<String> calles) =>
    ZonaRetiro(
      id: id,
      nombre: nombre,
      dias: [dia],
      calles: _calles(calles),
      poligonos: const [],
    );

/// Datos reales de San Joaquín (scripts/data/zonas_retiro/13129.json del
/// backend), sin geometria.
ServicioRetiro _servicioSanJoaquin({String? zonaActualId = '13129-t4-5'}) =>
    ServicioRetiro(
      comunaId: '13129',
      comunaNombre: 'San Joaquín',
      horario: 'Saca tu reciclaje desde las 8:00',
      materiales: const ['Papel y cartón', 'Plásticos', 'Aluminio', 'Tetrapak', 'Vidrio'],
      fuenteNombre: 'Municipalidad de San Joaquín',
      actualizado: DateTime(2026, 11, 16),
      zonaActualId: zonaActualId,
      zonas: [
        _zona('13129-t1', 'Territorio 1', 'lunes', [
          'Santa María', 'Vicuña Mackenna', 'Carlos Valdovinos', 'Santa Rosa',
        ]),
        _zona('13129-t2', 'Territorio 2', 'viernes', [
          'Carlos Valdovinos', 'Las Industrias', 'Salvador Allende', 'Santa Rosa',
        ]),
        _zona('13129-t3', 'Territorio 3', 'miércoles', [
          'Carlos Valdovinos', 'Vicuña Mackenna', 'Salvador Allende', 'Las Industrias',
        ]),
        _zona('13129-t4-5', 'Territorios 4 y 5', 'martes', [
          'Salvador Allende', 'Vicuña Mackenna', 'Departamental', 'Santa Rosa',
        ]),
        _zona('13129-t6-7', 'Territorios 6 y 7', 'jueves', [
          'Departamental', 'Vicuña Mackenna', 'Lo Ovalle', 'Santa Rosa',
        ]),
      ],
    );

Future<CamionReciclajeViewModel> _viewModelAbierto(ApiClientFalso apiClient) async {
  final viewModel = CamionReciclajeViewModel(
    apiClient: apiClient,
    ahora: () => DateTime(2026, 11, 16),
  );
  await viewModel.abrir(comunaId: '13129');
  return viewModel;
}

Future<void> _montar(
  WidgetTester tester,
  CamionReciclajeViewModel viewModel, {
  bool sinAnimaciones = false,
  Size tamano = const Size(800, 1600),
}) async {
  // Alto suficiente para que la hoja (0.62 de la pantalla) muestre todo.
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: sinAnimaciones),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: HojaCamionReciclaje(viewModel: viewModel),
            ),
          ),
        ),
      ),
    ),
  );
}

double _opacidad(WidgetTester tester, Key key) =>
    tester.widget<FadeTransition>(find.byKey(key)).opacity.value;

/// Opacidad con la que se ve el widget: producto de todos los
/// `FadeTransition` que lo envuelven (incluido el suyo).
double _opacidadVisible(WidgetTester tester, Key key) {
  expect(find.byKey(key), findsOneWidget, reason: '$key');
  final fades = find.ancestor(
    of: find.byKey(key),
    matching: find.byType(FadeTransition),
  );
  var opacidad = 1.0;
  for (final fade in tester.widgetList<FadeTransition>(fades)) {
    opacidad *= fade.opacity.value;
  }
  return opacidad;
}

/// Cada tramo de la linea une el punto `i - 1` con el `i` y se dibuja en dos
/// partes: la cola bajo el punto anterior y la cabeza sobre el suyo.
List<Key> _partesDelTramo(int i) => [Key('tramo-$i-cola'), Key('tramo-$i-cabeza')];

void main() {
  testWidgets('el boton de aviso explica que las rutas son referenciales', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    final boton = find.byKey(const Key('aviso-camion'));
    expect(boton, findsOneWidget);
    expect(
      find.descendant(of: boton, matching: find.byIcon(Icons.error_outline)),
      findsOneWidget,
    );
    expect(find.text(textoAvisoRutasReferenciales), findsNothing);

    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(find.text('Información referencial'), findsOneWidget);
    expect(find.text(textoAvisoRutasReferenciales), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text(textoAvisoRutasReferenciales), findsNothing);
  });

  testWidgets('muestra el dia del usuario destacado', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hoja-camion')), findsOneWidget);
    expect(find.text('Camión de reciclaje'), findsOneWidget);
    expect(find.text('San Joaquín · Territorios 4 y 5'), findsOneWidget);
    expect(find.text('El camión pasa por tu casa los'), findsOneWidget);
    expect(find.text('Martes'), findsOneWidget);
    expect(find.text('Saca tu reciclaje desde las 8:00'), findsOneWidget);
    for (final etiqueta in ['Lun', 'Mar', 'Mié', 'Jue', 'Vie']) {
      expect(find.text(etiqueta), findsOneWidget);
    }
    expect(find.text('Sáb'), findsNothing);
    expect(find.text('Dom'), findsNothing);
    // El punto azul marca el chip del dia del usuario y solo ese.
    expect(
      find.descendant(
        of: find.byKey(const Key('chip-dia-martes')),
        matching: find.byKey(const Key('punto-dia-del-usuario')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('punto-dia-del-usuario')), findsOneWidget);
    expect(find.text('Recorre el sector entre'), findsOneWidget);
    expect(find.text('Qué puedes sacar'), findsOneWidget);
    expect(find.text('Tetrapak'), findsOneWidget);
    expect(
      find.text('Fuente: Municipalidad de San Joaquín · actualizado nov 2026'),
      findsOneWidget,
    );
  });

  testWidgets('las calles aparecen una a una y quedan todas', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel);

    // La primera calle empieza a los 450 ms; la segunda recien a los 870 ms.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacidad(tester, const Key('calle-0')), greaterThan(0));
    expect(_opacidad(tester, const Key('calle-1')), 0);

    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      expect(_opacidad(tester, Key('calle-$i')), 1);
    }
    expect(_opacidad(tester, const Key('camion-recorrido-completo')), 1);
    expect(
      find.descendant(
        of: find.byKey(const Key('camion-recorrido-completo')),
        matching: find.text('4 calles · recorrido completo'),
      ),
      findsOneWidget,
    );
    expect(find.text('Salvador Allende'), findsOneWidget);
    expect(find.text('Límite poniente'), findsOneWidget);
  });

  testWidgets('la linea crece tramo a tramo junto con cada punto', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel);

    // A los 550 ms solo se ve el primer punto: la linea aun no tiene tramos.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacidad(tester, const Key('calle-0')), greaterThan(0));
    // El tramo 4 llega al marcador de recorrido completo.
    for (var i = 1; i <= 4; i++) {
      for (final parte in _partesDelTramo(i)) {
        expect(_opacidadVisible(tester, parte), 0, reason: '$parte');
      }
    }
    // Antes del primer punto no hay linea.
    expect(find.byKey(const Key('tramo-0-cabeza')), findsNothing);

    // Con el segundo punto aparece solo el primer tramo.
    await tester.pump(const Duration(milliseconds: 500));
    for (final parte in _partesDelTramo(1)) {
      expect(_opacidadVisible(tester, parte), greaterThan(0), reason: '$parte');
    }
    for (final parte in _partesDelTramo(2)) {
      expect(_opacidadVisible(tester, parte), 0, reason: '$parte');
    }

    await tester.pumpAndSettle();
    for (var i = 1; i <= 4; i++) {
      for (final parte in _partesDelTramo(i)) {
        expect(_opacidadVisible(tester, parte), 1, reason: '$parte');
      }
    }
  });

  testWidgets('los tramos unen los centros de puntos consecutivos', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    for (var i = 1; i <= 4; i++) {
      final cola = tester.getRect(find.byKey(Key('tramo-$i-cola')));
      final cabeza = tester.getRect(find.byKey(Key('tramo-$i-cabeza')));
      final puntoAnterior = tester.getRect(find.byKey(Key('punto-${i - 1}')));
      final punto = tester.getRect(find.byKey(Key('punto-$i')));
      expect(cabeza.width, 2);
      expect(cola.width, 2);
      expect(cabeza.center.dx, moreOrLessEquals(punto.center.dx));
      expect(cola.center.dx, moreOrLessEquals(puntoAnterior.center.dx));
      // Del centro del punto anterior al centro del suyo, sin hueco entre partes.
      expect(cola.top, moreOrLessEquals(puntoAnterior.center.dy));
      expect(cabeza.top, moreOrLessEquals(cola.bottom));
      expect(cabeza.bottom, moreOrLessEquals(punto.center.dy));
    }
  });

  testWidgets('con una sola calle dice 1 calle', (tester) async {
    final servicio = _servicioSanJoaquin();
    final unaCalle = ServicioRetiro(
      comunaId: servicio.comunaId,
      comunaNombre: servicio.comunaNombre,
      horario: servicio.horario,
      materiales: servicio.materiales,
      fuenteNombre: servicio.fuenteNombre,
      actualizado: servicio.actualizado,
      zonaActualId: '13129-t1',
      zonas: [_zona('13129-t1', 'Territorio 1', 'lunes', ['Santa María'])],
    );
    final viewModel = await _viewModelAbierto(ApiClientFalso(servicioRetiro: unaCalle));
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    expect(find.text('1 calle · recorrido completo'), findsOneWidget);
    expect(_opacidadVisible(tester, const Key('tramo-1-cola')), 1);
  });

  testWidgets('otro dia de la zona del usuario tambien dice tu casa', (tester) async {
    final servicio = _servicioSanJoaquin();
    final dosDias = ServicioRetiro(
      comunaId: servicio.comunaId,
      comunaNombre: servicio.comunaNombre,
      horario: servicio.horario,
      materiales: servicio.materiales,
      fuenteNombre: servicio.fuenteNombre,
      actualizado: servicio.actualizado,
      zonaActualId: 'casa',
      zonas: [
        _zona('otra', 'Otra zona', 'jueves', ['Santa María']),
        ZonaRetiro(
          id: 'casa',
          nombre: 'Mi zona',
          dias: const ['martes', 'jueves'],
          calles: _calles(['Departamental']),
          poligonos: const [],
        ),
      ],
    );
    final viewModel = await _viewModelAbierto(ApiClientFalso(servicioRetiro: dosDias));
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chip-dia-jueves')));
    await tester.pumpAndSettle();
    expect(find.text('El camión pasa por tu casa los'), findsOneWidget);
    expect(find.text('San Joaquín · Mi zona'), findsOneWidget);
  });

  testWidgets('seis dias caben en una sola fila en un telefono', (tester) async {
    final base = _servicioSanJoaquin();
    final servicio = ServicioRetiro(
      comunaId: base.comunaId,
      comunaNombre: base.comunaNombre,
      horario: base.horario,
      materiales: base.materiales,
      fuenteNombre: base.fuenteNombre,
      actualizado: base.actualizado,
      zonaActualId: base.zonaActualId,
      zonas: [
        ...base.zonas,
        _zona('13129-sab', 'Sábado', 'sábado', ['Santa Rosa', 'Lo Ovalle', 'Departamental']),
      ],
    );
    final viewModel = await _viewModelAbierto(ApiClientFalso(servicioRetiro: servicio));
    await _montar(tester, viewModel, tamano: const Size(360, 800));
    await tester.pumpAndSettle();

    final fila = tester.getTopLeft(find.byKey(const Key('chip-dia-lunes'))).dy;
    for (final dia in ['martes', 'miércoles', 'jueves', 'viernes', 'sábado']) {
      expect(tester.getTopLeft(find.byKey(Key('chip-dia-$dia'))).dy, fila, reason: dia);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada punto lleva el numero de su calle', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      expect(
        find.descendant(of: find.byKey(Key('punto-$i')), matching: find.text('${i + 1}')),
        findsOneWidget,
        reason: 'punto-$i',
      );
      expect(tester.getSize(find.byKey(Key('punto-$i'))), const Size(24, 24));
    }
  });

  testWidgets('la tarjeta del dia usa el horario de la zona si lo trae', (tester) async {
    final base = _servicioSanJoaquin();
    const horarioSabado = 'Entre 8:30 y 12:30 (aprox.)';
    final servicio = ServicioRetiro(
      comunaId: base.comunaId,
      comunaNombre: base.comunaNombre,
      horario: base.horario,
      materiales: base.materiales,
      fuenteNombre: base.fuenteNombre,
      actualizado: base.actualizado,
      zonaActualId: base.zonaActualId,
      zonas: [
        ...base.zonas,
        ZonaRetiro(
          id: '13110-sabado',
          nombre: 'Sábado',
          dias: const ['sábado'],
          calles: _calles(['Santa Rosa']),
          poligonos: const [],
          horario: horarioSabado,
        ),
      ],
    );
    final viewModel = await _viewModelAbierto(ApiClientFalso(servicioRetiro: servicio));
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    expect(find.text('Saca tu reciclaje desde las 8:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chip-dia-sábado')));
    await tester.pumpAndSettle();
    expect(find.text(horarioSabado), findsOneWidget);
    expect(find.text('Saca tu reciclaje desde las 8:00'), findsNothing);
  });

  testWidgets('tocar otro dia cambia texto y calles', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chip-dia-lunes')));
    // Al cambiar de dia la secuencia vuelve a empezar desde cero.
    await tester.pump();
    expect(_opacidad(tester, const Key('calle-0')), 0);

    await tester.pumpAndSettle();
    expect(viewModel.diaSeleccionado, 'lunes');
    expect(find.text('En este sector pasa los'), findsOneWidget);
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('San Joaquín · Territorio 1'), findsOneWidget);
    expect(find.text('Santa María'), findsOneWidget);
    expect(_opacidad(tester, const Key('calle-3')), 1);
  });

  testWidgets('sin animaciones muestra todo de inmediato', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await _montar(tester, viewModel, sinAnimaciones: true);
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      expect(_opacidad(tester, Key('calle-$i')), 1);
    }
    expect(_opacidad(tester, const Key('camion-recorrido-completo')), 1);
  });

  testWidgets('sin servicio muestra el aviso', (tester) async {
    final viewModel = await _viewModelAbierto(ApiClientFalso());
    await _montar(tester, viewModel);
    await tester.pump();

    expect(
      find.text('Aún no tenemos el recorrido del camión de reciclaje para esta comuna.'),
      findsOneWidget,
    );
  });

  testWidgets('error muestra Reintentar y lo llama', (tester) async {
    final apiClient = ApiClientFalso(
      excepcionServicioRetiro: const ReciclaiApiException('sin red'),
    );
    final viewModel = await _viewModelAbierto(apiClient);
    await _montar(tester, viewModel);
    await tester.pump();

    expect(find.text('No pudimos cargar el recorrido.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(apiClient.vecesLlamadoObtenerServicioRetiro, 2);
  });

  testWidgets('cargando muestra un indicador de progreso', (tester) async {
    final viewModel = CamionReciclajeViewModel(apiClient: ApiClientFalso());
    await _montar(tester, viewModel);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'mostrarHojaCamionReciclaje abre la hoja con alto maximo de 0.62 de la pantalla',
    (tester) async {
      final viewModel = await _viewModelAbierto(
        ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => mostrarHojaCamionReciclaje(context, viewModel),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hoja-camion')), findsOneWidget);
      final altoPantalla = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getSize(find.byKey(const Key('hoja-camion'))).height,
        lessThanOrEqualTo(altoPantalla * fraccionAlturaHojaCamion),
      );
      expect(fraccionAlturaHojaCamion, 0.62);
    },
  );

  testWidgets('mostrarHojaCamionReciclaje no oscurece el mapa de fondo', (tester) async {
    final viewModel = await _viewModelAbierto(
      ApiClientFalso(servicioRetiro: _servicioSanJoaquin()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostrarHojaCamionReciclaje(context, viewModel),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hoja-camion')), findsOneWidget);
    // Toda barrera modal (la de la hoja incluida) queda sin color o transparente.
    final barreras = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(barreras, isNotEmpty);
    for (final barrera in barreras) {
      expect(barrera.color == null || barrera.color!.a == 0, isTrue, reason: '${barrera.color}');
    }
  });
}
