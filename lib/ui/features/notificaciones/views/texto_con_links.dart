import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _regexLinks = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)');

/// Links estilo Markdown (`[texto](url)`) dentro del cuerpo de una
/// notificación -- quien escribe la notificación (vía el POST desde
/// GitHub Actions) no necesita pegar el URL completo, que muchas veces es
/// largo. Un patrón que no matchea el regex (ej. sin `http://`/`https://`)
/// se muestra literal, con los corchetes -- el regex en si ya es la
/// validación, no hace falta un manejo de error aparte.
class TextoConLinks extends StatelessWidget {
  const TextoConLinks({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var ultimoIndice = 0;
    for (final match in _regexLinks.allMatches(texto)) {
      if (match.start > ultimoIndice) {
        spans.add(TextSpan(text: texto.substring(ultimoIndice, match.start)));
      }
      final textoVisible = match.group(1)!;
      final url = match.group(2)!;
      spans.add(
        TextSpan(
          text: textoVisible,
          style: TextStyle(color: colores.primary, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      );
      ultimoIndice = match.end;
    }
    if (ultimoIndice < texto.length || spans.isEmpty) {
      spans.add(TextSpan(text: texto.substring(ultimoIndice)));
    }
    return Text.rich(TextSpan(children: spans));
  }
}
