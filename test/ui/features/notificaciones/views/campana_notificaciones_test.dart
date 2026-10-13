import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';
import 'package:reciclai_mobile/ui/core/spacing.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/campana_notificaciones.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/detalle_notificacion_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fakes.dart';

// La campana calcula su posicion de anclaje relativa a si misma -- hay que
// montarla en un AppBar (como en produccion, ver map_view.dart) para que
// termine donde el widget espera estar (arriba a la derecha), no pegada a
// la esquina superior izquierda de un Scaffold.body sin AppBar.
Widget _envolver(Widget child, {GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(
      navigatorKey: navigatorKey,
      home: Scaffold(
        appBar: AppBar(actions: [child]),
        body: const SizedBox(),
      ),
    );

Notificacion _n(String id, {String titulo = 'Aviso'}) => Notificacion(
  id: id,
  titulo: titulo,
  texto: 'Cuerpo',
  creadaEn: DateTime(2026, 10, 12),
);

Future<NotificacionesViewModel> _viewModelCargado(
  List<Notificacion> notificaciones,
) async {
  SharedPreferences.setMockInitialValues({});
  final viewModel = NotificacionesViewModel(
    apiClient: ApiClientFalso(notificaciones: notificaciones),
  );
  await viewModel.cargar();
  return viewModel;
}

void main() {
  testWidgets('sin notificaciones no leidas, el punto rojo no se muestra', (
    tester,
  ) async {
    final viewModel = await _viewModelCargado([]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('con al menos una no leida, el punto rojo se muestra', (
    tester,
  ) async {
    final viewModel = await _viewModelCargado([_n('n1')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('tocar la campana abre la hoja con las notificaciones', (
    tester,
  ) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Primera')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Primera'), findsOneWidget);
    expect(find.text('12 oct.'), findsOneWidget);
  });

  testWidgets(
    'con mas de 5 notificaciones aparece "Mostrar todas"; al tocarlo, se ven todas',
    (tester) async {
      final notificaciones = [
        for (var i = 0; i < 6; i++) _n('n$i', titulo: 'Aviso $i'),
      ];
      final viewModel = await _viewModelCargado(notificaciones);
      await tester.pumpWidget(
        _envolver(CampanaNotificaciones(viewModel: viewModel)),
      );
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Aviso 5'), findsNothing);
      expect(find.text('Mostrar todas'), findsOneWidget);

      await tester.tap(find.text('Mostrar todas'));
      await tester.pumpAndSettle();

      expect(find.text('Aviso 5'), findsOneWidget);
    },
  );

  testWidgets(
    'con exactamente 5 notificaciones, "Mostrar todas" no aparece (Review Focus)',
    (tester) async {
      final notificaciones = [
        for (var i = 0; i < 5; i++) _n('n$i', titulo: 'Aviso $i'),
      ];
      final viewModel = await _viewModelCargado(notificaciones);
      await tester.pumpWidget(
        _envolver(CampanaNotificaciones(viewModel: viewModel)),
      );
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Aviso 4'), findsOneWidget);
      expect(find.text('Mostrar todas'), findsNothing);
    },
  );

  testWidgets('una notificacion no leida se ve en negrita con un punto; una leida, sin ninguno de los '
      'dos', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'No leida')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    final titulo = tester.widget<Text>(find.text('No leida'));
    expect(titulo.style?.fontWeight, FontWeight.bold);
    expect(find.byIcon(Icons.circle), findsOneWidget);

    await viewModel.marcarLeida('n1');
    await tester.pump();

    final tituloLeido = tester.widget<Text>(find.text('No leida'));
    expect(tituloLeido.style?.fontWeight, FontWeight.normal);
    expect(find.byIcon(Icons.circle), findsNothing);
  });

  testWidgets(
    'tocar una notificacion abre el modal y la marca como leida sin cerrar la hoja',
    (tester) async {
      final viewModel = await _viewModelCargado([_n('n1', titulo: 'Tocame')]);
      await tester.pumpWidget(
        _envolver(CampanaNotificaciones(viewModel: viewModel)),
      );
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tocame'));
      await tester.pumpAndSettle();

      // El modal de detalle (titulo en grande) y la fila de la hoja (ahora
      // leida, sin negrita) coexisten en el arbol -- el modal se dibuja
      // encima, pero la hoja sigue montada debajo. Se afirma directo que
      // el widget del modal esta montado (Minor diferido: antes solo se
      // afirmaba find.text, que ya lo satisfacia la fila de la hoja sola
      // -- borrar el showDialog hubiera dejado este test en verde igual).
      expect(find.byType(DetalleNotificacionModal), findsOneWidget);
      expect(find.text('Tocame'), findsAtLeastNWidgets(1));
      expect(viewModel.estaLeida('n1'), isTrue);
    },
  );

  testWidgets(
    'la X del modal lo cierra directo, sin tener que cerrar la hoja primero (bug reportado)',
    (tester) async {
      final viewModel = await _viewModelCargado([_n('n1', titulo: 'Tocame')]);
      await tester.pumpWidget(
        _envolver(CampanaNotificaciones(viewModel: viewModel)),
      );
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tocame'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleNotificacionModal), findsOneWidget);

      // Hay dos iconos de cerrar en pantalla a la vez (hoja + modal) --
      // hay que tocar especificamente el del modal.
      await tester.tap(
        find.descendant(
          of: find.byType(DetalleNotificacionModal),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      // El modal se cerro, pero la hoja sigue abierta debajo (no se cerro
      // junto con el).
      expect(find.byType(DetalleNotificacionModal), findsNothing);
      expect(find.text('Tocame'), findsOneWidget);
    },
  );

  testWidgets('la hoja no se cierra con el boton atras del sistema', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Persiste')]);
    await tester.pumpWidget(
      _envolver(
        CampanaNotificaciones(viewModel: viewModel),
        navigatorKey: navigatorKey,
      ),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await navigatorKey.currentState!.maybePop();
    // pumpAndSettle, no un solo pump -- con un solo pump la ruta ya empezo
    // a cerrarse (si PopScope no la hubiera bloqueado) pero su animacion de
    // salida seguiria corriendo, y el contenido seguiria encontrandose un
    // frame despues de todos modos. Hay que esperar a que la animacion
    // termine para que el assert distinga "se cerro" de "sigue abierta".
    await tester.pumpAndSettle();

    expect(find.text('Persiste'), findsOneWidget);
  });

  testWidgets('la X cierra la hoja', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Cerrable')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Cerrable'), findsNothing);
  });

  testWidgets(
    'sin notificaciones, la hoja muestra un mensaje en vez de quedar vacia '
    '(Important, revision final)',
    (tester) async {
      final viewModel = await _viewModelCargado([]);
      await tester.pumpWidget(
        _envolver(CampanaNotificaciones(viewModel: viewModel)),
      );

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('No hay notificaciones'), findsOneWidget);
    },
  );

  testWidgets('tocar afuera de la hoja no la cierra (Minor diferido)', (
    tester,
  ) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Firme')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    // Un punto cerca de la esquina superior izquierda, fuera de la
    // tarjeta de la hoja (que esta flotante, con margen) pero dentro del
    // scrim que showModalBottomSheet pone detras.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Firme'), findsOneWidget);
  });

  testWidgets('tocar afuera del modal no lo cierra (Minor diferido)', (
    tester,
  ) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Firme')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firme'));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleNotificacionModal), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(DetalleNotificacionModal), findsOneWidget);
  });

  testWidgets('tras leer todas las notificaciones visibles, el punto rojo de la campana desaparece '
      '(Minor diferido)', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Unica')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unica'));
    await tester.pumpAndSettle();

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('el punto rojo queda pegado al icono de la campana, no al area de toque completa '
      '(Minor diferido)', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.child, isA<Icon>());
  });

  testWidgets(
    'el panel abarca todo el ancho de la pantalla, pegado debajo del AppBar sin superponerse',
    (tester) async {
      final viewModel = await _viewModelCargado([_n('n1', titulo: 'Aviso')]);
      await tester.pumpWidget(
        _envolver(CampanaNotificaciones(viewModel: viewModel)),
      );
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      final tamanoPantalla =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final panel = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Notificaciones'),
              matching: find.byType(Material),
            )
            .first,
      );
      final rect = tester.getRect(find.byWidget(panel));

      expect(rect.width, tamanoPantalla.width);
      // Pegado justo debajo del AppBar (64px, sin safe-area en el test) --
      // no debe arrancar en 0 (eso seria superpuesto con el header).
      expect(rect.top, alturaAppBar);
    },
  );

  testWidgets('la fecha y el titulo viven en columnas separadas -- un titulo largo no puede tocar la '
      'fecha', (tester) async {
    final tituloLargo = List.generate(30, (i) => 'palabra$i').join(' ');
    final viewModel = await _viewModelCargado([_n('n1', titulo: tituloLargo)]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel)),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    final fecha = tester.getTopRight(find.text('12 oct.'));
    final titulo = tester.getTopLeft(find.text(tituloLargo));

    expect(titulo.dx, greaterThan(fecha.dx));
  });
}
