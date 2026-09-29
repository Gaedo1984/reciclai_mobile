import 'package:flutter/widgets.dart';

/// Un paso del tour interactivo: un título, un cuerpo de texto, y opcionalmente
/// el widget real a resaltar. `anchorKey` en `null` significa una tarjeta
/// centrada sin spotlight (para explicar un concepto sin un widget puntual que
/// señalar, ej. "toca cualquier pin del mapa").
class TourStep {
  const TourStep({required this.titulo, required this.cuerpo, this.anchorKey, this.imagenAsset});

  final String titulo;
  final String cuerpo;
  final GlobalKey? anchorKey;

  /// Imagen opcional a mostrar entre el titulo y el cuerpo (ej. el icono real
  /// de un pin, para el paso que explica el mapa sin resaltar un widget
  /// puntual). `null` = sin imagen.
  final String? imagenAsset;
}
