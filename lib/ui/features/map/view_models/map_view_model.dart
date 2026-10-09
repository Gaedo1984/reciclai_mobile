import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/comuna.dart';
import '../../../../data/models/points_nearby_result.dart';
import '../../../../data/reciclai_api_client.dart';
import '../../../../data/reciclai_api_exception.dart';
import '../../../../domain/chile_bounds.dart';
import '../../../../domain/filtro_material.dart';
import '../../../../domain/location_permission_status.dart';
import '../../../../domain/location_service.dart';
import 'map_state.dart';

class MapViewModel extends ChangeNotifier {
  MapViewModel({
    required ReciclaiApiClient apiClient,
    required LocationService locationService,
    DateTime Function()? ahora,
  })  : _apiClient = apiClient,
        _locationService = locationService,
        _ahora = ahora ?? DateTime.now;

  final ReciclaiApiClient _apiClient;
  final LocationService _locationService;
  final DateTime Function() _ahora;

  // 20s x 3 intentos ~= los mismos 60s de espera maxima de siempre, pero
  // repartidos en intentos mas cortos con feedback visible entre medio (ver
  // splash_view.dart), en vez de una sola espera larga y silenciosa.
  static const _timeoutPorIntentoAlAbrir = Duration(seconds: 20);
  static const _maxIntentosAlAbrir = 3;

  // Al cruzar de comuna manejando, los puntos mostrados quedaban
  // desactualizados hasta reabrir la app o tocar algo a mano -- se refrescan
  // solos en segundo plano al moverse, sin tapar el mapa con "Cargando" ni
  // pisar una comuna elegida a mano. 30s acota a como mucho 2 pedidos por
  // minuto al backend mientras se maneja, en los dos modos (comuna y radio).
  static const _intervaloMinimoEntreRecargasPorMovimiento = Duration(seconds: 30);
  StreamSubscription<Position>? _suscripcionPosicion;
  DateTime? _ultimaRecargaPorMovimiento;

  List<Comuna> _comunas = [];
  List<Comuna> get comunas => _comunas;

  String? _comunaSeleccionadaId;
  String? get comunaSeleccionadaId => _comunaSeleccionadaId;

  bool _radioActivo = false;
  bool get radioActivo => _radioActivo;

  /// Verdadero mientras el mapa esta mostrando el resultado de
  /// `buscarEnRadioAmplio()`. Mientras esta activa, la recarga en segundo
  /// plano al moverse (`_recargarPorMovimiento`) se salta -- sin esto, el
  /// primer movimiento despues de 30s reemplazaba en silencio el resultado
  /// ampliado por la carga normal (comuna/radio de 3km), que vuelve a dar
  /// cero puntos con el filtro aplicado. Se desactiva con cualquier accion
  /// explicita que cambie el modo de busqueda: elegir/limpiar comuna,
  /// activar o desactivar el radio de 3km, o tocar el filtro de materiales.
  bool _busquedaAmpliadaActiva = false;
  bool get busquedaAmpliadaActiva => _busquedaAmpliadaActiva;

  /// Mensaje temporal (toast) para cuando el filtro de materiales -- en modo
  /// normal o tras `buscarEnRadioAmplio()` -- sigue sin encontrar ningun
  /// punto. El temporizador de 3s vive aca, no en el widget -- bug real en
  /// un dispositivo real: si el cierre automatico dependia del `State` de
  /// un widget dentro de un `Stack` con varios avisos condicionales
  /// entrando y saliendo, cualquier reconstruccion ajena (otro aviso, una
  /// recarga en segundo plano) podia reiniciar ese `State` -- y con el, el
  /// temporizador -- dejando el aviso sin cerrarse nunca. Un temporizador
  /// de pared aca no depende en absoluto del ciclo de vida de ningun
  /// widget.
  static const _duracionAviso = Duration(seconds: 3);
  static const _mensajeSinResultados = 'No hay puntos cercanos para el filtro indicado';
  static const _mensajeSinResultadosTrasBusquedaAmpliada =
      'No hay puntos cercanos para el filtro indicado. Prueba otros materiales o borra el filtro.';
  String? _avisoSinResultados;
  String? get avisoSinResultados => _avisoSinResultados;
  Timer? _temporizadorAviso;

  void _establecerAviso(String? mensaje) {
    _temporizadorAviso?.cancel();
    _avisoSinResultados = mensaje;
    _temporizadorAviso = mensaje == null ? null : Timer(_duracionAviso, descartarAviso);
  }

  void descartarAviso() {
    _temporizadorAviso?.cancel();
    _temporizadorAviso = null;
    _avisoSinResultados = null;
    notifyListeners();
  }

  /// Centro geográfico de la comuna elegida, para centrar el mapa en ella
  /// aunque todavía no tenga puntos de reciclaje cargados. Null si no hay
  /// comuna elegida o su centro no llegó a cargar en `comunas`.
  LatLng? get centroComunaSeleccionada {
    final comunaSeleccionadaId = _comunaSeleccionadaId;
    if (comunaSeleccionadaId == null) return null;
    for (final comuna in _comunas) {
      if (comuna.id == comunaSeleccionadaId) return comuna.centro;
    }
    return null;
  }

  Map<String, String> _nombresDeMateriales = {};
  Map<String, String> get nombresDeMateriales => _nombresDeMateriales;

  Set<String> _materialesSeleccionados = {};
  Set<String> get materialesSeleccionados => _materialesSeleccionados;

  /// Reemplaza toda la selección de una sola vez — usado al confirmar la hoja
  /// de filtro con el botón "Aplicar", en vez de ir alternando material por
  /// material (que notificaría, y por lo tanto filtraría el mapa, en cada
  /// toque individual mientras el usuario todavía está eligiendo).
  void aplicarFiltroMateriales(Set<String> materiales) {
    _materialesSeleccionados = {...materiales};
    final estabaActiva = _busquedaAmpliadaActiva;
    _busquedaAmpliadaActiva = false;
    _avisoBusquedaAmpliadaDescartado = false;
    // Si la busqueda ampliada estaba activa, `_cuerpo` todavia es el
    // resultado del radio de 15km, no el que va a quedar en pantalla (ver
    // `_recargarTrasApagarBusquedaAmpliada`) -- evaluar el aviso o
    // `mostrarBusquedaAmpliada` contra el ahora mismo eran bugs reales: un
    // material nuevo podia matchear un punto de esa busqueda amplia (que
    // cubre mas terreno) y cancelar el aviso aunque el cuerpo normal sigiera
    // sin encontrar nada; y el boton de 15km podia reaparecer de inmediato
    // (evaluado sincronicamente contra ese mismo cuerpo stale) mientras el
    // aviso recien se actualizaba un instante despues, async -- el boton
    // aparecia antes que el mensaje. Mientras `_recargandoTrasApagarBusquedaAmpliada`
    // es true, ninguno de los dos se evalua con datos viejos: se hace alla,
    // juntos, una vez que el cuerpo fresco esta listo.
    if (estabaActiva) {
      _recargandoTrasApagarBusquedaAmpliada = true;
      _establecerAviso(null);
    } else {
      final cuerpoActual = _cuerpo;
      _establecerAviso(
        materiales.isNotEmpty &&
                cuerpoActual is ConDatos &&
                filtrarPorMateriales(cuerpoActual.puntos, materiales).isEmpty
            ? _mensajeSinResultados
            : null,
      );
    }
    notifyListeners();
    // La busqueda ampliada se acaba de apagar -- sin esto, la pantalla seguia
    // mostrando sus puntos (ya no vigentes para el filtro actual) hasta el
    // proximo movimiento con recarga en segundo plano, en vez de volver de
    // inmediato al punto actual con el filtro ya puesto (aunque quede vacio).
    if (estabaActiva) {
      unawaited(_recargarTrasApagarBusquedaAmpliada());
    }
  }

  /// Ver doc en `aplicarFiltroMateriales` -- mientras es true,
  /// `mostrarBusquedaAmpliada` no se evalua (el cuerpo todavia es el de la
  /// busqueda ampliada, no el que se va a mostrar).
  bool _recargandoTrasApagarBusquedaAmpliada = false;

  Future<void> _recargarTrasApagarBusquedaAmpliada() async {
    final ubicacion = _ultimaPosicionEnVivo ?? miUbicacion;
    if (ubicacion == null) {
      _recargandoTrasApagarBusquedaAmpliada = false;
      return;
    }
    final miOperacion = ++_operacionDeCuerpo;
    try {
      final nuevoCuerpo = await _obtenerCuerpoParaPosicion(ubicacion.latitude, ubicacion.longitude);
      if (miOperacion == _operacionDeCuerpo) {
        _recargandoTrasApagarBusquedaAmpliada = false;
        _establecerAviso(
          _materialesSeleccionados.isNotEmpty &&
                  nuevoCuerpo is ConDatos &&
                  filtrarPorMateriales(nuevoCuerpo.puntos, _materialesSeleccionados).isEmpty
              ? _mensajeSinResultados
              : null,
        );
      }
      _aplicarCuerpo(miOperacion, nuevoCuerpo);
    } on ReciclaiApiException {
      _recargandoTrasApagarBusquedaAmpliada = false;
      // Fallo silencioso, igual que el resto de las recargas en segundo plano.
    }
  }

  /// Radio de la busqueda ampliada cuando el filtro de materiales no
  /// encuentra nada en modo geolocalizacion -- independiente del
  /// `radioActivo` de 3km, que es un origen de datos distinto.
  static const _radioMetrosAmpliado = 15000.0;

  /// El usuario puede cerrar el aviso de busqueda ampliada sin buscar en
  /// 15km (ej. va a probar otro filtro en vez de alejarse) -- `false` no
  /// significa "nunca mostrar", solo "no en esta condicion ya evaluada"; un
  /// nuevo toque al filtro de materiales (u otra accion que cambie el modo
  /// de busqueda) le da una oportunidad nueva, ver donde se reinicia.
  bool _avisoBusquedaAmpliadaDescartado = false;

  void descartarBusquedaAmpliada() {
    _avisoBusquedaAmpliadaDescartado = true;
    notifyListeners();
  }

  /// Derivado, no un campo propio -- se recalcula en cada lectura a partir
  /// del estado ya existente, asi que no hay nada que sincronizar a mano ni
  /// que se pueda desincronizar. Verdadero solo en modo geolocalizacion
  /// (`comunaSeleccionadaId == null`), con al menos un material filtrado,
  /// cuando ese filtro deja la vista actual sin ningun punto, y solo si
  /// todavia no se intento la busqueda ampliada para este filtro -- bug
  /// real reportado por un tester: sin el chequeo de `busquedaAmpliadaActiva`,
  /// el boton (y su X) se quedaban en pantalla despues de tocarlo, aunque la
  /// busqueda de 15km ya se hubiera hecho y no encontrara nada; no habia
  /// ninguna señal de "ya se intento, no ofrecer de nuevo". Un filtro nuevo
  /// (via `aplicarFiltroMateriales`) resetea `busquedaAmpliadaActiva` y le da
  /// una oportunidad nueva. Tambien false si el usuario ya lo descarto para
  /// esta misma condicion.
  bool get mostrarBusquedaAmpliada {
    if (_recargandoTrasApagarBusquedaAmpliada) return false;
    if (_busquedaAmpliadaActiva) return false;
    if (_avisoBusquedaAmpliadaDescartado) return false;
    if (_comunaSeleccionadaId != null) return false;
    if (_materialesSeleccionados.isEmpty) return false;
    final cuerpoActual = _cuerpo;
    if (cuerpoActual is! ConDatos) return false;
    return filtrarPorMateriales(cuerpoActual.puntos, _materialesSeleccionados).isEmpty;
  }

  LocationPermissionStatus? _permiso;
  bool get tienePermisoDeUbicacion => _permiso == LocationPermissionStatus.concedido;

  // Cacheado -- `LocationService.posicionEnVivo()` crea una suscripcion
  // nativa nueva en cada llamada (no es gratis como leer una variable). Antes
  // de la recarga en segundo plano, solo la vista lo llamaba (una vez). Ahora
  // que este viewModel tambien lo necesita para si mismo, sin cachear se
  // crearian dos streams nativos independientes compitiendo por los mismos
  // eventos de ubicacion -- en el dispositivo real, uno de los dos se queda
  // sin datos (bug real: el punto azul y el boton "mi ubicacion" dejaban de
  // aparecer). Cachear asegura que todo el que pida este stream -- la vista o
  // el propio viewModel -- comparta la misma suscripcion nativa.
  Stream<Position>? _posicionEnVivo;
  Stream<Position> get posicionEnVivo => _posicionEnVivo ??= _locationService.posicionEnVivo();

  /// Ultima posicion en vivo recibida, aunque haya llegado antes de que la
  /// vista (el punto azul / boton "mi ubicacion") existiera. Un stream de
  /// broadcast no reproduce eventos pasados a quien se suscribe tarde -- sin
  /// este cache, si la vista se monta despues de que este viewModel ya
  /// consumio el primer tramo de eventos (y el dispositivo no se movio 5m
  /// mas desde entonces), la vista se queda esperando un evento que nunca
  /// llega (bug real en produccion). La vista se siembra con este valor al
  /// montarse y sigue actualizandose sola con el stream en vivo despues.
  LatLng? _ultimaPosicionEnVivo;
  LatLng? get ultimaPosicionEnVivo => _ultimaPosicionEnVivo;

  /// Posición geolocalizada al iniciar, para centrar el mapa ahí en vez de en
  /// los puntos de reciclaje cercanos (que pueden no coincidir exactamente con
  /// la ubicación real). Deja de aplicar apenas se elige una comuna a mano,
  /// para no pisar esa elección.
  LatLng? _miUbicacion;
  LatLng? get miUbicacion => _comunaSeleccionadaId == null ? _miUbicacion : null;

  CuerpoMapaState _cuerpo = const Cargando();
  CuerpoMapaState get cuerpo => _cuerpo;

  // Token de la operación de carga del cuerpo del mapa en curso (geolocalización o
  // selección manual). El selector queda siempre interactivo, así que elegir una
  // comuna a mano mientras la geolocalización todavía está resolviendo es posible —
  // sin esto, un resultado tardío de geolocalización pisaría la elección manual más
  // reciente del usuario. Cada operación de cuerpo se descarta si al terminar ya no
  // es la más nueva.
  int _operacionDeCuerpo = 0;

  Future<void> iniciar() async {
    final miOperacion = ++_operacionDeCuerpo;
    _cuerpo = const Cargando();
    notifyListeners();
    unawaited(_cargarNombresDeMateriales());
    unawaited(_cargarComunas());

    final LocationPermissionStatus permiso;
    try {
      permiso = await _locationService.solicitarPermiso();
    } catch (_) {
      _aplicarCuerpo(
        miOperacion,
        const SinSeleccion(
          mensaje: 'No se pudo acceder a tu ubicación. Elige tu comuna manualmente.',
        ),
      );
      return;
    }
    _permiso = permiso;
    // Suscripcion recien despues de confirmar el permiso, nunca antes -- bug
    // real reportado por un tester en una instalacion nueva: la primera vez
    // que se abre la app, pedir el stream nativo mientras el permiso todavia
    // no esta concedido podia dejarlo sin emitir nunca, aunque el usuario
    // aceptara el permiso un instante despues.
    // ??= -- `reintentar()` puede llamar a `iniciar()` de nuevo sobre el mismo
    // viewModel si la carga inicial fallo; sin esto se suscribiria dos veces
    // al stream y cada movimiento disparado una recarga por duplicado.
    if (permiso == LocationPermissionStatus.concedido) {
      _suscripcionPosicion ??= posicionEnVivo.listen(_alMoverse);
      _ultimaRecargaPorMovimiento ??= _ahora();
    }
    await _cargarSegunPermiso(miOperacion);
  }

  Future<void> alternarRadio(bool activo) async {
    if (_radioActivo == activo) return;
    _radioActivo = activo;
    _busquedaAmpliadaActiva = false;
    _avisoBusquedaAmpliadaDescartado = false;
    if (activo) {
      _comunaSeleccionadaId = null;
    }
    if (_permiso != LocationPermissionStatus.concedido) return;
    final miOperacion = ++_operacionDeCuerpo;
    _cuerpo = const Cargando();
    notifyListeners();
    await _cargarPorGeolocalizacion(miOperacion);
  }

  Future<void> seleccionarComuna(String comunaId) async {
    _radioActivo = false;
    _busquedaAmpliadaActiva = false;
    _avisoBusquedaAmpliadaDescartado = false;
    final miOperacion = ++_operacionDeCuerpo;
    _comunaSeleccionadaId = comunaId;
    _cuerpo = const Cargando();
    notifyListeners();
    try {
      final puntos = await _apiClient.obtenerPuntosPorComuna(comunaId);
      _aplicarCuerpo(miOperacion, ConDatos(puntos));
    } on ReciclaiApiException catch (e) {
      _aplicarCuerpo(miOperacion, ErrorAlCargar(e.message));
    }
  }

  /// Quita la comuna elegida a mano y retoma la ubicación actual — para no
  /// obligar al usuario a volver a buscar su propia comuna solo para "volver"
  /// a donde está parado.
  Future<void> limpiarComuna() async {
    final miOperacion = ++_operacionDeCuerpo;
    _comunaSeleccionadaId = null;
    _busquedaAmpliadaActiva = false;
    _avisoBusquedaAmpliadaDescartado = false;
    _cuerpo = const Cargando();
    notifyListeners();
    await _cargarSegunPermiso(miOperacion);
  }

  Future<void> _cargarSegunPermiso(int miOperacion) async {
    switch (_permiso) {
      case LocationPermissionStatus.concedido:
        await _cargarPorGeolocalizacion(miOperacion);
      case LocationPermissionStatus.denegado:
      case null:
        _aplicarCuerpo(miOperacion, const SinSeleccion());
      case LocationPermissionStatus.denegadoPermanente:
        _aplicarCuerpo(
          miOperacion,
          const SinSeleccion(
            mensaje: 'El permiso de ubicación fue denegado. Puedes habilitarlo en Ajustes, '
                'o elegir tu comuna manualmente.',
          ),
        );
    }
  }

  Future<void> reintentar() {
    final comunaSeleccionadaId = _comunaSeleccionadaId;
    return comunaSeleccionadaId != null ? seleccionarComuna(comunaSeleccionadaId) : iniciar();
  }

  Future<void> _cargarPorGeolocalizacion(int miOperacion) async {
    final Position posicion;
    try {
      posicion = await _locationService.obtenerPosicionActual();
    } catch (_) {
      _aplicarCuerpo(
        miOperacion,
        const SinSeleccion(
          mensaje: 'No se pudo obtener tu ubicación (¿el GPS está activado?). '
              'Elige tu comuna manualmente.',
        ),
      );
      return;
    }
    _miUbicacion = LatLng(posicion.latitude, posicion.longitude);

    if (!estaEnChile(posicion.latitude, posicion.longitude)) {
      _aplicarCuerpo(miOperacion, const FueraDeRango());
      return;
    }

    // Al abrir la app, el backend puede estar "dormido" (plan free de Render) y
    // el primer request tras despertar demora bastante — en vez de una sola
    // espera larga y silenciosa que se siente pegada, se reintenta unas pocas
    // veces con un timeout mas corto por intento: si Render despierta en
    // cualquiera de esos intentos, la app abre sola sin que el usuario tenga
    // que tocar nada. Si los 3 fallan, cae al mismo ErrorAlCargar de siempre
    // (con su boton "Reintentar" manual, sin cambios ahi).
    ReciclaiApiException? ultimoError;
    for (var intento = 1; intento <= _maxIntentosAlAbrir; intento++) {
      if (miOperacion != _operacionDeCuerpo) return;
      try {
        _aplicarCuerpo(
          miOperacion,
          await _obtenerCuerpoParaPosicion(posicion.latitude, posicion.longitude),
        );
        _reintentarCargasSecundariasSiHaceFalta();
        return;
      } on ReciclaiApiException catch (e) {
        ultimoError = e;
      }
    }
    _aplicarCuerpo(miOperacion, ErrorAlCargar(ultimoError!.message));
  }

  Future<CuerpoMapaState> _obtenerCuerpoParaPosicion(double latitud, double longitud) async {
    if (_radioActivo) {
      final puntos = await _apiClient.obtenerPuntosEnRadio(
        latitud,
        longitud,
        timeout: _timeoutPorIntentoAlAbrir,
      );
      return ConDatos(puntos);
    }
    final resultado = await _apiClient.obtenerPuntosCercanos(
      latitud,
      longitud,
      timeout: _timeoutPorIntentoAlAbrir,
    );
    return switch (resultado) {
      Covered(:final puntos) => ConDatos(puntos),
      NotCovered() => const SinSeleccion(
          mensaje: 'Tu ubicación no está cubierta todavía. Elige tu comuna manualmente.',
        ),
    };
  }

  /// Busca puntos en un radio amplio (15km) alrededor de la ultima posicion
  /// conocida, para cuando el filtro de materiales no encuentra nada en el
  /// modo normal (comuna geolocalizada o radio de 3km). Independiente de
  /// `radioActivo` -- no lo lee ni lo modifica. Igual que
  /// `_recargarPorMovimiento`, un fallo de red se ignora en silencio: se
  /// mantienen los puntos que ya habia (y por lo tanto `mostrarBusquedaAmpliada`
  /// sigue en true, el usuario puede volver a intentar tocando el boton de
  /// nuevo).
  Future<void> buscarEnRadioAmplio() async {
    final posicion = _ultimaPosicionEnVivo ?? miUbicacion;
    if (posicion == null) return;
    final miOperacion = ++_operacionDeCuerpo;
    try {
      final puntos = await _apiClient.obtenerPuntosEnRadio(
        posicion.latitude,
        posicion.longitude,
        radioMetros: _radioMetrosAmpliado,
      );
      // Chequeado antes de marcar la bandera -- si mientras tanto una
      // operacion mas nueva ya tomo la posta (ej. el usuario eligio una
      // comuna), `_aplicarCuerpo` va a descartar este resultado de todas
      // formas; no corresponde dejar `_busquedaAmpliadaActiva` en true por
      // un resultado que nunca se aplico.
      if (miOperacion == _operacionDeCuerpo) {
        _busquedaAmpliadaActiva = true;
        // Mensaje distinto (mas largo) al de un filtro normal sin resultados
        // -- aca ya no hay "boton de 15km" que ofrecer (mostrarBusquedaAmpliada
        // ya es false por `busquedaAmpliadaActiva`), asi que el aviso sugiere
        // una salida en vez de repetir lo mismo.
        _establecerAviso(
          filtrarPorMateriales(puntos, _materialesSeleccionados).isEmpty
              ? _mensajeSinResultadosTrasBusquedaAmpliada
              : null,
        );
      }
      _aplicarCuerpo(miOperacion, ConDatos(puntos));
    } on ReciclaiApiException {
      // Fallo silencioso -- ver doc del metodo.
    }
  }

  /// Se llama en cada emision del stream de posicion en vivo (cada ~5m). Solo
  /// actua si no hay una comuna elegida a mano (eso ya significa "quedate
  /// acá") y si no pasaron menos de `_intervaloMinimoEntreRecargasPorMovimiento`
  /// desde la ultima recarga por movimiento.
  void _alMoverse(Position posicion) {
    // Siempre se cachea, incluso con una comuna elegida a mano o fuera del
    // intervalo de recarga -- esto es independiente de si se recargan los
    // puntos, solo registra "donde estoy ahora" para quien llegue tarde al
    // stream (ver doc de `ultimaPosicionEnVivo`).
    _ultimaPosicionEnVivo = LatLng(posicion.latitude, posicion.longitude);
    if (_comunaSeleccionadaId != null) return;
    if (_permiso != LocationPermissionStatus.concedido) return;
    // No se toca `_ultimaRecargaPorMovimiento` aqui (a diferencia del early
    // return de mas abajo) -- asi, apenas se desactive la busqueda ampliada,
    // el proximo movimiento recarga de inmediato en vez de esperar otros 30s.
    if (_busquedaAmpliadaActiva) return;
    final ahora = _ahora();
    final ultima = _ultimaRecargaPorMovimiento;
    if (ultima != null && ahora.difference(ultima) < _intervaloMinimoEntreRecargasPorMovimiento) {
      return;
    }
    _ultimaRecargaPorMovimiento = ahora;
    unawaited(_recargarPorMovimiento(posicion));
  }

  /// A diferencia de `_cargarPorGeolocalizacion`, no pasa por "Cargando" (no
  /// se debe tapar el mapa con un spinner mientras el usuario esta manejando)
  /// ni reintenta ante un fallo -- si no hay señal en ese momento, se
  /// mantienen los puntos ya mostrados y se reintenta solo en el proximo
  /// movimiento.
  Future<void> _recargarPorMovimiento(Position posicion) async {
    final miOperacion = ++_operacionDeCuerpo;
    try {
      final nuevoCuerpo = await _obtenerCuerpoParaPosicion(posicion.latitude, posicion.longitude);
      _aplicarCuerpo(miOperacion, nuevoCuerpo);
    } on ReciclaiApiException {
      // Fallo silencioso -- ver comentario arriba.
    }
  }

  @override
  void dispose() {
    unawaited(_suscripcionPosicion?.cancel());
    _temporizadorAviso?.cancel();
    super.dispose();
  }

  /// Aplica el resultado de una operación de cuerpo solo si sigue siendo la más
  /// reciente — descarta resultados tardíos de operaciones ya reemplazadas.
  void _aplicarCuerpo(int miOperacion, CuerpoMapaState nuevoCuerpo) {
    if (miOperacion != _operacionDeCuerpo) return;
    _cuerpo = nuevoCuerpo;
    notifyListeners();
  }

  // Mismos reintentos que `_cargarPorGeolocalizacion` -- antes, un solo
  // intento fallido mientras Render todavia estaba despertando dejaba el
  // selector de comuna y el filtro de materiales deshabilitados para
  // siempre en esa sesion (sus botones usan `onTap: null` con la lista
  // vacia), aunque el mapa principal terminara cargando bien gracias a sus
  // propios reintentos. Bug real reportado en produccion.
  bool _comunasEnCurso = false;
  bool _materialesEnCurso = false;

  Future<void> _cargarComunas() async {
    _comunasEnCurso = true;
    try {
      for (var intento = 1; intento <= _maxIntentosAlAbrir; intento++) {
        try {
          _comunas = await _apiClient.obtenerComunas(timeout: _timeoutPorIntentoAlAbrir);
          notifyListeners();
          return;
        } catch (_) {
          // El selector queda vacío si los 3 intentos fallan — no bloquea el
          // resto de la pantalla.
        }
      }
    } finally {
      _comunasEnCurso = false;
    }
  }

  Future<void> _cargarNombresDeMateriales() async {
    _materialesEnCurso = true;
    try {
      for (var intento = 1; intento <= _maxIntentosAlAbrir; intento++) {
        try {
          final materiales = await _apiClient.obtenerMateriales(timeout: _timeoutPorIntentoAlAbrir);
          _nombresDeMateriales = {for (final m in materiales) m.codigo: m.nombre};
          notifyListeners();
          return;
        } catch (_) {
          // Es solo una mejora visual (nombres legibles en vez de códigos crudos) —
          // si los 3 intentos fallan, el detalle del punto sigue mostrando los
          // códigos, no bloquea nada.
        }
      }
    } finally {
      _materialesEnCurso = false;
    }
  }

  /// Bug real reportado por un tester: comunas/materiales arrancan antes que
  /// el cuerpo principal (no esperan el permiso de ubicacion), asi que con
  /// Render particularmente lento para despertar pueden agotar sus propios
  /// 3 reintentos justo antes de que el backend responda -- mientras el
  /// cuerpo principal, que "llega" un poco despues, si logra cargar. Sin
  /// esto, el selector de comuna y el filtro de materiales quedaban
  /// deshabilitados para siempre en esa sesion, sin ningun "Reintentar"
  /// visible porque el mapa principal no mostraba error. Se llama justo
  /// despues de que el cuerpo principal confirma que el backend ya
  /// responde -- en ese momento una carga nueva deberia resolver casi de
  /// inmediato. No hace nada si la lista ya llego bien, ni si una tanda de
  /// reintentos propia todavia esta en curso (para no duplicarla).
  void _reintentarCargasSecundariasSiHaceFalta() {
    if (_comunas.isEmpty && !_comunasEnCurso) unawaited(_cargarComunas());
    if (_nombresDeMateriales.isEmpty && !_materialesEnCurso) {
      unawaited(_cargarNombresDeMateriales());
    }
  }
}
