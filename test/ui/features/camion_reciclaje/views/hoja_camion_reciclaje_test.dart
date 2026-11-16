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
}) async {
  // Alto suficiente para que la hoja (0.62 de la pantalla) muestre todo.
  tester.view.physicalSize = const Size(800, 1600);
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

void main() {
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
}
