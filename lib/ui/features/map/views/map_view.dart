import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/recycling_point.dart';
import '../../../../domain/filtro_material.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/glass_bar.dart';
import '../../../core/spacing.dart';
import '../view_models/map_state.dart';
import '../view_models/map_view_model.dart';
import 'comuna_selector.dart';
import 'map_attribution.dart';
import 'material_filter_button.dart';
import 'my_location_layer.dart';
import 'point_details_sheet.dart';

const _centroSantiago = LatLng(-33.45, -70.65);
const _zoomPorDefecto = 12.0;
const _zoomSinPuntos = 13.0;
const _zoomConPuntos = 15.0;
const _estiloMapaUrl = 'https://tiles.openfreemap.org/styles/liberty';

(LatLng, double) _centroYZoom(List<RecyclingPoint> puntos, LatLng? centroComuna, LatLng? miUbicacion) {
  if (miUbicacion != null) {
    return (miUbicacion, _zoomConPuntos);
  }
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
  const MapView({super.key, required this.viewModel, this.iniciarAlMontar = true});

  final MapViewModel viewModel;

  /// En `false` cuando quien construye este widget ya llamó `viewModel.iniciar()`
  /// por su cuenta (por ejemplo, la pantalla de intro) — evita recargar todo de
  /// nuevo apenas se llega al mapa.
  final bool iniciarAlMontar;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  @override
  void initState() {
    super.initState();
    if (widget.iniciarAlMontar) widget.viewModel.iniciar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 64,
        title: Image.asset(
          'assets/branding/logo_horizontal.png',
          height: 44,
          fit: BoxFit.contain,
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (widget.viewModel.cuerpo) {
                    Cargando() => const Center(child: CircularProgressIndicator()),
                    ConDatos(:final puntos) => _MapaConPuntos(
                        puntos: filtrarPorMateriales(puntos, widget.viewModel.materialesSeleccionados),
                        centroComuna: widget.viewModel.centroComunaSeleccionada,
                        miUbicacion: widget.viewModel.miUbicacion,
                        onTocarPunto: _mostrarDetalle,
                        mostrarMiUbicacion: widget.viewModel.tienePermisoDeUbicacion,
                        posicionEnVivo: widget.viewModel.posicionEnVivo,
                      ),
                    SinSeleccion(:final mensaje) => _EstadoSinSeleccion(mensaje: mensaje),
                    ErrorAlCargar(:final mensaje) => _EstadoError(
                        mensaje: mensaje,
                        onReintentar: widget.viewModel.reintentar,
                      ),
                    FueraDeRango() => _MapaConPuntos(
                        puntos: const [],
                        centroComuna: null,
                        miUbicacion: widget.viewModel.miUbicacion,
                        onTocarPunto: _mostrarDetalle,
                        mostrarMiUbicacion: widget.viewModel.tienePermisoDeUbicacion,
                        posicionEnVivo: widget.viewModel.posicionEnVivo,
                      ),
                  },
                ),
              ),
              Positioned(
                left: espacioMd,
                right: espacioMd,
                bottom: espacioLg + MediaQuery.of(context).padding.bottom,
                child: Center(
                  child: widget.viewModel.cuerpo is FueraDeRango
                      ? const _AvisoFueraDeRango()
                      : GlassBar(
                          children: [
                            ComunaSelector(
                              comunas: widget.viewModel.comunas,
                              onElegirComuna: widget.viewModel.seleccionarComuna,
                            ),
                            MaterialFilterButton(viewModel: widget.viewModel),
                          ],
                        ),
                ),
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
  const _MapaConPuntos({
    required this.puntos,
    required this.centroComuna,
    required this.miUbicacion,
    required this.onTocarPunto,
    required this.mostrarMiUbicacion,
    required this.posicionEnVivo,
  });

  final List<RecyclingPoint> puntos;
  final LatLng? centroComuna;
  final LatLng? miUbicacion;
  final void Function(RecyclingPoint) onTocarPunto;
  final bool mostrarMiUbicacion;
  final Stream<Position> posicionEnVivo;

  @override
  State<_MapaConPuntos> createState() => _MapaConPuntosState();
}

class _MapaConPuntosState extends State<_MapaConPuntos> {
  final _controller = MapController();
  late final Future<vt.Style> _estiloFuturo;
  late final StreamSubscription<Position> _suscripcionUbicacion;
  LatLng? _miUbicacionEnVivo;

  @override
  void initState() {
    super.initState();
    _estiloFuturo = const vt.StyleReader(uri: _estiloMapaUrl).read();
    _suscripcionUbicacion = widget.posicionEnVivo.listen((posicion) {
      if (!mounted) return;
      setState(() => _miUbicacionEnVivo = LatLng(posicion.latitude, posicion.longitude));
    });
  }

  @override
  void didUpdateWidget(_MapaConPuntos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.puntos != widget.puntos ||
        oldWidget.centroComuna != widget.centroComuna ||
        oldWidget.miUbicacion != widget.miUbicacion) {
      final (centro, zoom) = _centroYZoom(widget.puntos, widget.centroComuna, widget.miUbicacion);
      _controller.move(centro, zoom);
    }
  }

  void _centrarEnMiUbicacion() {
    final posicion = _miUbicacionEnVivo;
    if (posicion == null) return;
    _controller.move(posicion, _zoomConPuntos);
  }

  @override
  void dispose() {
    unawaited(_suscripcionUbicacion.cancel());
    _controller.dispose();
    _estiloFuturo.then((estilo) => estilo.dispose()).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _mapa(context)),
        if (widget.mostrarMiUbicacion && _miUbicacionEnVivo != null)
          Positioned(
            top: espacioMd,
            right: espacioMd,
            child: FloatingActionButton.small(
              key: const Key('boton-mi-ubicacion'),
              heroTag: 'boton-mi-ubicacion',
              onPressed: _centrarEnMiUbicacion,
              child: const Icon(Icons.my_location),
            ),
          ),
      ],
    );
  }

  Widget _mapa(BuildContext context) {
    final (centro, zoom) = _centroYZoom(widget.puntos, widget.centroComuna, widget.miUbicacion);
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
                key: const ValueKey('vector-tiles'),
                theme: estilo.theme,
                tileProviders: estilo.providers,
                rasterSources: estilo.rasterSources,
                sprites: estilo.sprites,
              ),
            MarkerLayer(
              key: const ValueKey('puntos-de-reciclaje'),
              markers: [
                for (final punto in widget.puntos)
                  Marker(
                    point: punto.ubicacion,
                    width: 42,
                    height: 42,
                    alignment: Alignment.topCenter,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(punto.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, progreso, child) => Opacity(opacity: progreso, child: child),
                      child: GestureDetector(
                        onTap: () => widget.onTocarPunto(punto),
                        child: Image.asset('assets/branding/icono_marcador.png'),
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.mostrarMiUbicacion)
              MiUbicacionLayer(key: const ValueKey('mi-ubicacion'), posiciones: widget.posicionEnVivo),
            if (estilo != null)
              MapAttribution(key: const ValueKey('atribucion'), atribuciones: estilo.attributions),
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
        padding: const EdgeInsets.all(espacioLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: espacioMd - espacioXs),
            if (mensaje != null) ...[
              Text(mensaje!, textAlign: TextAlign.center),
              const SizedBox(height: espacioSm),
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
        padding: const EdgeInsets.all(espacioLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: espacioMd - espacioXs),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: espacioMd),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _AvisoFueraDeRango extends StatelessWidget {
  const _AvisoFueraDeRango();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radioDeHojaFlotante),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: espacioMd, vertical: 14),
          decoration: BoxDecoration(
            color: colores.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radioDeHojaFlotante),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, color: colores.error),
              const SizedBox(width: espacioSm),
              const Text('Fuera de rango'),
            ],
          ),
        ),
      ),
    );
  }
}
