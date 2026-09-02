import 'dart:async';

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

class ApiClientFalso implements ReciclaiApiClient {
  ApiClientFalso({
    this.comunas = const [],
    this.materiales = const [],
    this.puntosPorComuna = const [],
    this.resultadoCercanos,
    this.excepcion,
  });

  final List<Comuna> comunas;
  final List<Material> materiales;
  final List<RecyclingPoint> puntosPorComuna;
  final PointsNearbyResult? resultadoCercanos;
  final ReciclaiApiException? excepcion;

  int vecesLlamadoObtenerPuntosCercanos = 0;

  @override
  Future<List<Comuna>> obtenerComunas() async {
    if (excepcion != null) throw excepcion!;
    return comunas;
  }

  @override
  Future<List<Material>> obtenerMateriales() async {
    if (excepcion != null) throw excepcion!;
    return materiales;
  }

  @override
  Future<List<RecyclingPoint>> obtenerPuntosPorComuna(String comunaId) async {
    if (excepcion != null) throw excepcion!;
    return puntosPorComuna;
  }

  @override
  Future<PointsNearbyResult> obtenerPuntosCercanos(double lat, double lng) async {
    vecesLlamadoObtenerPuntosCercanos++;
    if (excepcion != null) throw excepcion!;
    return resultadoCercanos!;
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

  @override
  Stream<Position> posicionEnVivo() => streamDePosicion ?? const Stream.empty();
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
