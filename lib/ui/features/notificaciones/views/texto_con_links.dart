import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Excluye '[' y ']' de la url ademas de espacios y ')' -- sin esto, un
// cuerpo con un '[' dentro de la url (ej. un error de tipeo al escribir
// la notificacion) produce una url invalida que Uri.parse rechaza al
// tocar el link (ver guardia en _abrir más abajo, que ademas cubre
// cualquier otro fallo de Uri.parse/launchUrl, no solo este caso).
final _regexLinks = RegExp(r'\[([^\]]+)\]\((https?://[^\s)\[\]]+)\)');

/// Links estilo Markdown (`[texto](url)`) dentro del cuerpo de una
/// notificación -- quien escribe la notificación (vía el POST desde
/// GitHub Actions) no necesita pegar el URL completo, que muchas veces es
/// largo. Un patrón que no matchea el regex (ej. sin `http://`/`https://`)
/// se muestra literal, con los corchetes -- el regex en si ya es la
/// validación, no hace falta un manejo de error aparte.
class TextoConLinks extends StatefulWidget {
  const TextoConLinks({super.key, required this.texto});

  final String texto;

  @override
  State<TextoConLinks> createState() => _TextoConLinksState();
}

class _TextoConLinksState extends State<TextoConLinks> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _abrir(String url) {
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Uri.parse puede lanzar FormatException con una url malformada, y
      // launchUrl puede lanzar su propia excepcion de plataforma -- ninguna
      // de las dos debe tumbar el gesto del usuario (Minor diferido).
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final colores = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var ultimoIndice = 0;
    for (final match in _regexLinks.allMatches(widget.texto)) {
      if (match.start > ultimoIndice) {
        spans.add(
          TextSpan(text: widget.texto.substring(ultimoIndice, match.start)),
        );
      }
      final textoVisible = match.group(1)!;
      final url = match.group(2)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _abrir(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: textoVisible,
          style: TextStyle(
            color: colores.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizer,
        ),
      );
      ultimoIndice = match.end;
    }
    if (ultimoIndice < widget.texto.length || spans.isEmpty) {
      spans.add(TextSpan(text: widget.texto.substring(ultimoIndice)));
    }
    return Text.rich(TextSpan(children: spans));
  }
}
