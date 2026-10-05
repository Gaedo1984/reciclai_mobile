import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/comuna.dart';
import '../../../../data/models/points_nearby_result.dart';
import '../../../../data/reciclai_api_client.dart';
import '../../../../data/reciclai_api_exception.dart';
import '../../../../domain/chile_bounds.dart';
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
    notifyListeners();
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
    // ??= -- `reintentar()` puede llamar a `iniciar()` de nuevo sobre el mismo
    // viewModel si la carga inicial fallo; sin esto se suscribiria dos veces
    // al stream y cada movimiento disparado una recarga por duplicado.
    _suscripcionPosicion ??= posicionEnVivo.listen(_alMoverse);
    _ultimaRecargaPorMovimiento ??= _ahora();

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
    await _cargarSegunPermiso(miOperacion);
  }

  Future<void> alternarRadio(bool activo) async {
    if (_radioActivo == activo) return;
    _radioActivo = activo;
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
        _aplicarCuerpo(miOperacion, await _obtenerCuerpoParaPosicion(posicion));
        return;
      } on ReciclaiApiException catch (e) {
        ultimoError = e;
      }
    }
    _aplicarCuerpo(miOperacion, ErrorAlCargar(ultimoError!.message));
  }

  Future<CuerpoMapaState> _obtenerCuerpoParaPosicion(Position posicion) async {
    if (_radioActivo) {
      final puntos = await _apiClient.obtenerPuntosEnRadio(
        posicion.latitude,
        posicion.longitude,
        timeout: _timeoutPorIntentoAlAbrir,
      );
      return ConDatos(puntos);
    }
    final resultado = await _apiClient.obtenerPuntosCercanos(
      posicion.latitude,
      posicion.longitude,
      timeout: _timeoutPorIntentoAlAbrir,
    );
    return switch (resultado) {
      Covered(:final puntos) => ConDatos(puntos),
      NotCovered() => const SinSeleccion(
          mensaje: 'Tu ubicación no está cubierta todavía. Elige tu comuna manualmente.',
        ),
    };
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
      final nuevoCuerpo = await _obtenerCuerpoParaPosicion(posicion);
      _aplicarCuerpo(miOperacion, nuevoCuerpo);
    } on ReciclaiApiException {
      // Fallo silencioso -- ver comentario arriba.
    }
  }

  @override
  void dispose() {
    unawaited(_suscripcionPosicion?.cancel());
    super.dispose();
  }

  /// Aplica el resultado de una operación de cuerpo solo si sigue siendo la más
  /// reciente — descarta resultados tardíos de operaciones ya reemplazadas.
  void _aplicarCuerpo(int miOperacion, CuerpoMapaState nuevoCuerpo) {
    if (miOperacion != _operacionDeCuerpo) return;
    _cuerpo = nuevoCuerpo;
    notifyListeners();
  }

  Future<void> _cargarComunas() async {
    try {
      _comunas = await _apiClient.obtenerComunas();
      notifyListeners();
    } catch (_) {
      // El selector queda vacío si falla — no bloquea el resto de la pantalla.
    }
  }

  Future<void> _cargarNombresDeMateriales() async {
    try {
      final materiales = await _apiClient.obtenerMateriales();
      _nombresDeMateriales = {for (final m in materiales) m.codigo: m.nombre};
      notifyListeners();
    } catch (_) {
      // Es solo una mejora visual (nombres legibles en vez de códigos crudos) — si
      // falla, el detalle del punto sigue mostrando los códigos, no bloquea nada.
    }
  }
}
