import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/data/models/material.dart';
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/data/reciclai_api_client.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/domain/location_service.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class ApiClientFalso implements ReciclaiApiClient {
  ApiClientFalso({
    this.comunas = const [],
    this.materiales = const [],
    this.puntosPorComuna = const [],
    this.resultadoCercanos = const Covered([]),
    this.excepcion,
    this.fallosDeObtenerPuntosCercanosAntesDeExito = 0,
    this.resultadoEnRadio = const [],
    this.resultadoCercanosPorLlamada,
    this.resultadoEnRadioPorLlamada,
    this.completerPuntosPorComuna,
    this.fallosDeObtenerComunasAntesDeExito = 0,
    this.fallosDeObtenerMaterialesAntesDeExito = 0,
  });

  final List<Comuna> comunas;
  final List<Material> materiales;
  final List<RecyclingPoint> puntosPorComuna;
  final PointsNearbyResult resultadoCercanos;
  final List<RecyclingPoint> resultadoEnRadio;
  final ReciclaiApiException? excepcion;

  /// Si se provee, cada llamada a `obtenerPuntosCercanos` usa este callback en
  /// vez de `resultadoCercanos` -- recibe el numero de llamada (1, 2, 3...) y
  /// puede devolver un resultado distinto por llamada, o lanzar una excepcion.
  /// Para simular que una recarga por movimiento (cruzar de comuna manejando)
  /// trae un resultado distinto al de la carga inicial, o que falla en
  /// silencio sin afectar lo ya cargado.
  final PointsNearbyResult Function(int numeroDeLlamada)? resultadoCercanosPorLlamada;

  /// Igual que `resultadoCercanosPorLlamada`, para `obtenerPuntosEnRadio`.
  final List<RecyclingPoint> Function(int numeroDeLlamada)? resultadoEnRadioPorLlamada;

  /// Si se provee, `obtenerPuntosPorComuna` queda pendiente hasta que el test
  /// complete este Completer -- para poder inspeccionar el estado `Cargando`
  /// intermedio antes de que la recarga termine (misma idea que
  /// `completerPosicion`).
  final Completer<List<RecyclingPoint>>? completerPuntosPorComuna;

  /// Cuántas veces `obtenerPuntosCercanos` debe fallar (con `excepcion`, o un
  /// error genérico si no se proveyó una) antes de responder con éxito — para
  /// simular un Render que despierta recién al segundo o tercer intento. En 0
  /// (default), el comportamiento es el de siempre: si `excepcion` está seteada,
  /// siempre falla.
  final int fallosDeObtenerPuntosCercanosAntesDeExito;

  /// Igual que `fallosDeObtenerPuntosCercanosAntesDeExito`, para
  /// `obtenerComunas`/`obtenerMateriales` -- simula que Render tambien tarda
  /// en responder a estas dos llamadas "best effort" mientras despierta.
  final int fallosDeObtenerComunasAntesDeExito;
  final int fallosDeObtenerMaterialesAntesDeExito;

  int vecesLlamadoObtenerPuntosCercanos = 0;
  int vecesLlamadoObtenerPuntosEnRadio = 0;
  int vecesLlamadoObtenerComunas = 0;
  int vecesLlamadoObtenerMateriales = 0;

  /// Ultimo `radioMetros` recibido por `obtenerPuntosEnRadio` -- `null` si la
  /// ultima llamada no lo paso. Usado para verificar con que radio se llamo
  /// (ej. la busqueda ampliada de 15000m).
  double? ultimoRadioMetrosPedido;

  @override
  Future<List<Comuna>> obtenerComunas({Duration? timeout}) async {
    vecesLlamadoObtenerComunas++;
    final debeFallar = fallosDeObtenerComunasAntesDeExito > 0
        ? vecesLlamadoObtenerComunas <= fallosDeObtenerComunasAntesDeExito
        : excepcion != null;
    if (debeFallar) throw excepcion ?? const ReciclaiApiException('fallo simulado');
    return comunas;
  }

  @override
  Future<List<Material>> obtenerMateriales({Duration? timeout}) async {
    vecesLlamadoObtenerMateriales++;
    final debeFallar = fallosDeObtenerMaterialesAntesDeExito > 0
        ? vecesLlamadoObtenerMateriales <= fallosDeObtenerMaterialesAntesDeExito
        : excepcion != null;
    if (debeFallar) throw excepcion ?? const ReciclaiApiException('fallo simulado');
    return materiales;
  }

  @override
  Future<List<RecyclingPoint>> obtenerPuntosPorComuna(String comunaId) async {
    if (completerPuntosPorComuna != null) return completerPuntosPorComuna!.future;
    if (excepcion != null) throw excepcion!;
    return puntosPorComuna;
  }

  @override
  Future<PointsNearbyResult> obtenerPuntosCercanos(
    double lat,
    double lng, {
    Duration? timeout,
  }) async {
    vecesLlamadoObtenerPuntosCercanos++;
    final porLlamada = resultadoCercanosPorLlamada;
    if (porLlamada != null) return porLlamada(vecesLlamadoObtenerPuntosCercanos);
    final debeFallar = fallosDeObtenerPuntosCercanosAntesDeExito > 0
        ? vecesLlamadoObtenerPuntosCercanos <= fallosDeObtenerPuntosCercanosAntesDeExito
        : excepcion != null;
    if (debeFallar) throw excepcion ?? const ReciclaiApiException('fallo simulado');
    return resultadoCercanos;
  }

  @override
  Future<List<RecyclingPoint>> obtenerPuntosEnRadio(
    double lat,
    double lng, {
    Duration? timeout,
    double? radioMetros,
  }) async {
    vecesLlamadoObtenerPuntosEnRadio++;
    ultimoRadioMetrosPedido = radioMetros;
    final porLlamada = resultadoEnRadioPorLlamada;
    if (porLlamada != null) return porLlamada(vecesLlamadoObtenerPuntosEnRadio);
    if (excepcion != null) throw excepcion!;
    return resultadoEnRadio;
  }
}

class LocationServiceFalsa implements LocationService {
  LocationServiceFalsa({
    required this.permiso,
    this.posicion,
    this.excepcionAlPedirPermiso,
    this.excepcionAlObtenerPosicion,
    this.completerPosicion,
    this.streamDePosicion,
  });

  final LocationPermissionStatus permiso;
  final Position? posicion;
  final Exception? excepcionAlPedirPermiso;
  final Exception? excepcionAlObtenerPosicion;

  /// Si se provee, `obtenerPosicionActual` queda pendiente hasta que el test
  /// complete este Completer — simula una geolocalización lenta para probar
  /// que una selección manual mientras tanto no sea pisada por su resultado tardío.
  final Completer<Position>? completerPosicion;

  /// Si se provee, `posicionEnVivo` emite desde este stream en vez del vacío
  /// por defecto — para simular actualizaciones de ubicación en vivo. Debe
  /// ser un `StreamController.broadcast()` si el test va a tener más de un
  /// widget escuchándolo a la vez (igual que el stream real de Geolocator).
  final Stream<Position>? streamDePosicion;

  @override
  Future<LocationPermissionStatus> solicitarPermiso() async {
    if (excepcionAlPedirPermiso != null) throw excepcionAlPedirPermiso!;
    return permiso;
  }

  @override
  Future<Position> obtenerPosicionActual() async {
    if (completerPosicion != null) return completerPosicion!.future;
    if (excepcionAlObtenerPosicion != null) throw excepcionAlObtenerPosicion!;
    return posicion!;
  }

  /// Cuantas veces se llamo `posicionEnVivo()` -- el plugin real crea una
  /// suscripcion nativa nueva en cada llamada, asi que mas de una llamada en
  /// la app real significa mas de un stream de ubicacion nativo compitiendo
  /// por los mismos eventos (bug real visto en produccion: el stream del
  /// viewModel "robaba" los eventos del stream de la vista, y el punto azul
  /// dejaba de aparecer). Este fake devuelve siempre el mismo stream sin
  /// importar cuantas veces se llame, asi que no reproduce ese sintoma por si
  /// solo -- este contador es lo que permite pinearlo en un test.
  int vecesLlamadoPosicionEnVivo = 0;

  @override
  Stream<Position> posicionEnVivo() {
    vecesLlamadoPosicionEnVivo++;
    return streamDePosicion ?? const Stream.empty();
  }
}

/// Reemplaza el canal de plataforma de `url_launcher` en los tests — registra
/// cada URL que se intentó lanzar en vez de invocar de verdad un navegador o
/// app externa (que no existe en el entorno de test).
class UrlLauncherPlatformFalso extends UrlLauncherPlatform {
  final List<String> urlsLanzadas = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    urlsLanzadas.add(url);
    return true;
  }
}

/// Reemplaza `VideoPlayerPlatform.instance` en los tests — sin esto,
/// `VideoPlayerController.asset(...).initialize()` lanza `UnimplementedError`
/// de inmediato (no hay implementacion nativa real en `flutter test`).
/// Al reproducir (`play`), deja la posicion en el final de una vez — el
/// controller la lee via un timer periodico real (100ms), asi que un solo
/// `tester.pump(Duration(milliseconds: 150))` alcanza para que detecte que
/// el video ya completo una vuelta.
class VideoPlayerPlatformFalso extends VideoPlayerPlatform {
  VideoPlayerPlatformFalso({
    this.duracion = const Duration(seconds: 1),
    this.tamano = const Size(720, 1280),
  });

  final Duration duracion;
  final Size tamano;

  int _proximoPlayerId = 0;
  final Map<int, StreamController<VideoEvent>> _eventosPorPlayer = {};
  final Map<int, Duration> _posicionPorPlayer = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    await _eventosPorPlayer.remove(playerId)?.close();
    _posicionPorPlayer.remove(playerId);
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _proximoPlayerId++;
    late final StreamController<VideoEvent> controlador;
    // El evento "initialized" se agrega recien cuando alguien se suscribe
    // (onListen), no al crear el controller: con un microtask a secas, el
    // evento podia emitirse en un stream broadcast todavia sin oyentes (el
    // caller recien se suscribe despues de que este Future resuelve) y se
    // perdia para siempre.
    controlador = StreamController<VideoEvent>.broadcast(
      onListen: () {
        controlador.add(
          VideoEvent(eventType: VideoEventType.initialized, duration: duracion, size: tamano),
        );
      },
    );
    _eventosPorPlayer[playerId] = controlador;
    _posicionPorPlayer[playerId] = Duration.zero;
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _eventosPorPlayer[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    _posicionPorPlayer[playerId] = duracion;
  }

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _posicionPorPlayer[playerId] = position;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => _posicionPorPlayer[playerId] ?? Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.shrink();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleep,
  ) async {}
}

Position posicionDePrueba({double latitude = -33.52, double longitude = -70.60}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
