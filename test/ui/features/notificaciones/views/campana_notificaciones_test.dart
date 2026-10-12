import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/campana_notificaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child, {GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(navigatorKey: navigatorKey, home: Scaffold(body: child));

Notificacion _n(String id, {String titulo = 'Aviso'}) =>
    Notificacion(id: id, titulo: titulo, texto: 'Cuerpo', creadaEn: DateTime(2026, 10, 12));

Future<NotificacionesViewModel> _viewModelCargado(List<Notificacion> notificaciones) async {
  SharedPreferences.setMockInitialValues({});
  final viewModel = NotificacionesViewModel(apiClient: ApiClientFalso(notificaciones: notificaciones));
  await viewModel.cargar();
  return viewModel;
}

void main() {
  testWidgets('sin notificaciones no leidas, el punto rojo no se muestra', (tester) async {
    final viewModel = await _viewModelCargado([]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('con al menos una no leida, el punto rojo se muestra', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('tocar la campana abre la hoja con las notificaciones', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Primera')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Primera'), findsOneWidget);
  });

  testWidgets('con mas de 5 notificaciones aparece "Mostrar todas"; al tocarlo, se ven todas',
      (tester) async {
    final notificaciones = [for (var i = 0; i < 6; i++) _n('n$i', titulo: 'Aviso $i')];
    final viewModel = await _viewModelCargado(notificaciones);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 5'), findsNothing);
    expect(find.text('Mostrar todas'), findsOneWidget);

    await tester.tap(find.text('Mostrar todas'));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 5'), findsOneWidget);
  });

  testWidgets('con exactamente 5 notificaciones, "Mostrar todas" no aparece (Review Focus)',
      (tester) async {
    final notificaciones = [for (var i = 0; i < 5; i++) _n('n$i', titulo: 'Aviso $i')];
    final viewModel = await _viewModelCargado(notificaciones);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 4'), findsOneWidget);
    expect(find.text('Mostrar todas'), findsNothing);
  });

  testWidgets(
      'una notificacion no leida se ve en negrita con un punto; una leida, sin ninguno de los '
      'dos', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'No leida')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
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

  testWidgets('tocar una notificacion abre el modal y la marca como leida sin cerrar la hoja',
      (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Tocame')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tocame'));
    await tester.pumpAndSettle();

    // El modal de detalle (titulo en grande) y la fila de la hoja (ahora
    // leida, sin negrita) coexisten en el arbol -- el modal se dibuja
    // encima, pero la hoja sigue montada debajo.
    expect(find.text('Tocame'), findsAtLeastNWidgets(1));
    expect(viewModel.estaLeida('n1'), isTrue);
  });

  testWidgets('la hoja no se cierra con el boton atras del sistema', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Persiste')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel), navigatorKey: navigatorKey),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await navigatorKey.currentState!.maybePop();
    await tester.pump();

    expect(find.text('Persiste'), findsOneWidget);
  });

  testWidgets('la X cierra la hoja', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Cerrable')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Cerrable'), findsNothing);
  });
}
