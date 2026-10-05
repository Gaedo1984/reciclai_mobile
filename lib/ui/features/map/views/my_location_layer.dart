import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const _diametroDelPunto = 16.0;
const _diametroDelAro = 48.0;
const _azulDeUbicacion = Color(0xFF4285F4);

class MiUbicacionLayer extends StatefulWidget {
  const MiUbicacionLayer({super.key, required this.posiciones, this.posicionInicial});

  final Stream<Position> posiciones;

  /// Ultima posicion en vivo ya conocida antes de que esta capa existiera —
  /// un stream de broadcast no reproduce eventos pasados a un listener
  /// tardio, asi que sin esto el punto podia quedarse sin aparecer nunca si
  /// el dispositivo no se movia despues de montarse (bug real en
  /// produccion). Solo siembra el estado inicial; las actualizaciones en
  /// vivo siguen llegando por `posiciones`.
  final LatLng? posicionInicial;

  @override
  State<MiUbicacionLayer> createState() => _MiUbicacionLayerState();
}

class _MiUbicacionLayerState extends State<MiUbicacionLayer>
    with SingleTickerProviderStateMixin {
  late LatLng? _posicion;
  late final StreamSubscription<Position> _suscripcion;
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _posicion = widget.posicionInicial;
    _pulso = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _suscripcion = widget.posiciones.listen((posicion) {
      setState(() => _posicion = LatLng(posicion.latitude, posicion.longitude));
    });
  }

  @override
  void dispose() {
    unawaited(_suscripcion.cancel());
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posicion = _posicion;
    return MarkerLayer(
      // Ver comentario equivalente en map_view.dart: sin esto el circulo de
      // "mi ubicacion" tambien queda torcido al girar el mapa.
      rotate: true,
      markers: [
        if (posicion != null)
          Marker(
            point: posicion,
            width: _diametroDelAro,
            height: _diametroDelAro,
            child: AnimatedBuilder(
              animation: _pulso,
              builder: (context, _) => _PuntoConAro(progreso: _pulso.value),
            ),
          ),
      ],
    );
  }
}

class _PuntoConAro extends StatelessWidget {
  const _PuntoConAro({required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 1 - progreso,
          child: Container(
            width: _diametroDelAro * progreso,
            height: _diametroDelAro * progreso,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _azulDeUbicacion.withValues(alpha: 0.3),
            ),
          ),
        ),
        Container(
          width: _diametroDelPunto,
          height: _diametroDelPunto,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _azulDeUbicacion,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}
