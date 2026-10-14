import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/detalle_notificacion_modal.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/texto_con_links.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

Notificacion _n({String texto = 'Cuerpo'}) => Notificacion(
  id: 'n1',
  titulo: 'Título del aviso',
  texto: texto,
  creadaEn: DateTime(2026, 10, 12),
);

void main() {
  testWidgets('muestra el titulo y el texto de la notificacion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _envolver(DetalleNotificacionModal(notificacion: _n())),
    );

    expect(find.text('Título del aviso'), findsOneWidget);
    expect(find.text('Cuerpo'), findsOneWidget);
    expect(find.text('12 oct.'), findsOneWidget);
  });

  testWidgets('muestra la hoja chica junto al titulo', (tester) async {
    await tester.pumpWidget(
      _envolver(DetalleNotificacionModal(notificacion: _n())),
    );

    expect(
      find.image(const AssetImage('assets/branding/hoja_detalle_notificacion.png')),
      findsOneWidget,
    );
  });

  testWidgets('no se cierra con el boton atras del sistema', (tester) async {
    // El modal debe estar montado como su PROPIA ruta (via showDialog), no
    // como el body de la unica ruta de la app -- maybePop() sobre la unica
    // ruta de un MaterialApp nunca hace nada, con o sin PopScope, así que
    // montarlo directo en el body no probaba nada (bug real, encontrado
    // reproduciendo el hallazgo del revisor: con PopScope quitado del
    // widget, este test seguia pasando).
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => DetalleNotificacionModal(notificacion: _n()),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Título del aviso'), findsOneWidget);

    // maybePop() en si mismo no confirma si la ruta cambio o no (delega la
    // decision al PopScope) -- lo que importa observar es el efecto real:
    // el contenido sigue en pantalla.
    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Título del aviso'), findsOneWidget);
  });

  testWidgets('la X cierra el modal', (tester) async {
    await tester.pumpWidget(
      _envolver(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => DetalleNotificacionModal(notificacion: _n()),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Título del aviso'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Título del aviso'), findsNothing);
  });

  testWidgets(
    'un cuerpo muy largo no desborda la pantalla (Important, revision final)',
    (tester) async {
      final cuerpoLargo = List.generate(400, (i) => 'palabra$i').join(' ');
      await tester.pumpWidget(
        _envolver(
          DetalleNotificacionModal(notificacion: _n(texto: cuerpoLargo)),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el texto del cuerpo soporta links estilo Markdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        DetalleNotificacionModal(
          notificacion: _n(texto: 'Ver [aquí](https://reciclai.cl)'),
        ),
      ),
    );

    // El header (titulo) tambien es un Text, que internamente tambien es
    // un RichText -- find.byType(RichText).first no distingue cual es
    // cual. Hay que acotar la busqueda al RichText QUE ESTA DENTRO de
    // TextoConLinks especificamente.
    final richText = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(TextoConLinks),
            matching: find.byType(RichText),
          )
          .first,
    );
    // Text.rich(span) envuelve nuestro TextSpan en uno extra (ver Task 3) --
    // hay que bajar un nivel mas para llegar a los spans reales.
    final envoltura = richText.text as TextSpan;
    final raiz = envoltura.children!.single as TextSpan;
    final hijos = (raiz.children ?? []).cast<TextSpan>();
    expect(hijos.any((s) => s.text == 'aquí' && s.recognizer != null), isTrue);
  });

  testWidgets(
    'un cuerpo largo muestra la barra de scroll para avisar que hay mas texto abajo',
    (tester) async {
      final cuerpoLargo = List.generate(400, (i) => 'palabra$i').join(' ');
      await tester.pumpWidget(
        _envolver(
          DetalleNotificacionModal(notificacion: _n(texto: cuerpoLargo)),
        ),
      );

      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(scrollbar.thumbVisibility, isTrue);
    },
  );
}
