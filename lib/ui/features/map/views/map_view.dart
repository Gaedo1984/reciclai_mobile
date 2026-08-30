import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../../../data/models/recycling_point.dart';
import '../view_models/map_state.dart';
import '../view_models/map_view_model.dart';
import 'comuna_selector.dart';
import 'map_attribution.dart';
import 'point_details_sheet.dart';

const _centroSantiago = LatLng(-33.45, -70.65);
const _zoomPorDefecto = 12.0;
const _zoomSinPuntos = 13.0;
const _zoomConPuntos = 15.0;
const _estiloMapaUrl = 'https://tiles.openfreemap.org/styles/liberty';

(LatLng, double) _centroYZoom(List<RecyclingPoint> puntos, LatLng? centroComuna) {
  if (puntos.isNotEmpty) {
    final lat = puntos.map((p) => p.ubicacion.latitude).reduce((a, b) => a + b) / puntos.length;
    final lng = puntos.map((p) => p.ubicacion.longitude).reduce((a, b) => a + b) / puntos.length;
    return (LatLng(lat, lng), _zoomConPuntos);
  }
  if (centroComuna != null) {
    return (centroComuna, _zoomSinPuntos);
  }
  return (_centroSantiago, _zoomPorDefecto);
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
          return Column(
            children: [
              ComunaSelector(
                comunas: widget.viewModel.comunas,
                comunaSeleccionadaId: widget.viewModel.comunaSeleccionadaId,
                onElegirComuna: widget.viewModel.seleccionarComuna,
              ),
              Expanded(
                child: switch (widget.viewModel.cuerpo) {
                  Cargando() => const Center(child: CircularProgressIndicator()),
                  ConDatos(:final puntos) => _MapaConPuntos(
                      puntos: puntos,
                      centroComuna: widget.viewModel.centroComunaSeleccionada,
                      onTocarPunto: _mostrarDetalle,
                    ),
                  SinSeleccion(:final mensaje) => _EstadoSinSeleccion(mensaje: mensaje),
                  ErrorAlCargar(:final mensaje) => _EstadoError(
                      mensaje: mensaje,
                      onReintentar: widget.viewModel.reintentar,
                    ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDetalle(RecyclingPoint punto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PointDetailsSheet(
        punto: punto,
        nombresDeMateriales: widget.viewModel.nombresDeMateriales,
      ),
    );
  }
}

class _MapaConPuntos extends StatefulWidget {
  const _MapaConPuntos({required this.puntos, required this.centroComuna, required this.onTocarPunto});

  final List<RecyclingPoint> puntos;
  final LatLng? centroComuna;
  final void Function(RecyclingPoint) onTocarPunto;

  @override
  State<_MapaConPuntos> createState() => _MapaConPuntosState();
}

class _MapaConPuntosState extends State<_MapaConPuntos> {
  final _controller = MapController();
  late final Future<vt.Style> _estiloFuturo;

  @override
  void initState() {
    super.initState();
    _estiloFuturo = const vt.StyleReader(uri: _estiloMapaUrl).read();
  }

  @override
  void didUpdateWidget(_MapaConPuntos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.puntos != widget.puntos || oldWidget.centroComuna != widget.centroComuna) {
      final (centro, zoom) = _centroYZoom(widget.puntos, widget.centroComuna);
      _controller.move(centro, zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _estiloFuturo.then((estilo) => estilo.dispose()).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (centro, zoom) = _centroYZoom(widget.puntos, widget.centroComuna);
    return FutureBuilder<vt.Style>(
      future: _estiloFuturo,
      builder: (context, snapshot) {
        final estilo = snapshot.data;
        return FlutterMap(
          mapController: _controller,
          options: MapOptions(initialCenter: centro, initialZoom: zoom),
          children: [
            if (estilo != null)
              vt.VectorTileLayer(
                theme: estilo.theme,
                tileProviders: estilo.providers,
                rasterSources: estilo.rasterSources,
                sprites: estilo.sprites,
              ),
            MarkerLayer(
              markers: [
                for (final punto in widget.puntos)
                  Marker(
                    point: punto.ubicacion,
                    child: GestureDetector(
                      onTap: () => widget.onTocarPunto(punto),
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                    ),
                  ),
              ],
            ),
            if (estilo != null) MapAttribution(atribuciones: estilo.attributions),
          ],
        );
      },
    );
  }
}

class _EstadoSinSeleccion extends StatelessWidget {
  const _EstadoSinSeleccion({this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            if (mensaje != null) ...[
              Text(mensaje!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
            ],
            Text(
              'Elige tu comuna arriba para ver los puntos de reciclaje.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
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
