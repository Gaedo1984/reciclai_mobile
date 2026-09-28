import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../tour_step.dart';

class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.pasos, required this.onCerrar});

  final List<TourStep> pasos;
  final VoidCallback onCerrar;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  late int _indice;

  @override
  void initState() {
    super.initState();
    _indice = _primerIndiceMontado();
  }

  bool _montado(int indice) {
    final key = widget.pasos[indice].anchorKey;
    return key == null || key.currentContext != null;
  }

  int _primerIndiceMontado() {
    for (var i = 0; i < widget.pasos.length; i++) {
      if (_montado(i)) return i;
    }
    return widget.pasos.length;
  }

  void _siguiente() {
    var candidato = _indice + 1;
    while (candidato < widget.pasos.length && !_montado(candidato)) {
      candidato++;
    }
    if (candidato >= widget.pasos.length) {
      widget.onCerrar();
    } else {
      setState(() => _indice = candidato);
    }
  }

  void _atras() {
    var candidato = _indice - 1;
    while (candidato > 0 && !_montado(candidato)) {
      candidato--;
    }
    if (candidato < 0) return;
    setState(() => _indice = candidato);
  }

  @override
  Widget build(BuildContext context) {
    if (_indice >= widget.pasos.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCerrar());
      return const SizedBox.shrink();
    }

    final paso = widget.pasos[_indice];
    final esUltimo = _indice == widget.pasos.length - 1;
    final rect = _rectDelAncla(paso.anchorKey);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(painter: _RecortePainter(rect), child: const SizedBox.expand()),
          ),
        ),
        _tarjeta(context, paso, rect, esUltimo),
      ],
    );
  }

  Rect? _rectDelAncla(GlobalKey? key) {
    if (key == null) return null;
    final contexto = key.currentContext;
    if (contexto == null) return null;
    final renderBox = contexto.findRenderObject() as RenderBox;
    final posicion = renderBox.localToGlobal(Offset.zero);
    return posicion & renderBox.size;
  }

  Widget _tarjeta(BuildContext context, TourStep paso, Rect? rect, bool esUltimo) {
    final esquema = Theme.of(context).colorScheme;
    final tarjeta = Material(
      color: esquema.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radioDeHojaFlotante),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(espacioMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(paso.titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: espacioSm),
            Text(paso.cuerpo),
            const SizedBox(height: espacioMd),
            Row(
              children: [
                TextButton(
                  key: const Key('tour-saltar'),
                  onPressed: widget.onCerrar,
                  child: const Text('Saltar'),
                ),
                const Spacer(),
                if (_indice > 0) ...[
                  TextButton(
                    key: const Key('tour-atras'),
                    onPressed: _atras,
                    child: const Text('Atrás'),
                  ),
                  const SizedBox(width: espacioSm),
                ],
                FilledButton(
                  key: const Key('tour-siguiente'),
                  onPressed: _siguiente,
                  child: Text(esUltimo ? 'Listo' : 'Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (rect == null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(espacioLg), child: tarjeta),
      );
    }

    final pantalla = MediaQuery.of(context).size;
    final espacioAbajo = pantalla.height - rect.bottom;
    final vaArriba = espacioAbajo < rect.top;
    return Positioned(
      left: espacioMd,
      right: espacioMd,
      top: vaArriba ? null : rect.bottom + espacioMd,
      bottom: vaArriba ? (pantalla.height - rect.top) + espacioMd : null,
      child: tarjeta,
    );
  }
}

class _RecortePainter extends CustomPainter {
  const _RecortePainter(this.hueco);

  final Rect? hueco;

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final recorte = hueco == null
        ? fondo
        : Path.combine(
            PathOperation.difference,
            fondo,
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(hueco!.inflate(espacioXs), const Radius.circular(espacioSm)),
              ),
          );
    canvas.drawPath(recorte, Paint()..color = Colors.black54);
  }

  @override
  bool shouldRepaint(covariant _RecortePainter oldDelegate) => oldDelegate.hueco != hueco;
}
