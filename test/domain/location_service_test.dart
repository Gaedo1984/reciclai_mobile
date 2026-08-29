import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/domain/location_service.dart';

void main() {
  test('always y whileInUse mapean a concedido', () {
    expect(mapearPermiso(LocationPermission.always), LocationPermissionStatus.concedido);
    expect(mapearPermiso(LocationPermission.whileInUse), LocationPermissionStatus.concedido);
  });

  test('deniedForever mapea a denegadoPermanente', () {
    expect(
      mapearPermiso(LocationPermission.deniedForever),
      LocationPermissionStatus.denegadoPermanente,
    );
  });

  test('denied y unableToDetermine mapean a denegado', () {
    expect(mapearPermiso(LocationPermission.denied), LocationPermissionStatus.denegado);
    expect(
      mapearPermiso(LocationPermission.unableToDetermine),
      LocationPermissionStatus.denegado,
    );
  });
}
