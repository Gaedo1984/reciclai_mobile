import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/servicio_retiro.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/ui/features/camion_reciclaje/view_models/camion_reciclaje_view_model.dart';

import '../../../../fakes.dart';

ZonaRetiro _zona(String id, List<String> dias) => ZonaRetiro(
  id: id,
  nombre: 'Zona $id',
  dias: dias,
  calles: const [],
  poligonos: const [],
);

ServicioRetiro _servicio({String? zonaActualId, List<ZonaRetiro>? zonas}) =>
    ServicioRetiro(
      comunaId: '13129',
      comunaNombre: 'San Joaquín',
      horario: '09:00 a 13:00',
      materiales: const ['Plástico'],
      fuenteNombre: 'Municipalidad de San Joaquín',
      actualizado: DateTime(2026, 11, 1),
      zonaActualId: zonaActualId,
      zonas: zonas ?? [_zona('a', ['martes']), _zona('b', ['jueves', 'sábado'])],
    );

/// Falla las primeras `fallos` llamadas y despues responde `servicioRetiro`.
class _ApiClientQueSeRecupera extends ApiClientFalso {
  _ApiClientQueSeRecupera(ServicioRetiro servicio)
    : super(servicioRetiro: servicio);

  bool fallar = true;

  @override
  Future<ServicioRetiro?> obtenerServicioRetiro({
    String? comunaId,
    LatLng? ubicacion,
  }) async {
    if (fallar) {
      vecesLlamadoObtenerServicioRetiro++;
      throw const ReciclaiApiException('sin red');
    }
    return super.obtenerServicioRetiro(comunaId: comunaId, ubicacion: ubicacion);
  }
}

void main() {
  CamionReciclajeViewModel crear(ApiClientFalso api, DateTime ahora) =>
      CamionReciclajeViewModel(apiClient: api, ahora: () => ahora);

  test('abre en el dia de la zona actual', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio(zonaActualId: 'a')),
      DateTime(2026, 11, 19),
    );
    await vm.abrir(comunaId: '13129');
    expect(vm.estado, isA<CamionListo>());
    expect(vm.diaDelUsuario, 'martes');
    expect(vm.diaSeleccionado, 'martes');
  });

  test('abre en el dia de hoy si no hay zona actual', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio()),
      DateTime(2026, 11, 19), // jueves
    );
    await vm.abrir(comunaId: '13129');
    expect(vm.diaDelUsuario, isNull);
    expect(vm.diaSeleccionado, 'jueves');
    expect(vm.zonaDelDia?.id, 'b');
  });

  test('si hoy no hay servicio abre en el primer dia', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio()),
      DateTime(2026, 11, 22), // domingo
    );
    await vm.abrir(comunaId: '13129');
    expect(vm.diasDelServicio, ['martes', 'jueves', 'sábado']);
    expect(vm.diaSeleccionado, 'martes');
  });

  test('diasDelServicio va en orden de lunes a domingo', () async {
    final vm = crear(
      ApiClientFalso(
        servicioRetiro: _servicio(
          zonas: [_zona('a', ['domingo', 'lunes']), _zona('b', ['miércoles'])],
        ),
      ),
      DateTime(2026, 11, 17),
    );
    await vm.abrir(comunaId: '13129');
    expect(vm.diasDelServicio, ['lunes', 'miércoles', 'domingo']);
    expect(vm.diaSeleccionado, 'lunes');
  });

  test('seleccionarDia cambia zonaDelDia y notifica', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio(zonaActualId: 'a')),
      DateTime(2026, 11, 19),
    );
    await vm.abrir(comunaId: '13129');
    var avisos = 0;
    vm.addListener(() => avisos++);
    vm.seleccionarDia('sábado');
    expect(vm.diaSeleccionado, 'sábado');
    expect(vm.zonaDelDia?.id, 'b');
    expect(avisos, 1);
  });

  test('sin servicio', () async {
    final vm = crear(ApiClientFalso(), DateTime(2026, 11, 19));
    await vm.abrir(comunaId: '13129');
    expect(vm.estado, isA<CamionSinServicio>());
    expect(vm.diaSeleccionado, isNull);
    expect(vm.zonaDelDia, isNull);
    expect(vm.diasDelServicio, isEmpty);
  });

  test('error de red y reintentar', () async {
    final api = _ApiClientQueSeRecupera(_servicio());
    final vm = crear(api, DateTime(2026, 11, 19));
    await vm.abrir(comunaId: '13129');
    expect(vm.estado, isA<CamionError>());

    api.fallar = false;
    await vm.reintentar();
    expect(vm.estado, isA<CamionListo>());
    expect(api.ultimaComunaIdServicioRetiro, '13129');
  });

  test('estado es CamionCargando mientras la llamada esta en vuelo', () async {
    final completer = Completer<ServicioRetiro?>();
    final vm = crear(
      ApiClientFalso(completerServicioRetiro: completer),
      DateTime(2026, 11, 19),
    );
    final futuro = vm.abrir(comunaId: '13129');
    expect(vm.estado, isA<CamionCargando>());
    completer.complete(_servicio());
    await futuro;
    expect(vm.estado, isA<CamionListo>());
  });

  test('comunaId tiene prioridad sobre ubicacion', () async {
    final api = ApiClientFalso(servicioRetiro: _servicio());
    final vm = crear(api, DateTime(2026, 11, 19));
    await vm.abrir(comunaId: '13129', ubicacion: const LatLng(-33.5, -70.6));
    expect(api.ultimaComunaIdServicioRetiro, '13129');
    expect(api.ultimaUbicacionServicioRetiro, isNull);
  });

  test('con solo ubicacion consulta por ubicacion', () async {
    final api = ApiClientFalso(servicioRetiro: _servicio());
    final vm = crear(api, DateTime(2026, 11, 19));
    await vm.abrir(ubicacion: const LatLng(-33.5, -70.6));
    expect(api.ultimaComunaIdServicioRetiro, isNull);
    expect(api.ultimaUbicacionServicioRetiro, const LatLng(-33.5, -70.6));
  });
}
