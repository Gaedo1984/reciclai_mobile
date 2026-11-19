import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/models/recycling_point.dart';
import '../../../../data/models/servicio_retiro.dart';
import '../../../../domain/filtro_material.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/glass_bar.dart';
import '../../../core/glass_bar_action.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../../camion_reciclaje/view_models/camion_reciclaje_view_model.dart';
import '../../camion_reciclaje/views/hoja_camion_reciclaje.dart';
import '../../como_reciclar/views/menu_lateral.dart';
import '../../notificaciones/view_models/notificaciones_view_model.dart';
import '../../notificaciones/views/campana_notificaciones.dart';
import '../view_models/map_state.dart';
import '../view_models/map_view_model.dart';
import 'comuna_selector.dart';
import 'map_attribution.dart';
import 'material_filter_button.dart';
import 'my_location_layer.dart';
import 'point_details_sheet.dart';
import 'radius_selector_panel.dart';
import 'radius_selector_trigger.dart';
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
const _claveCamionVisto = 'camion_visto';

/// Sin comuna elegida, la disponibilidad del camion se vuelve a consultar
/// solo si el usuario se alejo mas que esto del ultimo punto consultado.
const _metrosParaReconsultarCamion = 1000.0;

/// Cuanto queda abierto el globo de "sin camion" si nadie lo cierra antes.
const _duracionGloboSinCamion = Duration(seconds: 4);

(LatLng, double) _centroYZoom(
  List<RecyclingPoint> puntos,
  LatLng? centroComuna,
  LatLng? miUbicacion,
) {
  if (miUbicacion != null) {
    return (miUbicacion, _zoomConPuntos);
  }
  if (puntos.isNotEmpty) {
    final lat =
        puntos.map((p) => p.ubicacion.latitude).reduce((a, b) => a + b) /
        puntos.length;
    final lng =
        puntos.map((p) => p.ubicacion.longitude).reduce((a, b) => a + b) /
        puntos.length;
    return (LatLng(lat, lng), _zoomConPuntos);
  }
  if (centroComuna != null) {
    return (centroComuna, _zoomSinPuntos);
  }
  return (_centroSantiago, _zoomPorDefecto);
}

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.viewModel,
    this.notificacionesViewModel,
    this.camionReciclajeViewModel,
    this.iniciarAlMontar = true,
  });

  final MapViewModel viewModel;

  /// Opcional (no `required`): si es null, la campana simplemente no se
  /// muestra -- mismo comportamiento que antes de esta feature. Ver
  /// Global Constraints del plan de notificaciones (evita forzar un
  /// parametro nuevo en las ~50 construcciones de MapView ya existentes
  /// en los tests, que no tienen relacion con esta feature).
  final NotificacionesViewModel? notificacionesViewModel;

  /// Opcional por la misma razon que `notificacionesViewModel`: si es null,
  /// el boton del camion no se muestra.
  final CamionReciclajeViewModel? camionReciclajeViewModel;

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
  final _keyCampana = GlobalKey();
  final _keyMenu = GlobalKey();
  final _keyCamion = GlobalKey();
  OverlayEntry? _entradaDelTour;
  bool _selectorDeRadioAbierto = false;

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
    widget.notificacionesViewModel?.cargar();
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
            if (widget.camionReciclajeViewModel != null)
              TourStep(
                titulo: 'Camión de reciclaje',
                cuerpo:
                    'Toca aquí para ver qué día pasa el camión por tu sector y por dónde '
                    'recorre. Si está gris, el camión aún no llega a tu comuna.',
                anchorKey: _keyCamion,
              ),
            TourStep(
              titulo: 'Elige tu comuna',
              cuerpo: 'O elige tu comuna aquí si prefieres buscar así.',
              anchorKey: _keyComunaSelector,
            ),
            TourStep(
              titulo: 'Busca por cercanía',
              cuerpo:
                  'Elige 3, 5 o 7 km a la redonda tuyo, sin importar la comuna — útil si '
                  'vives cerca del límite entre dos comunas. Toca "Off" para volver a la '
                  'búsqueda normal.',
              anchorKey: _keyRadioToggle,
            ),
            TourStep(
              titulo: 'Filtra por material',
              cuerpo: 'Filtra por el tipo de material que quieres reciclar.',
              anchorKey: _keyFiltroMateriales,
            ),
            TourStep(
              titulo: 'Busca más lejos',
              cuerpo:
                  'Si el filtro de materiales no encuentra nada cerca, aparece este botón '
                  'para buscar en un radio de 15 km.',
              anchorKey: _keyBusquedaAmpliada,
            ),
            const TourStep(
              titulo: 'Avisos temporales',
              cuerpo:
                  'Si un filtro no encuentra nada cerca, vas a ver un aviso breve que se '
                  'cierra solo a los pocos segundos — o toca la X para cerrarlo antes.',
            ),
            const TourStep(
              titulo: 'Detalle de un punto',
              cuerpo: 'Toca cualquier pin para ver su dirección, materiales y trazar una ruta.',
            ),
            TourStep(
              titulo: 'Notificaciones',
              cuerpo: 'Toca la campana para ver avisos y novedades de la app.',
              anchorKey: _keyCampana,
            ),
            TourStep(
              titulo: 'Más opciones',
              cuerpo:
                  'Toca el menú para ver más de lo que ReciclAI tiene para ti — esta sección '
                  'sigue creciendo.',
              anchorKey: _keyMenu,
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
        // Con esto seteado, Flutter agrega solo el icono de hamburguesa como
        // `leading` del AppBar (sin pisar el `title` centrado ni los
        // `actions` de la campana/Tour a la derecha).
        drawer: MenuLateral(onVerEnMapa: widget.viewModel.aplicarFiltroMateriales),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          toolbarHeight: alturaAppBar,
          // colorVerdeLogo (el verde vivo del logo, no colorSemillaBosque --
          // ese es el salvia apagado del tema, probado en celular y el
          // usuario reporto que "no se aprecia" como verde a simple vista)
          // + el contorno negro (mismo helper que ya usan los iconos del
          // GlassBar) para que se note bien en modo claro y oscuro.
          leading: Builder(
            builder: (context) => IconButton(
              key: _keyMenu,
              icon: Icon(
                Icons.menu,
                color: colorVerdeLogo,
                shadows: contornoSobreVidrio(),
              ),
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          // Sin esto, Flutter centra el title solo en iOS/macOS por defecto — en
          // Android queda a la izquierda.
          centerTitle: true,
          title: Image.asset(
            'assets/branding/logo_horizontal.png',
            height: 44,
            fit: BoxFit.contain,
          ),
          actions: [
            if (widget.notificacionesViewModel != null)
              Padding(
                padding: const EdgeInsets.only(right: espacioXs),
                child: CampanaNotificaciones(
                  key: _keyCampana,
                  viewModel: widget.notificacionesViewModel!,
                ),
              ),
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
                puntos: filtrarPorMateriales(
                  puntos,
                  widget.viewModel.materialesSeleccionados,
                ),
                centroComuna: widget.viewModel.centroComunaSeleccionada,
                miUbicacion: widget.viewModel.miUbicacion,
                onTocarPunto: _mostrarDetalle,
                mostrarMiUbicacion: widget.viewModel.tienePermisoDeUbicacion,
                posicionEnVivo: widget.viewModel.posicionEnVivo,
                posicionEnVivoInicial: widget.viewModel.ultimaPosicionEnVivo,
                miUbicacionKey: _keyMiUbicacion,
                comunaSeleccionada:
                    widget.viewModel.comunaSeleccionadaId != null,
                onLimpiarComuna: widget.viewModel.limpiarComuna,
                comunaSeleccionadaId: widget.viewModel.comunaSeleccionadaId,
                camionReciclajeViewModel: widget.camionReciclajeViewModel,
                camionKey: _keyCamion,
                ajustarCamaraAPuntos: widget.viewModel.busquedaAmpliadaActiva,
              ),
              SinSeleccion(:final mensaje) => _EstadoSinSeleccion(
                mensaje: mensaje,
              ),
              ErrorAlCargar() => _MapaConPuntos(
                puntos: const [],
                centroComuna: widget.viewModel.centroComunaSeleccionada,
                miUbicacion: widget.viewModel.miUbicacion,
                onTocarPunto: _mostrarDetalle,
                mostrarMiUbicacion: widget.viewModel.tienePermisoDeUbicacion,
                posicionEnVivo: widget.viewModel.posicionEnVivo,
                posicionEnVivoInicial: widget.viewModel.ultimaPosicionEnVivo,
                miUbicacionKey: _keyMiUbicacion,
                comunaSeleccionada:
                    widget.viewModel.comunaSeleccionadaId != null,
                onLimpiarComuna: widget.viewModel.limpiarComuna,
                comunaSeleccionadaId: widget.viewModel.comunaSeleccionadaId,
                camionReciclajeViewModel: widget.camionReciclajeViewModel,
                camionKey: _keyCamion,
                ajustarCamaraAPuntos: false,
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
                comunaSeleccionada:
                    widget.viewModel.comunaSeleccionadaId != null,
                onLimpiarComuna: widget.viewModel.limpiarComuna,
                comunaSeleccionadaId: widget.viewModel.comunaSeleccionadaId,
                camionReciclajeViewModel: widget.camionReciclajeViewModel,
                camionKey: _keyCamion,
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
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: contenidoAMostrar,
                        ),
                ),
                // El spinner se superpone sobre el contenido anterior en vez de
                // reemplazarlo -- antes, cada recarga (elegir otra comuna, volver
                // a "mi ubicacion", activar el radio) dejaba la pantalla en
                // blanco con solo un spinner, reportado como "se pone oscura".
                if (cuerpo is Cargando && contenidoAMostrar != null)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if ((widget.viewModel.mostrarBusquedaAmpliada ||
                        widget.viewModel.avisoSinResultados != null) &&
                    !_selectorDeRadioAbierto)
                  // Un solo bloque para los dos avisos -- un tester pidio que se
                  // vean juntos: mismo ancho (CrossAxisAlignment.stretch hace que
                  // ambas cajas ocupen el mismo ancho, el que da este Positioned),
                  // el toast de 3s arriba del aviso con el boton de 15km, separados
                  // 2px. Key explicita para que la reconciliacion de este slot del
                  // Stack no dependa de la posicion en la que cae entre los demas
                  // hijos condicionales del Stack.
                  //
                  // Se oculta mientras el selector de radio esta abierto -- sin
                  // esto, el panel (pegado arriba de la barra) se superponia con
                  // este bloque (hallazgo real de la revision final: ambos caen
                  // en la misma franja vertical). Tocar afuera ya cierra el
                  // panel de todas formas (la barrera lo intercepta antes de
                  // llegar a este aviso), asi que ocultarlo no le quita ninguna
                  // interaccion al usuario.
                  Positioned(
                    key: const ValueKey('avisos-de-filtro-sin-resultados'),
                    left: espacioMd,
                    right: espacioMd,
                    bottom:
                        espacioLg + MediaQuery.of(context).padding.bottom + 72,
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
                      : widget.viewModel.cuerpo is ErrorAlCargar
                      ? Center(
                          child: _BotonReintentar(
                            onReintentar: widget.viewModel.reintentar,
                          ),
                        )
                      : Center(
                          child: GlassBar(
                            children: [
                              RadiusSelectorTrigger(
                                key: _keyRadioToggle,
                                viewModel: widget.viewModel,
                                onTap: () => setState(
                                  () => _selectorDeRadioAbierto =
                                      !_selectorDeRadioAbierto,
                                ),
                              ),
                              ComunaSelector(
                                key: _keyComunaSelector,
                                comunas: widget.viewModel.comunas,
                                comunaSeleccionadaId:
                                    widget.viewModel.comunaSeleccionadaId,
                                onElegirComuna:
                                    widget.viewModel.seleccionarComuna,
                                onLimpiarComuna: widget.viewModel.limpiarComuna,
                                onReintentarComunasSiVacia:
                                    widget.viewModel.reintentarComunasSiHaceFalta,
                              ),
                              MaterialFilterButton(
                                key: _keyFiltroMateriales,
                                viewModel: widget.viewModel,
                              ),
                            ],
                          ),
                        ),
                ),
                if (_selectorDeRadioAbierto)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () =>
                          setState(() => _selectorDeRadioAbierto = false),
                    ),
                  ),
                if (_selectorDeRadioAbierto)
                  Positioned(
                    left: espacioMd,
                    right: espacioMd,
                    // Pegado arriba de la barra principal (mismo bottom + su
                    // alto, sin el espacio que si tienen el aviso de "sin
                    // resultados" o el boton de 15km) -- para que se vea como
                    // una extension de la barra, no como una tarjeta aparte.
                    bottom:
                        espacioLg + MediaQuery.of(context).padding.bottom + 48,
                    child: Center(
                      child: RadiusSelectorPanel(
                        viewModel: widget.viewModel,
                        onCerrar: () =>
                            setState(() => _selectorDeRadioAbierto = false),
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
    required this.comunaSeleccionadaId,
    required this.camionReciclajeViewModel,
    this.camionKey,
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

  /// El camion se busca por esta comuna; si es null, por la ubicacion en vivo.
  final String? comunaSeleccionadaId;

  /// Null oculta el boton del camion.
  final CamionReciclajeViewModel? camionReciclajeViewModel;

  /// Envuelve el boton del camion, como `miUbicacionKey`; lo usa el tour.
  final GlobalKey? camionKey;

  @override
  State<_MapaConPuntos> createState() => _MapaConPuntosState();
}

class _MapaConPuntosState extends State<_MapaConPuntos>
    with TickerProviderStateMixin {
  final _controller = MapController();
  late final Future<vt.Style> _estiloFuturo;
  late final StreamSubscription<Position> _suscripcionUbicacion;
  late LatLng? _miUbicacionEnVivo;

  /// Anillo del boton del camion mientras el usuario no lo haya tocado nunca.
  late final AnimationController _pulsoCamion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Avance del trazo del contorno de la zona del camion: la linea recorre el
  /// borde como una ruta y cada numero aparece cuando la linea llega a su
  /// calle (pedido del usuario, 2026-11-17).
  late final AnimationController _trazoZona = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// Null mientras no se sabe (lectura de SharedPreferences pendiente): asi
  /// la etiqueta no aparece un instante a quien ya toco el boton antes.
  bool? _camionVisto;

  /// Zona del dia dibujada en el mapa; solo mientras la hoja esta abierta.
  ZonaRetiro? _zonaResaltada;

  /// Contorno de `_zonaResaltada`, precalculado al cambiar la zona.
  _ContornoZona? _contornoZona;
  bool _hojaCamionAbierta = false;

  /// Ultima disponibilidad dibujada; asi solo se repinta cuando cambia.
  DisponibilidadCamion _disponibilidadCamion = DisponibilidadCamion.desconocida;

  /// Ubicacion con la que se consulto la disponibilidad por ultima vez, sin
  /// comuna elegida; null si la ultima consulta fue por comuna o no hubo.
  LatLng? _ubicacionConsultada;

  bool _globoSinCamionVisible = false;
  Timer? _cierreGloboSinCamion;

  bool get _camionSinServicio =>
      _disponibilidadCamion == DisponibilidadCamion.sinServicio;

  @override
  void initState() {
    super.initState();
    _miUbicacionEnVivo = widget.posicionEnVivoInicial;
    final camionViewModel = widget.camionReciclajeViewModel;
    if (camionViewModel != null) {
      unawaited(_leerCamionVisto());
      _consultarDisponibilidadCamion();
      _disponibilidadCamion = camionViewModel.disponibilidad;
      camionViewModel.addListener(_alCambiarDisponibilidad);
    }
    _estiloFuturo = const vt.StyleReader(uri: _estiloMapaUrl).read();
    _suscripcionUbicacion = widget.posicionEnVivo.listen((posicion) {
      if (!mounted) return;
      final ubicacion = LatLng(posicion.latitude, posicion.longitude);
      setState(() => _miUbicacionEnVivo = ubicacion);
      _alMoverseParaElCamion(ubicacion);
    });
  }

  @override
  void didUpdateWidget(_MapaConPuntos oldWidget) {
    super.didUpdateWidget(oldWidget);
    final camionViewModel = widget.camionReciclajeViewModel;
    if (oldWidget.camionReciclajeViewModel != camionViewModel) {
      oldWidget.camionReciclajeViewModel?.removeListener(
        _alCambiarDisponibilidad,
      );
      camionViewModel?.addListener(_alCambiarDisponibilidad);
      _consultarDisponibilidadCamion();
      _alCambiarDisponibilidad();
    } else if (oldWidget.comunaSeleccionadaId != widget.comunaSeleccionadaId) {
      _consultarDisponibilidadCamion();
    }
    if (oldWidget.puntos == widget.puntos &&
        oldWidget.centroComuna == widget.centroComuna &&
        oldWidget.miUbicacion == widget.miUbicacion) {
      return;
    }
    final miUbicacion = widget.miUbicacion;
    if (widget.ajustarCamaraAPuntos &&
        widget.puntos.isNotEmpty &&
        miUbicacion != null) {
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
    final (centro, zoom) = _centroYZoom(
      widget.puntos,
      widget.centroComuna,
      widget.miUbicacion,
    );
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

  /// Pregunta si hay camion en la comuna elegida o, sin comuna, en la
  /// ubicacion en vivo. Sin ninguna de las dos queda `desconocida`.
  void _consultarDisponibilidadCamion() {
    final viewModel = widget.camionReciclajeViewModel;
    if (viewModel == null) return;
    final comunaId = widget.comunaSeleccionadaId;
    final ubicacion = comunaId == null ? _miUbicacionEnVivo : null;
    _ubicacionConsultada = ubicacion;
    unawaited(
      viewModel.consultarDisponibilidad(
        comunaId: comunaId,
        ubicacion: ubicacion,
      ),
    );
  }

  /// Sin comuna elegida, consulta con la primera posicion en vivo y despues
  /// solo si el usuario se alejo mas de 1 km del punto consultado. Con comuna
  /// elegida, moverse no cambia la respuesta y no se consulta.
  void _alMoverseParaElCamion(LatLng ubicacion) {
    if (widget.camionReciclajeViewModel == null ||
        widget.comunaSeleccionadaId != null) {
      return;
    }
    final consultada = _ubicacionConsultada;
    if (consultada != null &&
        const Distance().as(LengthUnit.Meter, consultada, ubicacion) <=
            _metrosParaReconsultarCamion) {
      return;
    }
    _consultarDisponibilidadCamion();
  }

  void _alCambiarDisponibilidad() {
    final disponibilidad =
        widget.camionReciclajeViewModel?.disponibilidad ??
        DisponibilidadCamion.desconocida;
    if (!mounted || disponibilidad == _disponibilidadCamion) return;
    setState(() {
      _disponibilidadCamion = disponibilidad;
      // El globo solo tiene sentido mientras la comuna no tenga camion.
      if (!_camionSinServicio) _cerrarGloboSinCamion();
    });
    _sincronizarPulso();
  }

  /// El anillo solo se dibuja (y por eso solo debe animarse) en el primer uso,
  /// con servicio en la comuna y con animaciones permitidas.
  void _sincronizarPulso() {
    final debePulsar =
        _camionVisto == false &&
        !_camionSinServicio &&
        !MediaQuery.disableAnimationsOf(context);
    if (!debePulsar) {
      _pulsoCamion.stop();
    } else if (!_pulsoCamion.isAnimating) {
      _pulsoCamion.repeat();
    }
  }

  void _mostrarGloboSinCamion() {
    _cierreGloboSinCamion?.cancel();
    _cierreGloboSinCamion = Timer(_duracionGloboSinCamion, () {
      if (mounted) setState(_cerrarGloboSinCamion);
    });
    setState(() => _globoSinCamionVisible = true);
  }

  /// Solo cambia los campos; quien la llama hace el setState.
  void _cerrarGloboSinCamion() {
    _cierreGloboSinCamion?.cancel();
    _cierreGloboSinCamion = null;
    _globoSinCamionVisible = false;
  }

  void _alTocarMapa(TapPosition _, LatLng _) {
    if (_globoSinCamionVisible) setState(_cerrarGloboSinCamion);
  }

  /// En una comuna sin camion el boton no abre la hoja ni cuenta como primer
  /// uso: solo avisa con el globo.
  void _tocarBotonCamion() {
    if (_camionSinServicio) {
      _mostrarGloboSinCamion();
    } else {
      unawaited(_abrirCamion());
    }
  }

  Future<void> _leerCamionVisto() async {
    final bool visto;
    try {
      final prefs = await SharedPreferences.getInstance();
      visto = prefs.getBool(_claveCamionVisto) ?? false;
    } catch (_) {
      // Sin preferencias no se insiste con la etiqueta.
      return;
    }
    // Si el usuario ya toco el camion mientras se leian las preferencias, la
    // etiqueta de primer uso no debe volver.
    if (!mounted || _camionVisto == true) return;
    setState(() => _camionVisto = visto);
    _sincronizarPulso();
  }

  Future<void> _marcarCamionVisto() async {
    if (_camionVisto == true) return;
    setState(() => _camionVisto = true);
    _pulsoCamion.stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveCamionVisto, true);
    } catch (_) {
      // Si no se pudo guardar, la etiqueta vuelve la proxima vez; no es grave.
    }
  }

  Future<void> _abrirCamion() async {
    final viewModel = widget.camionReciclajeViewModel;
    if (viewModel == null || _hojaCamionAbierta) return;
    unawaited(_marcarCamionVisto());
    final comunaId = widget.comunaSeleccionadaId;
    final ubicacion = _miUbicacionEnVivo;
    if (comunaId == null && ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa tu ubicación o elige una comuna para ver el camión.'),
        ),
      );
      return;
    }
    // Mientras la hoja esta abierta se ocultan los puntos de reciclaje: en
    // comunas con muchos puntos tapaban la zona del camion (caso real de La
    // Florida, pedido del usuario 2026-11-16). Vuelven apenas se cierra.
    setState(() => _hojaCamionAbierta = true);
    viewModel.addListener(_alCambiarZonaDelDia);
    unawaited(viewModel.abrir(comunaId: comunaId, ubicacion: ubicacion));
    await mostrarHojaCamionReciclaje(context, viewModel);
    viewModel.removeListener(_alCambiarZonaDelDia);
    _hojaCamionAbierta = false;
    // Al cerrar se quita la zona sin mover la camara.
    if (!mounted) return;
    _trazoZona.stop();
    setState(() {
      _zonaResaltada = null;
      _contornoZona = null;
    });
  }

  void _alCambiarZonaDelDia() {
    final zona = widget.camionReciclajeViewModel?.zonaDelDia;
    if (!mounted || zona == _zonaResaltada) return;
    setState(() {
      _zonaResaltada = zona;
      _contornoZona = zona == null ? null : _ContornoZona(zona);
    });
    if (zona == null) {
      _trazoZona.stop();
      return;
    }
    // Cada zona nueva (abrir la hoja o cambiar de dia) se traza desde cero.
    // Con movimiento reducido el build la dibuja completa de una vez.
    if (MediaQuery.disableAnimationsOf(context)) {
      _trazoZona.value = 1;
    } else {
      unawaited(_trazoZona.forward(from: 0));
    }
    final puntos = [
      ...zona.poligonos.expand((p) => p),
      // Una calle puede asomar un poco fuera del borde de la zona.
      ...zona.calles.expand((calle) => calle.tramo),
    ];
    if (puntos.isEmpty) return;
    // Encuadra la zona en la franja del mapa que la hoja deja visible.
    final altoHoja = MediaQuery.sizeOf(context).height * fraccionAlturaHojaCamion;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: puntos,
        // Margen chico para que la zona se vea lo mas grande posible (pedido
        // del usuario tras probar en el iPhone, 2026-11-17). A la derecha se
        // deja el ancho de los botones de ubicacion y del camion para que no
        // tapen numeros de calles.
        padding: EdgeInsets.only(
          top: espacioSm,
          left: espacioSm,
          right: 56 + espacioMd,
          bottom: altoHoja + espacioSm,
        ),
        maxZoom: _zoomMaximo,
      ),
    );
  }

  @override
  void dispose() {
    widget.camionReciclajeViewModel?.removeListener(_alCambiarZonaDelDia);
    widget.camionReciclajeViewModel?.removeListener(_alCambiarDisponibilidad);
    _cierreGloboSinCamion?.cancel();
    _pulsoCamion.dispose();
    _trazoZona.dispose();
    unawaited(_suscripcionUbicacion.cancel());
    _controller.dispose();
    _estiloFuturo.then((estilo) => estilo.dispose()).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final botonUbicacionVisible =
        widget.mostrarMiUbicacion && _miUbicacionEnVivo != null;
    // 48: alto del boton de ubicacion con su area tactil.
    final arribaBotonCamion =
        espacioMd + (botonUbicacionVisible ? 48 + espacioSm : 0);
    return Stack(
      children: [
        Positioned.fill(child: _mapa(context)),
        if (widget.camionReciclajeViewModel != null)
          Positioned(
            top: arribaBotonCamion,
            right: espacioMd,
            child: KeyedSubtree(
              key: widget.camionKey,
              child: _BotonCamion(
                primerUso: _camionVisto == false,
                sinServicio: _camionSinServicio,
                pulso: _pulsoCamion,
                onPressed: _tocarBotonCamion,
              ),
            ),
          ),
        if (widget.camionReciclajeViewModel != null &&
            _camionSinServicio &&
            _globoSinCamionVisible)
          Positioned(
            // Su centro vertical coincide con el del boton (48 de alto con el
            // area tactil); la flecha queda pegada al boton visible.
            top: arribaBotonCamion + 48 / 2,
            right: espacioMd + 48 - espacioXs,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: _GloboSinCamion(
                onTap: () => setState(_cerrarGloboSinCamion),
              ),
            ),
          ),
        if (botonUbicacionVisible)
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

  /// Fraccion del perimetro ya trazada, de 0 a 1; con movimiento reducido
  /// el contorno va completo.
  double _avanceDelTrazo(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return 1;
    return Curves.easeInOut.transform(_trazoZona.value);
  }

  Widget _mapa(BuildContext context) {
    final (centro, zoom) = _centroYZoom(
      widget.puntos,
      widget.centroComuna,
      widget.miUbicacion,
    );
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
            onTap: _alTocarMapa,
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
            // Solo el borde de la zona, sin relleno, trazado de a poco. Los
            // numeros de las calles aparecen cuando la linea llega a cada una;
            // el numero es el mismo de la lista de la hoja. Una calle sin tramo
            // (OSM no la encontro) sigue en la lista, pero no lleva numero.
            if (_contornoZona case final contorno?)
              AnimatedBuilder(
                animation: _trazoZona,
                builder: (context, _) => PolylineLayer(
                  key: const ValueKey('contorno-del-camion'),
                  polylines: [
                    for (final parte in contorno.partes)
                      Polyline(
                        points: parte.recorrido(_avanceDelTrazo(context)),
                        color: colorVerdeLogo,
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
              ),
            if (_contornoZona case final contorno?)
              AnimatedBuilder(
                animation: _trazoZona,
                builder: (context, _) {
                  final avance = _avanceDelTrazo(context);
                  final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
                  return MarkerLayer(
                    key: const ValueKey('numeros-del-camion'),
                    rotate: true,
                    markers: [
                      for (final (i, calle) in contorno.zona.calles.indexed)
                        if (calle.punto case final punto?)
                          if (avance >= contorno.fraccionDeCalle[i]!)
                            Marker(
                              // La key en el Marker evita que la aparicion
                              // se reinicie en cada repintado del mapa.
                              key: Key('numero-calle-${i + 1}'),
                              point: punto,
                              width: 26,
                              height: 26,
                              child: sinAnimaciones
                                  ? _NumeroDeCalle(numero: i + 1)
                                  : TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: 1),
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOut,
                                      builder: (context, progreso, child) => Opacity(
                                        opacity: progreso,
                                        child: Transform.scale(
                                          scale: 0.6 + 0.4 * progreso,
                                          child: child,
                                        ),
                                      ),
                                      child: _NumeroDeCalle(numero: i + 1),
                                    ),
                            ),
                    ],
                  );
                },
              ),
            if (!_hojaCamionAbierta)
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
                        builder: (context, progreso, child) =>
                            Opacity(opacity: progreso, child: child),
                        child: GestureDetector(
                          onTap: () =>
                              widget.onTocarPunto(punto, _miUbicacionEnVivo),
                          child: Image.asset(
                            'assets/branding/icono_marcador.png',
                          ),
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
              MapAttribution(
                key: const ValueKey('atribucion'),
                atribuciones: estilo.attributions,
              ),
          ],
        );
      },
    );
  }
}

/// Verde oscuro del boton del camion, distinto del boton de ubicacion.
const _colorBotonCamion = Color(0xFF2F6B4F);

class _BotonCamion extends StatelessWidget {
  const _BotonCamion({
    required this.primerUso,
    required this.sinServicio,
    required this.pulso,
    required this.onPressed,
  });

  /// Muestra el anillo pulsante y la etiqueta, hasta el primer toque.
  final bool primerUso;

  /// La comuna no tiene camion (404): boton gris, sin anillo ni etiqueta.
  final bool sinServicio;
  final Animation<double> pulso;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (sinServicio) {
      return FloatingActionButton.small(
        key: const Key('boton-camion'),
        heroTag: 'boton-camion',
        shape: const CircleBorder(),
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.grey.shade600,
        tooltip: 'El camión de reciclaje aún no llega a esta comuna',
        onPressed: onPressed,
        child: const Icon(Icons.local_shipping),
      );
    }
    final boton = FloatingActionButton.small(
      key: const Key('boton-camion'),
      heroTag: 'boton-camion',
      shape: const CircleBorder(),
      backgroundColor: _colorBotonCamion,
      foregroundColor: Colors.white,
      tooltip: 'Cuándo pasa el camión de reciclaje',
      onPressed: onPressed,
      child: const Icon(Icons.local_shipping),
    );
    if (!primerUso) return boton;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _EtiquetaCamion(),
        const SizedBox(width: espacioSm),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (!MediaQuery.disableAnimationsOf(context))
              // Fuera del layout (el boton define el tamano): el area tactil
              // mide 48 y el boton visible 40, asi que -2 deja el anillo 6
              // por fuera del boton, como en la maqueta.
              Positioned(
                left: -2,
                top: -2,
                right: -2,
                bottom: -2,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: pulso,
                    builder: (context, _) {
                      // Crece de 0,85 a 1,35 y se desvanece en el primer 80 %
                      // de cada vuelta; el resto queda en pausa.
                      final t = (pulso.value / 0.8).clamp(0.0, 1.0);
                      final curva = Curves.easeOut.transform(t);
                      return Transform.scale(
                        scale: 0.85 + 0.5 * curva,
                        child: Opacity(
                          opacity: 0.7 * (1 - curva),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _colorBotonCamion, width: 2),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            boton,
          ],
        ),
      ],
    );
  }
}

/// Aviso junto al boton gris del camion: la comuna aun no tiene camion.
class _GloboSinCamion extends StatelessWidget {
  const _GloboSinCamion({required this.onTap});

  final VoidCallback onTap;

  static const _fondo = Color(0xFF20281F);
  static const _texto = Color(0xFFF5F1E8);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('globo-sin-camion'),
      onTap: onTap,
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _fondo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping, size: 18, color: _texto),
                  SizedBox(width: espacioSm),
                  Flexible(
                    child: Text(
                      'El camión de reciclaje aún no llega a esta comuna. '
                      '¡Estamos sumando comunas!',
                      style: TextStyle(
                        color: _texto,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Flecha que apunta al boton.
            const CustomPaint(
              size: Size(5, 10),
              painter: _FlechaEtiqueta(_fondo),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaCamion extends StatelessWidget {
  const _EtiquetaCamion();

  static const _fondo = Color(0xFF20281F);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: _fondo,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '¿Cuándo pasa el camión?',
            style: TextStyle(
              color: Color(0xFFF5F1E8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Flecha que apunta al boton.
        const CustomPaint(size: Size(5, 10), painter: _FlechaEtiqueta(_fondo)),
      ],
    );
  }
}

class _FlechaEtiqueta extends CustomPainter {
  const _FlechaEtiqueta(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final flecha = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(flecha, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlechaEtiqueta anterior) => anterior.color != color;
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

/// Reemplaza la barra inferior normal (selector de comuna, radio, filtro)
/// mientras `cuerpo` es `ErrorAlCargar` -- en vez de tapar el mapa con una
/// pantalla de error (que se sentia roto cuando a Render le toma mas de los
/// 3 reintentos automaticos despertar), el mapa queda visible y usable con
/// este boton siempre encima. No desaparece solo ni tiene temporizador: se
/// mantiene hasta que el usuario lo toca, y si el reintento vuelve a fallar
/// simplemente sigue ahi para tocarlo de nuevo.
class _BotonReintentar extends StatelessWidget {
  const _BotonReintentar({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return GlassBar(
      children: [
        FilledButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(
            horizontal: espacioMd,
            vertical: 14,
          ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: espacioMd,
            vertical: 10,
          ),
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
              BotonCerrarHoja(
                key: const Key('cerrar-aviso-sin-resultados'),
                onTap: onCerrar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numero de una calle del camion sobre el mapa: circulo verde de 26 px con
/// borde blanco, como el punto de la misma calle en la hoja.
class _NumeroDeCalle extends StatelessWidget {
  const _NumeroDeCalle({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorVerdeLogo,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$numero',
        // Tamano fijo: el numero tiene que caber en el circulo.
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Contorno de una zona del camion listo para trazarse de a poco.
class _ContornoZona {
  _ContornoZona(this.zona)
    : partes = [
        for (final anillo in zona.poligonos)
          if (anillo.isNotEmpty) _ParteDelContorno(anillo),
      ] {
    for (final (i, calle) in zona.calles.indexed) {
      final punto = calle.punto;
      if (punto == null) continue;
      fraccionDeCalle[i] = _fraccionMasCercana(punto);
    }
  }

  final ZonaRetiro zona;
  final List<_ParteDelContorno> partes;

  /// Por indice de calle: fraccion del perimetro de su parte a partir de la
  /// cual se muestra su numero. Solo calles con `punto`.
  final Map<int, double> fraccionDeCalle = {};

  /// Fraccion del punto del borde mas cercano a `punto`, en la parte cuyo
  /// anillo queda mas cerca.
  double _fraccionMasCercana(LatLng punto) {
    var mejorDistancia = double.infinity;
    var mejorFraccion = 0.0;
    for (final parte in partes) {
      final (distancia, fraccion) = parte.puntoMasCercano(punto);
      if (distancia < mejorDistancia) {
        mejorDistancia = distancia;
        mejorFraccion = fraccion;
      }
    }
    return mejorFraccion;
  }
}

/// Un anillo exterior cerrado con el largo acumulado hasta cada vertice.
/// Mide en grados lat/lng: a la escala de una zona la deformacion no se nota.
class _ParteDelContorno {
  _ParteDelContorno(List<LatLng> anillo)
    : anillo = anillo.first == anillo.last ? anillo : [...anillo, anillo.first] {
    var suma = 0.0;
    acumulado.add(0);
    for (var i = 1; i < this.anillo.length; i++) {
      suma += _distancia(this.anillo[i - 1], this.anillo[i]);
      acumulado.add(suma);
    }
  }

  final List<LatLng> anillo;
  final List<double> acumulado = [];

  double get largo => acumulado.last;

  /// Primeros `avance` (0 a 1) del perimetro, desde el primer punto; el
  /// ultimo punto se interpola dentro de su segmento.
  List<LatLng> recorrido(double avance) {
    if (avance >= 1 || anillo.length < 2) return anillo;
    final objetivo = largo * math.max(avance, 0);
    final puntos = [anillo.first];
    for (var i = 1; i < anillo.length; i++) {
      if (acumulado[i] >= objetivo) {
        final tramo = acumulado[i] - acumulado[i - 1];
        final t = tramo > 0 ? (objetivo - acumulado[i - 1]) / tramo : 0.0;
        puntos.add(_interpolar(anillo[i - 1], anillo[i], t));
        return puntos;
      }
      puntos.add(anillo[i]);
    }
    return puntos;
  }

  /// Distancia de `punto` al borde y fraccion del perimetro donde queda su
  /// proyeccion sobre el segmento mas cercano.
  (double, double) puntoMasCercano(LatLng punto) {
    if (anillo.length < 2 || largo == 0) {
      return (_distancia(anillo.first, punto), 0);
    }
    var mejorDistancia = double.infinity;
    var mejorRecorrido = 0.0;
    for (var i = 1; i < anillo.length; i++) {
      final a = anillo[i - 1];
      final b = anillo[i];
      final dLat = b.latitude - a.latitude;
      final dLng = b.longitude - a.longitude;
      final cuadrado = dLat * dLat + dLng * dLng;
      final t = cuadrado == 0
          ? 0.0
          : (((punto.latitude - a.latitude) * dLat +
                        (punto.longitude - a.longitude) * dLng) /
                    cuadrado)
                .clamp(0.0, 1.0);
      final distancia = _distancia(_interpolar(a, b, t), punto);
      if (distancia < mejorDistancia) {
        mejorDistancia = distancia;
        mejorRecorrido = acumulado[i - 1] + (acumulado[i] - acumulado[i - 1]) * t;
      }
    }
    // clamp: por redondeo la proyeccion al final del ultimo tramo puede pasar
    // de 1 y ese numero no apareceria nunca.
    return (mejorDistancia, (mejorRecorrido / largo).clamp(0.0, 1.0));
  }

  static LatLng _interpolar(LatLng a, LatLng b, double t) => LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );

  static double _distancia(LatLng a, LatLng b) {
    final dLat = b.latitude - a.latitude;
    final dLng = b.longitude - a.longitude;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }
}
