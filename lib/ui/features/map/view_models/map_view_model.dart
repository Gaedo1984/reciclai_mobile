import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/comuna.dart';
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

  List<Comuna> _comunas = [];
  List<Comuna> get comunas => _comunas;

  String? _comunaSeleccionadaId;
  String? get comunaSeleccionadaId => _comunaSeleccionadaId;

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

  LocationPermissionStatus? _permiso;
  bool get tienePermisoDeUbicacion => _permiso == LocationPermissionStatus.concedido;

  Stream<Position> get posicionEnVivo => _locationService.posicionEnVivo();

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
    switch (permiso) {
      case LocationPermissionStatus.concedido:
        await _cargarPorGeolocalizacion(miOperacion);
      case LocationPermissionStatus.denegado:
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

  Future<void> seleccionarComuna(String comunaId) async {
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

    try {
      final resultado = await _apiClient.obtenerPuntosCercanos(
        posicion.latitude,
        posicion.longitude,
      );
      _aplicarCuerpo(
        miOperacion,
        switch (resultado) {
          Covered(:final puntos) => ConDatos(puntos),
          NotCovered() => const SinSeleccion(
              mensaje: 'Tu ubicación no está cubierta todavía. Elige tu comuna manualmente.',
            ),
        },
      );
    } on ReciclaiApiException catch (e) {
      _aplicarCuerpo(miOperacion, ErrorAlCargar(e.message));
    }
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
