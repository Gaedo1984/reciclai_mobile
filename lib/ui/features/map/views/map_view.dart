import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/recycling_point.dart';
import '../view_models/map_state.dart';
import '../view_models/map_view_model.dart';
import 'comuna_picker_sheet.dart';
import 'point_details_sheet.dart';

const _centroSantiago = LatLng(-33.45, -70.65);
const _zoomPorDefecto = 12.0;
const _zoomConPuntos = 15.0;

(LatLng, double) _centroYZoom(List<RecyclingPoint> puntos) {
  if (puntos.isEmpty) {
    return (_centroSantiago, _zoomPorDefecto);
  }
  final lat = puntos.map((p) => p.ubicacion.latitude).reduce((a, b) => a + b) / puntos.length;
  final lng = puntos.map((p) => p.ubicacion.longitude).reduce((a, b) => a + b) / puntos.length;
  return (LatLng(lat, lng), _zoomConPuntos);
}

class MapView extends StatefulWidget {
  const MapView({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.iniciar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ReciclAI')),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          return switch (widget.viewModel.state) {
            Cargando() => const Center(child: CircularProgressIndicator()),
            ConDatos(:final puntos) => _MapaConPuntos(puntos: puntos, onTocarPunto: _mostrarDetalle),
            RequierePicker(:final comunasDisponibles, :final mensaje) => ComunaPickerSheet(
                comunas: comunasDisponibles,
                mensaje: mensaje,
                onElegirComuna: widget.viewModel.seleccionarComuna,
              ),
            ErrorAlCargar(:final mensaje) => _EstadoError(
                mensaje: mensaje,
                onReintentar: widget.viewModel.reintentar,
              ),
          };
        },
      ),
    );
  }

  void _mostrarDetalle(RecyclingPoint punto) {
    showModalBottomSheet(
      context: context,
      builder: (_) => PointDetailsSheet(punto: punto),
    );
  }
}

class _MapaConPuntos extends StatefulWidget {
  const _MapaConPuntos({required this.puntos, required this.onTocarPunto});

  final List<RecyclingPoint> puntos;
  final void Function(RecyclingPoint) onTocarPunto;

  @override
  State<_MapaConPuntos> createState() => _MapaConPuntosState();
}

class _MapaConPuntosState extends State<_MapaConPuntos> {
  final _controller = MapController();

  @override
  void didUpdateWidget(_MapaConPuntos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.puntos != widget.puntos) {
      final (centro, zoom) = _centroYZoom(widget.puntos);
      _controller.move(centro, zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (centro, zoom) = _centroYZoom(widget.puntos);
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(initialCenter: centro, initialZoom: zoom),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gustavoaedo.reciclai_mobile',
        ),
        MarkerLayer(
          markers: [
            for (final punto in widget.puntos)
              Marker(
                point: punto.ubicacion,
                child: GestureDetector(
                  onTap: () => widget.onTocarPunto(punto),
                  child: const Icon(Icons.location_on, color: Colors.deepPurple, size: 36),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
