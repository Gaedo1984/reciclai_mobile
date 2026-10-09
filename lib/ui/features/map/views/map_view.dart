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
import 'radius_toggle_button.dart';
import '../../tour/tour_step.dart';
import '../../tour/views/tour_overlay.dart';
import '../../tour/views/tour_trigger_button.dart';

const _centroSantiago = LatLng(-33.45, -70.65);
const _zoomPorDefecto = 12.0;
const _zoomSinPuntos = 13.0;
const _zoomConPuntos = 15.0;
// Sin estos limites, alejar el zoom hasta ver el continente/mundo hace
// colapsar la app (reportado en produccion) -- el renderizador de tiles
// vectoriales no da abasto a esa escala. minZoom mantiene la vista dentro de
// Chile y alrededores como maximo alejamiento; maxZoom evita acercar mas
// alla del detalle util de calles de este estilo de mapa.
const _zoomMinimo = 4.0;
const _zoomMaximo = 18.0;
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
  final _keyMiUbicacion = GlobalKey();
  final _keyComunaSelector = GlobalKey();
  final _keyFiltroMateriales = GlobalKey();
  final _keyRadioToggle = GlobalKey();
  final _keyBusquedaAmpliada = GlobalKey();
  OverlayEntry? _entradaDelTour;

  // Se mantiene mientras `cuerpo` vuelve a `Cargando()` (elegir otra comuna,
  // volver a "mi ubicacion", activar el radio, reintentar) para que la
  // pantalla no se quede en blanco con solo un spinner -- se sigue viendo lo
  // que ya habia, con el spinner encima, hasta que la recarga termine. Null
  // solo en la primera carga de la app, antes de mostrar algo por primera vez.
  Widget? _ultimoContenido;

  @override
  void initState() {
    super.initState();
    if (widget.iniciarAlMontar) widget.viewModel.iniciar();
  }

  @override
  void dispose() {
    _entradaDelTour?.remove();
    super.dispose();
  }

  void _iniciarTour() {
    // Un toque repetido mientras el tour ya esta abierto (p. ej. a traves de
    // TalkBack activando el boton de nuevo, que no pasa por el hit-testing
    // normal que el overlay ya bloquea) no debe crear una segunda instancia —
    // cerrar una con "Saltar" dejaria a la otra en pantalla sin forma de
    // cerrarla.
    if (_entradaDelTour != null) return;
    final entrada = OverlayEntry(
      builder: (context) => BlockSemantics(
        child: TourOverlay(
        pasos: [
          const TourStep(
            titulo: 'El mapa',
            cuerpo: 'Los pines verdes son puntos de reciclaje cerca de ti.',
            imagenAsset: 'assets/branding/icono_marcador.png',
          ),
          TourStep(
            titulo: 'Tu ubicación',
            cuerpo: 'Toca aquí para centrar el mapa en tu ubicación.',
            anchorKey: _keyMiUbicacion,
          ),
          TourStep(
            titulo: 'Elige tu comuna',
            cuerpo: 'O elige tu comuna aquí si prefieres buscar así.',
            anchorKey: _keyComunaSelector,
          ),
          TourStep(
            titulo: 'Busca por cercanía',
            cuerpo: 'Actívalo para ver los puntos a 3km a la redonda tuyo, sin importar la '
                'comuna — útil si vives cerca del límite entre dos comunas.',
            anchorKey: _keyRadioToggle,
          ),
          TourStep(
            titulo: 'Filtra por material',
            cuerpo: 'Filtra por el tipo de material que quieres reciclar.',
            anchorKey: _keyFiltroMateriales,
          ),
          TourStep(
            titulo: 'Busca más lejos',
            cuerpo: 'Si el filtro de materiales no encuentra nada cerca, aparece este botón '
                'para buscar en un radio de 15 km.',
            anchorKey: _keyBusquedaAmpliada,
          ),
          const TourStep(
            titulo: 'Avisos temporales',
            cuerpo: 'Si un filtro no encuentra nada cerca, vas a ver un aviso breve que se '
                'cierra solo a los pocos segundos — o toca la X para cerrarlo antes.',
          ),
          const TourStep(
            titulo: 'Detalle de un punto',
            cuerpo: 'Toca cualquier pin para ver su dirección, materiales y trazar una ruta.',
          ),
        ],
          onCerrar: _cerrarTour,
        ),
      ),
    );
    setState(() => _entradaDelTour = entrada);
    Overlay.of(context).insert(entrada);
  }

  void _cerrarTour() {
    final entrada = _entradaDelTour;
    if (entrada == null) return;
    entrada.remove();
    setState(() => _entradaDelTour = null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Con el tour abierto, el boton atras del sistema (o el gesto de retroceso)
      // debe cerrar el tour, no la pantalla entera — sin esto, MapView es la unica
      // ruta de la app y "atras" salia directo de la app con el tour tapando todo.
      canPop: _entradaDelTour == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cerrarTour();
      },
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 64,
        // Sin esto, Flutter centra el title solo en iOS/macOS por defecto — en
        // Android queda a la izquierda.
        centerTitle: true,
        title: Image.asset(
          'assets/branding/logo_horizontal.png',
          height: 44,
          fit: BoxFit.contain,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: espacioMd),
            child: TourTriggerButton(onTap: _iniciarTour),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final cuerpo = widget.viewModel.cuerpo;
          final contenidoNuevo = switch (cuerpo) {
            Cargando() => null,
            ConDatos(:final puntos) => _MapaConPuntos(
                puntos: filtrarPorMateriales(puntos, widget.viewModel.materialesSeleccionados),
                centroComuna: widget.viewModel.centroComunaSeleccionada,
                miUbicacion: widget.viewModel.miUbicacion,
                onTocarPunto: _mostrarDetalle,
                mostrarMiUbicacion: widget.viewModel.tienePermisoDeUbicacion,
                posicionEnVivo: widget.viewModel.posicionEnVivo,
                posicionEnVivoInicial: widget.viewModel.ultimaPosicionEnVivo,
                miUbicacionKey: _keyMiUbicacion,
                comunaSeleccionada: widget.viewModel.comunaSeleccionadaId != null,
                onLimpiarComuna: widget.viewModel.limpiarComuna,
                ajustarCamaraAPuntos: widget.viewModel.busquedaAmpliadaActiva,
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
                posicionEnVivoInicial: widget.viewModel.ultimaPosicionEnVivo,
                miUbicacionKey: _keyMiUbicacion,
                comunaSeleccionada: widget.viewModel.comunaSeleccionadaId != null,
                onLimpiarComuna: widget.viewModel.limpiarComuna,
                ajustarCamaraAPuntos: false,
              ),
          };
          if (contenidoNuevo != null) _ultimoContenido = contenidoNuevo;
          final contenidoAMostrar = _ultimoContenido;

          return Stack(
            children: [
              Positioned.fill(
                child: contenidoAMostrar == null
                    ? const Center(child: CircularProgressIndicator())
                    : AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: contenidoAMostrar),
              ),
              // El spinner se superpone sobre el contenido anterior en vez de
              // reemplazarlo -- antes, cada recarga (elegir otra comuna, volver
              // a "mi ubicacion", activar el radio) dejaba la pantalla en
              // blanco con solo un spinner, reportado como "se pone oscura".
              if (cuerpo is Cargando && contenidoAMostrar != null)
                const Positioned.fill(
                  child: IgnorePointer(child: Center(child: CircularProgressIndicator())),
                ),
              if (widget.viewModel.mostrarBusquedaAmpliada || widget.viewModel.avisoSinResultados != null)
                // Un solo bloque para los dos avisos -- un tester pidio que se
                // vean juntos: mismo ancho (CrossAxisAlignment.stretch hace que
                // ambas cajas ocupen el mismo ancho, el que da este Positioned),
                // el toast de 3s arriba del aviso con el boton de 15km, separados
                // 2px. Key explicita para que la reconciliacion de este slot del
                // Stack no dependa de la posicion en la que cae entre los demas
                // hijos condicionales del Stack.
                Positioned(
                  key: const ValueKey('avisos-de-filtro-sin-resultados'),
                  left: espacioMd,
                  right: espacioMd,
                  bottom: espacioLg + MediaQuery.of(context).padding.bottom + 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.viewModel.avisoSinResultados != null)
                        _AvisoTemporal(
                          mensaje: widget.viewModel.avisoSinResultados!,
                          onCerrar: widget.viewModel.descartarAviso,
                        ),
                      if (widget.viewModel.avisoSinResultados != null &&
                          widget.viewModel.mostrarBusquedaAmpliada)
                        const SizedBox(height: 2),
                      if (widget.viewModel.mostrarBusquedaAmpliada)
                        _AvisoBusquedaAmpliada(
                          key: _keyBusquedaAmpliada,
                          viewModel: widget.viewModel,
                        ),
                    ],
                  ),
                ),
              Positioned(
                left: espacioMd,
                right: espacioMd,
                bottom: espacioLg + MediaQuery.of(context).padding.bottom,
                child: widget.viewModel.cuerpo is FueraDeRango
                    ? const Center(child: _AvisoFueraDeRango())
                    : Center(
                        child: GlassBar(
                          children: [
                            RadiusToggleButton(
                              key: _keyRadioToggle,
                              viewModel: widget.viewModel,
                            ),
                            ComunaSelector(
                              key: _keyComunaSelector,
                              comunas: widget.viewModel.comunas,
                              comunaSeleccionadaId: widget.viewModel.comunaSeleccionadaId,
                              onElegirComuna: widget.viewModel.seleccionarComuna,
                              onLimpiarComuna: widget.viewModel.limpiarComuna,
                            ),
                            MaterialFilterButton(
                              key: _keyFiltroMateriales,
                              viewModel: widget.viewModel,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  void _mostrarDetalle(RecyclingPoint punto, LatLng? miUbicacion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // Sin esto, la hoja queda limitada a una fraccion fija de la pantalla — insuficiente
      // cuando el nombre/direccion/horario son largos y hay varios materiales.
      isScrollControlled: true,
      builder: (_) => PointDetailsSheet(
        punto: punto,
        nombresDeMateriales: widget.viewModel.nombresDeMateriales,
        miUbicacion: miUbicacion,
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
    required this.posicionEnVivoInicial,
    required this.miUbicacionKey,
    required this.comunaSeleccionada,
    required this.onLimpiarComuna,
    required this.ajustarCamaraAPuntos,
  });

  final List<RecyclingPoint> puntos;
  final LatLng? centroComuna;
  final LatLng? miUbicacion;
  final void Function(RecyclingPoint punto, LatLng? miUbicacion) onTocarPunto;
  final bool mostrarMiUbicacion;
  final Stream<Position> posicionEnVivo;

  /// Ultima posicion en vivo que el viewModel ya tenia cacheada antes de que
  /// este widget existiera -- un stream de broadcast no reproduce eventos
  /// pasados a un nuevo listener, asi que sin esto el punto azul y el boton
  /// "mi ubicacion" se quedaban esperando un evento que podia no llegar
  /// nunca si el dispositivo ya no se movia (bug real en produccion). Se usa
  /// solo para sembrar el estado inicial; las actualizaciones en vivo
  /// siguen llegando por `posicionEnVivo`.
  final LatLng? posicionEnVivoInicial;

  final GlobalKey miUbicacionKey;

  /// Si hay una comuna elegida a mano, tocar "mi ubicación" la limpia y recarga
  /// por geolocalización — ver `onLimpiarComuna`.
  final bool comunaSeleccionada;
  final VoidCallback onLimpiarComuna;

  /// Verdadero cuando `puntos` viene de `buscarEnRadioAmplio()` (15km). En ese
  /// caso la camara encuadra TODOS los puntos mas la ubicacion del usuario en
  /// vez de solo centrar en el usuario a zoom fijo -- sin esto, los puntos
  /// encontrados (tipicamente lejos, es por eso que la busqueda ampliada
  /// aparecio) quedaban fuera de la pantalla y la funcion parecia no hacer
  /// nada.
  final bool ajustarCamaraAPuntos;

  @override
  State<_MapaConPuntos> createState() => _MapaConPuntosState();
}

class _MapaConPuntosState extends State<_MapaConPuntos> {
  final _controller = MapController();
  late final Future<vt.Style> _estiloFuturo;
  late final StreamSubscription<Position> _suscripcionUbicacion;
  late LatLng? _miUbicacionEnVivo;

  @override
  void initState() {
    super.initState();
    _miUbicacionEnVivo = widget.posicionEnVivoInicial;
    _estiloFuturo = const vt.StyleReader(uri: _estiloMapaUrl).read();
    _suscripcionUbicacion = widget.posicionEnVivo.listen((posicion) {
      if (!mounted) return;
      setState(() => _miUbicacionEnVivo = LatLng(posicion.latitude, posicion.longitude));
    });
  }

  @override
  void didUpdateWidget(_MapaConPuntos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.puntos == widget.puntos &&
        oldWidget.centroComuna == widget.centroComuna &&
        oldWidget.miUbicacion == widget.miUbicacion) {
      return;
    }
    final miUbicacion = widget.miUbicacion;
    if (widget.ajustarCamaraAPuntos && widget.puntos.isNotEmpty && miUbicacion != null) {
      // Encuadra el usuario y todos los puntos encontrados -- a diferencia
      // de centrar a zoom fijo en el usuario, esto no deja afuera puntos
      // que esten lejos (el motivo mismo por el que la busqueda ampliada
      // existe).
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: [miUbicacion, ...widget.puntos.map((p) => p.ubicacion)],
          padding: const EdgeInsets.all(60),
          maxZoom: _zoomMaximo,
        ),
      );
      return;
    }
    final (centro, zoom) = _centroYZoom(widget.puntos, widget.centroComuna, widget.miUbicacion);
    _controller.move(centro, zoom);
  }

  void _centrarEnMiUbicacion() {
    final posicion = _miUbicacionEnVivo;
    if (posicion != null) {
      _controller.move(posicion, _zoomConPuntos);
    }
    if (widget.comunaSeleccionada) {
      widget.onLimpiarComuna();
    }
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
            child: KeyedSubtree(
              key: widget.miUbicacionKey,
              child: FloatingActionButton.small(
                key: const Key('boton-mi-ubicacion'),
                heroTag: 'boton-mi-ubicacion',
                onPressed: _centrarEnMiUbicacion,
                child: const Icon(Icons.my_location),
              ),
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
          options: MapOptions(
            initialCenter: centro,
            initialZoom: zoom,
            minZoom: _zoomMinimo,
            maxZoom: _zoomMaximo,
          ),
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
              // Sin esto, MarkerLayer rota los marcadores junto con el mapa (su
              // default es rotate: false) — los iconos quedan torcidos apenas el
              // usuario gira la camara en vez de mantenerse siempre verticales.
              rotate: true,
              markers: [
                for (final punto in widget.puntos)
                  Marker(
                    // La key va en el Marker, no en un widget anidado adentro de su
                    // child: MarkerLayer reconstruye su arbol interno en cada
                    // repintado de camara (cada frame de un pan/zoom), y sin esta key
                    // en el Marker no puede reconocer que sigue siendo "el mismo"
                    // marcador entre esos repintados — recreaba el TweenAnimationBuilder
                    // de cero cada vez, reiniciando la animacion de aparicion en loop y
                    // produciendo un parpadeo real en produccion al mover/zoomear el mapa.
                    key: ValueKey(punto.id),
                    point: punto.ubicacion,
                    width: 42,
                    height: 42,
                    alignment: Alignment.topCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, progreso, child) => Opacity(opacity: progreso, child: child),
                      child: GestureDetector(
                        onTap: () => widget.onTocarPunto(punto, _miUbicacionEnVivo),
                        child: Image.asset('assets/branding/icono_marcador.png'),
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.mostrarMiUbicacion)
              MiUbicacionLayer(
                key: const ValueKey('mi-ubicacion'),
                posiciones: widget.posicionEnVivo,
                posicionInicial: widget.posicionEnVivoInicial,
              ),
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

class _AvisoBusquedaAmpliada extends StatefulWidget {
  const _AvisoBusquedaAmpliada({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  State<_AvisoBusquedaAmpliada> createState() => _AvisoBusquedaAmpliadaState();
}

class _AvisoBusquedaAmpliadaState extends State<_AvisoBusquedaAmpliada> {
  bool _buscando = false;

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    await widget.viewModel.buscarEnRadioAmplio();
    if (mounted) setState(() => _buscando = false);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final boton = _buscando
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        // FilledButton en vez de TextButton -- un tester reporto que el texto
        // no se veia como algo que se pudiera tocar. Colores propios (verde
        // claro de la marca, via primaryContainer) en vez del default del
        // tema -- otro tester pidio que se sintiera "de la app".
        : FilledButton.icon(
            onPressed: _buscar,
            style: FilledButton.styleFrom(
              backgroundColor: colores.primaryContainer,
              foregroundColor: colores.onPrimaryContainer,
            ),
            icon: const Icon(Icons.search),
            label: const Text('Buscar en 15 km'),
          );
    // Sin tarjeta ni mensaje de texto -- un tester lo encontro confuso
    // (parecia un cartel, no un boton). La X vive en un Stack superpuesta a
    // la esquina del boton (no alineada al ancho completo del bloque, que la
    // dejaba lejos del boton cuando este quedaba mas angosto que el toast de
    // arriba) -- asi queda pegada a el, independiente de cuanto mida el
    // bloque. `Center` evita que el `Stack` se estire con el resto del
    // bloque (CrossAxisAlignment.stretch en el Column que lo contiene);
    // `clipBehavior: Clip.none` deja que la X sobresalga del tamaño del
    // boton sin recortarse.
    return Center(
      child: Stack(
        key: const Key('caja-busqueda-ampliada'),
        clipBehavior: Clip.none,
        children: [
          boton,
          // Oculta mientras busca -- un tester reporto que la X se quedaba
          // en pantalla durante toda la busqueda (desaparecia recien al
          // terminar); el boton ya desaparecio (es el spinner de arriba), la
          // X deberia hacerlo con el, no esperar a que la busqueda termine.
          if (!_buscando)
            Positioned(
              top: -10,
              right: -10,
              child: _BotonCerrarEnCirculo(
                key: const Key('cerrar-busqueda-ampliada'),
                onTap: widget.viewModel.descartarBusquedaAmpliada,
              ),
            ),
        ],
      ),
    );
  }
}

/// X dentro de un circulo un poco mas grande que el icono -- distinto de
/// `BotonCerrarHoja` (icono suelto, sin circulo) a proposito: este cierra un
/// aviso flotante sobre el mapa, no el encabezado de una hoja modal.
class _BotonCerrarEnCirculo extends StatelessWidget {
  const _BotonCerrarEnCirculo({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close, size: 16),
        ),
      ),
    );
  }
}

/// Toast puntual (ej. "sin puntos cercanos para el filtro") que no requiere
/// una accion del usuario para desaparecer -- el cierre automatico a los 3
/// segundos lo maneja el ViewModel (`avisoSinResultados`/`descartarAviso()`),
/// no este widget: asi no depende de que este widget mantenga su `State`
/// estable entre reconstrucciones del Stack (bug real en un dispositivo
/// real -- ver doc de `avisoSinResultados`).
class _AvisoTemporal extends StatelessWidget {
  const _AvisoTemporal({required this.mensaje, required this.onCerrar});

  final String mensaje;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radioDeHojaFlotante),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          key: const Key('caja-aviso-sin-resultados'),
          padding: const EdgeInsets.symmetric(horizontal: espacioMd, vertical: 10),
          decoration: BoxDecoration(
            color: colores.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radioDeHojaFlotante),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(mensaje)),
              const SizedBox(width: espacioSm),
              BotonCerrarHoja(key: const Key('cerrar-aviso-sin-resultados'), onTap: onCerrar),
            ],
          ),
        ),
      ),
    );
  }
}
