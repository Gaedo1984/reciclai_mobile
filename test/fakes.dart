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
  });

  final LocationPermissionStatus permiso;
  final Position? posicion;
  final Exception? excepcionAlPedirPermiso;
  final Exception? excepcionAlObtenerPosicion;

  /// Si se provee, `obtenerPosicionActual` queda pendiente hasta que el test
  /// complete este Completer — simula una geolocalización lenta para probar
  /// que una selección manual mientras tanto no sea pisada por su resultado tardío.
  final Completer<Position>? completerPosicion;

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
