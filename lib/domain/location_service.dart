import 'package:geolocator/geolocator.dart';

import 'location_permission_status.dart';

LocationPermissionStatus mapearPermiso(LocationPermission permiso) {
  return switch (permiso) {
    LocationPermission.always ||
    LocationPermission.whileInUse =>
      LocationPermissionStatus.concedido,
    LocationPermission.deniedForever => LocationPermissionStatus.denegadoPermanente,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine =>
      LocationPermissionStatus.denegado,
  };
}

class LocationService {
  Future<LocationPermissionStatus> solicitarPermiso() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    return mapearPermiso(permiso);
  }

  Future<Position> obtenerPosicionActual() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }
}
