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

/// Cada llamada queda pendiente de su propio Completer, en orden.
class _ApiClientConCompleters extends ApiClientFalso {
  final completers = <Completer<ServicioRetiro?>>[];

  @override
  Future<ServicioRetiro?> obtenerServicioRetiro({
    String? comunaId,
    LatLng? ubicacion,
  }) {
    final completer = Completer<ServicioRetiro?>();
    completers.add(completer);
    return completer.future;
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

  test('zonaDelDia prefiere la zona del usuario si comparte el dia', () async {
    final vm = crear(
      ApiClientFalso(
        servicioRetiro: _servicio(
          zonaActualId: 'b',
          zonas: [_zona('a', ['martes']), _zona('b', ['lunes', 'martes'])],
        ),
      ),
      DateTime(2026, 11, 19),
    );
    await vm.abrir(comunaId: '13129');
    vm.seleccionarDia('martes');
    expect(vm.zonaDelDia?.id, 'b');
    expect(vm.diaEsDelUsuario, isTrue);
  });

  test('diaEsDelUsuario es falso en un dia de otra zona', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio(zonaActualId: 'b')),
      DateTime(2026, 11, 19),
    );
    await vm.abrir(comunaId: '13129');
    // Sabado es el segundo dia de la zona del usuario, no solo el primero.
    vm.seleccionarDia('sábado');
    expect(vm.diaEsDelUsuario, isTrue);
    vm.seleccionarDia('martes');
    expect(vm.zonaDelDia?.id, 'a');
    expect(vm.diaEsDelUsuario, isFalse);
  });

  test('diaEsDelUsuario es falso sin zona actual', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio()),
      DateTime(2026, 11, 19),
    );
    await vm.abrir(comunaId: '13129');
    expect(vm.diaEsDelUsuario, isFalse);
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

  test('seleccionarDia ignora dias sin servicio', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio(zonaActualId: 'a')),
      DateTime(2026, 11, 19),
    );
    await vm.abrir(comunaId: '13129');
    var avisos = 0;
    vm.addListener(() => avisos++);
    vm.seleccionarDia('lunes');
    vm.seleccionarDia('no es un dia');
    expect(vm.diaSeleccionado, 'martes');
    expect(avisos, 0);
  });

  test('una respuesta vieja no pisa a una mas nueva', () async {
    final api = _ApiClientConCompleters();
    final vm = crear(api, DateTime(2026, 11, 19));
    final a = vm.abrir(comunaId: 'A');
    final b = vm.abrir(comunaId: 'B');
    api.completers[1].complete(_servicio(zonaActualId: 'a'));
    await b;
    expect(vm.diaSeleccionado, 'martes');
    api.completers[0].complete(null);
    await a;
    expect(vm.estado, isA<CamionListo>());
    expect(vm.diaSeleccionado, 'martes');
  });

  test('un error viejo no pisa a una respuesta mas nueva', () async {
    final api = _ApiClientConCompleters();
    final vm = crear(api, DateTime(2026, 11, 19));
    final a = vm.abrir(comunaId: 'A');
    final b = vm.abrir(comunaId: 'B');
    api.completers[1].complete(_servicio());
    await b;
    api.completers[0].completeError(const ReciclaiApiException('tarde'));
    await a;
    expect(vm.estado, isA<CamionListo>());
  });

  test('completar una llamada despues de dispose no lanza', () async {
    final api = _ApiClientConCompleters();
    final vm = crear(api, DateTime(2026, 11, 19));
    final futuro = vm.abrir(comunaId: 'A');
    vm.dispose();
    api.completers[0].complete(_servicio());
    await futuro;

    final vm2 = crear(api, DateTime(2026, 11, 19));
    final futuro2 = vm2.abrir(comunaId: 'A');
    vm2.dispose();
    api.completers[1].completeError(const ReciclaiApiException('x'));
    await futuro2;
  });

  test('horarioDelDia usa el horario de la zona si lo trae, si no el del servicio', () async {
    const horarioSabado = 'El camión pasa entre 8:30 y 12:30 (aprox.)';
    final vm = crear(
      ApiClientFalso(
        servicioRetiro: _servicio(
          zonas: [
            _zona('a', ['martes']),
            const ZonaRetiro(
              id: 'sab',
              nombre: 'Zona sábado',
              dias: ['sábado'],
              calles: [],
              poligonos: [],
              horario: horarioSabado,
            ),
          ],
        ),
      ),
      DateTime(2026, 11, 17), // martes
    );
    expect(vm.horarioDelDia, isNull);

    await vm.abrir(comunaId: '13129');
    expect(vm.diaSeleccionado, 'martes');
    expect(vm.horarioDelDia, '09:00 a 13:00');

    vm.seleccionarDia('sábado');
    expect(vm.horarioDelDia, horarioSabado);
  });
}
