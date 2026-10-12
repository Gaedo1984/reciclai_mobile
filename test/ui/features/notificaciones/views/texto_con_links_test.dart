import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/texto_con_links.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

List<TextSpan> _hijos(WidgetTester tester) {
  final richText = tester.widget<RichText>(find.byType(RichText).first);
  // Text.rich(span) construye un RichText cuyo `.text` es un TextSpan
  // ENVOLTORIO nuevo (le aplica el estilo por defecto), con nuestro propio
  // TextSpan como unico hijo -- no es nuestro TextSpan directamente.
  final envoltura = richText.text as TextSpan;
  final raiz = envoltura.children!.single as TextSpan;
  return (raiz.children ?? []).cast<TextSpan>();
}

void main() {
  testWidgets('texto sin links se muestra como un solo TextSpan plano', (tester) async {
    await tester.pumpWidget(_envolver(const TextoConLinks(texto: 'Hola mundo')));

    final hijos = _hijos(tester);
    expect(hijos, hasLength(1));
    expect(hijos.first.text, 'Hola mundo');
    expect(hijos.first.recognizer, isNull);
  });

  testWidgets('un link muestra el texto visible subrayado y tocable', (tester) async {
    await tester.pumpWidget(
      _envolver(const TextoConLinks(texto: 'hola [aquí](https://reciclai.cl) mundo')),
    );

    final hijos = _hijos(tester);
    expect(hijos.map((s) => s.text), ['hola ', 'aquí', ' mundo']);
    expect(hijos[0].recognizer, isNull);
    expect(hijos[1].recognizer, isA<TapGestureRecognizer>());
    expect(hijos[1].style?.decoration, TextDecoration.underline);
    expect(hijos[2].recognizer, isNull);
  });

  testWidgets('dos links separa los cinco segmentos correctos', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const TextoConLinks(texto: 'ver [uno](https://a.cl) y [dos](https://b.cl) ya'),
      ),
    );

    final hijos = _hijos(tester);
    expect(hijos.map((s) => s.text), ['ver ', 'uno', ' y ', 'dos', ' ya']);
    expect(hijos[1].recognizer, isNotNull);
    expect(hijos[3].recognizer, isNotNull);
  });

  testWidgets('tocar el link llama a launchUrl con el url correcto', (tester) async {
    final urlLauncherFalso = UrlLauncherPlatformFalso();
    UrlLauncherPlatform.instance = urlLauncherFalso;
    await tester.pumpWidget(
      _envolver(const TextoConLinks(texto: 'ir [aquí](https://reciclai.cl/aviso)')),
    );

    final link = _hijos(tester)[1];
    (link.recognizer as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(urlLauncherFalso.urlsLanzadas, ['https://reciclai.cl/aviso']);
  });

  testWidgets(
      'un link malformado se muestra literal, con los corchetes, sin intentar abrir nada '
      '(Review Focus)', (tester) async {
    await tester.pumpWidget(
      _envolver(const TextoConLinks(texto: 'ver [texto](no-es-url) aca')),
    );

    final hijos = _hijos(tester);
    expect(hijos, hasLength(1));
    expect(hijos.first.text, 'ver [texto](no-es-url) aca');
    expect(hijos.first.recognizer, isNull);
  });
}
