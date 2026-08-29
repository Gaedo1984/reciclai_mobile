import 'package:flutter/foundation.dart';

import '../../../../data/models/points_nearby_result.dart';
import '../../../../data/reciclai_api_client.dart';
import '../../../../data/reciclai_api_exception.dart';
import '../../../../domain/location_permission_status.dart';
import '../../../../domain/location_service.dart';
import 'map_state.dart';

class MapViewModel extends ChangeNotifier {
  MapViewModel({required ReciclaiApiClient apiClient, required LocationService locationService})
      : _apiClient = apiClient,
        _locationService = locationService;

  final ReciclaiApiClient _apiClient;
  final LocationService _locationService;

  MapState _state = const Cargando();
  MapState get state => _state;

  Future<void> iniciar() async {
    _state = const Cargando();
    notifyListeners();

    final permiso = await _locationService.solicitarPermiso();
    switch (permiso) {
      case LocationPermissionStatus.concedido:
        await _cargarPorGeolocalizacion();
      case LocationPermissionStatus.denegado:
        await _cargarSelectorDeComunas();
      case LocationPermissionStatus.denegadoPermanente:
        await _cargarSelectorDeComunas(
          mensaje: 'El permiso de ubicación fue denegado. Podés habilitarlo en Ajustes, '
              'o elegir tu comuna manualmente.',
        );
    }
  }

  Future<void> seleccionarComuna(String comunaId) async {
    _state = const Cargando();
    notifyListeners();
    try {
      final puntos = await _apiClient.obtenerPuntosPorComuna(comunaId);
      _state = ConDatos(puntos);
    } on ReciclaiApiException catch (e) {
      _state = ErrorAlCargar(e.message);
    }
    notifyListeners();
  }

  Future<void> reintentar() => iniciar();

  Future<void> _cargarPorGeolocalizacion() async {
    try {
      final posicion = await _locationService.obtenerPosicionActual();
      final resultado = await _apiClient.obtenerPuntosCercanos(
        posicion.latitude,
        posicion.longitude,
      );
      _state = switch (resultado) {
        Covered(:final puntos) => ConDatos(puntos),
        NotCovered(:final comunasDisponibles) => RequierePicker(
            comunasDisponibles,
            mensaje: 'Tu ubicación no está cubierta todavía. Elegí tu comuna manualmente.',
          ),
      };
    } on ReciclaiApiException catch (e) {
      _state = ErrorAlCargar(e.message);
    } catch (e) {
      _state = ErrorAlCargar('no se pudo obtener tu ubicación: $e');
    }
    notifyListeners();
  }

  Future<void> _cargarSelectorDeComunas({String? mensaje}) async {
    try {
      final comunas = await _apiClient.obtenerComunas();
      _state = RequierePicker(comunas, mensaje: mensaje);
    } on ReciclaiApiException catch (e) {
      _state = ErrorAlCargar(e.message);
    }
    notifyListeners();
  }
}
