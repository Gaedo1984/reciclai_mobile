import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.atribuciones});

  final List<vt.StyleAttribution> atribuciones;

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      showFlutterMapAttribution: false,
      attributions: [
        for (final atribucion in atribuciones)
          TextSourceAttribution(atribucion.text, prependCopyright: false),
      ],
    );
  }
}
