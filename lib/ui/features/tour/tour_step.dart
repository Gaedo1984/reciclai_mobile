import 'package:flutter/widgets.dart';

/// Un paso del tour interactivo: un título, un cuerpo de texto, y opcionalmente
/// el widget real a resaltar. `anchorKey` en `null` significa una tarjeta
/// centrada sin spotlight (para explicar un concepto sin un widget puntual que
/// señalar, ej. "toca cualquier pin del mapa").
class TourStep {
  const TourStep({required this.titulo, required this.cuerpo, this.anchorKey});

  final String titulo;
  final String cuerpo;
  final GlobalKey? anchorKey;
}
