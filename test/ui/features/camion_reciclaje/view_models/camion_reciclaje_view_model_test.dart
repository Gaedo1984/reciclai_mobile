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

  test('abre en el dia de hoy aunque el usuario tenga otro dia', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio(zonaActualId: 'a')),
      DateTime(2026, 11, 19), // jueves
    );
    await vm.abrir(comunaId: '13129');
    expect(vm.estado, isA<CamionListo>());
    expect(vm.diaDelUsuario, 'martes');
    expect(vm.diaSeleccionado, 'jueves');
    expect(vm.diaDeHoy, 'jueves');
  });

  test('si hoy no hay servicio abre en el siguiente dia con servicio', () async {
    final vm = crear(
      ApiClientFalso(servicioRetiro: _servicio(zonaActualId: 'a')),
      DateTime(2026, 11, 20), // viernes
    );
    await vm.abrir(comunaId: '13129');
    expect(vm.diasDelServicio, ['martes', 'jueves', 'sábado']);
    expect(vm.diaSeleccionado, 'sábado');
    expect(vm.diaDeHoy, 'viernes');
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

  test('el domingo sin servicio abre en el primer dia de la semana', () async {
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
    // 17 nov es martes: el siguiente dia con servicio es el miercoles.
    expect(vm.diaSeleccionado, 'miércoles');
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
    expect(vm.diaSeleccionado, 'jueves');
    expect(avisos, 0);
  });

  test('una respuesta vieja no pisa a una mas nueva', () async {
    final api = _ApiClientConCompleters();
    final vm = crear(api, DateTime(2026, 11, 19));
    final a = vm.abrir(comunaId: 'A');
    final b = vm.abrir(comunaId: 'B');
    api.completers[1].complete(_servicio(zonaActualId: 'a'));
    await b;
    expect(vm.diaSeleccionado, 'jueves');
    api.completers[0].complete(null);
    await a;
    expect(vm.estado, isA<CamionListo>());
    expect(vm.diaSeleccionado, 'jueves');
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
    const horarioSabado = 'Entre 8:30 y 12:30 (aprox.)';
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

  group('disponibilidad', () {
    test('empieza desconocida', () {
      final vm = crear(ApiClientFalso(), DateTime(2026, 11, 19));
      expect(vm.disponibilidad, DisponibilidadCamion.desconocida);
    });

    test('consultarDisponibilidad con 404 queda sinServicio', () async {
      final vm = crear(ApiClientFalso(), DateTime(2026, 11, 19));
      await vm.consultarDisponibilidad(comunaId: '13129');
      expect(vm.disponibilidad, DisponibilidadCamion.sinServicio);
    });

    test('con servicio queda conServicio', () async {
      final vm = crear(
        ApiClientFalso(servicioRetiro: _servicio()),
        DateTime(2026, 11, 19),
      );
      await vm.consultarDisponibilidad(comunaId: '13129');
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
    });

    test('con error queda desconocida', () async {
      final vm = crear(
        _ApiClientQueSeRecupera(_servicio()),
        DateTime(2026, 11, 19),
      );
      await vm.consultarDisponibilidad(comunaId: '13129');
      expect(vm.disponibilidad, DisponibilidadCamion.desconocida);
    });

    test('sin comuna ni ubicacion no llama a la API y queda desconocida', () async {
      final api = ApiClientFalso(servicioRetiro: _servicio());
      final vm = crear(api, DateTime(2026, 11, 19));
      await vm.consultarDisponibilidad(comunaId: '13129');
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
      final llamadas = api.vecesLlamadoObtenerServicioRetiro;
      await vm.consultarDisponibilidad();
      expect(vm.disponibilidad, DisponibilidadCamion.desconocida);
      expect(api.vecesLlamadoObtenerServicioRetiro, llamadas);
    });

    test('usa comunaId si vienen ambos', () async {
      final api = ApiClientFalso(servicioRetiro: _servicio());
      final vm = crear(api, DateTime(2026, 11, 19));
      await vm.consultarDisponibilidad(
        comunaId: '13129',
        ubicacion: const LatLng(-33.5, -70.6),
      );
      expect(api.ultimaComunaIdServicioRetiro, '13129');
      expect(api.ultimaUbicacionServicioRetiro, isNull);
    });

    test('con solo ubicacion consulta por ubicacion', () async {
      final api = ApiClientFalso(servicioRetiro: _servicio());
      final vm = crear(api, DateTime(2026, 11, 19));
      await vm.consultarDisponibilidad(ubicacion: const LatLng(-33.5, -70.6));
      expect(api.ultimaComunaIdServicioRetiro, isNull);
      expect(api.ultimaUbicacionServicioRetiro, const LatLng(-33.5, -70.6));
    });

    test('una respuesta vieja se ignora', () async {
      final api = _ApiClientConCompleters();
      final vm = crear(api, DateTime(2026, 11, 19));
      final a = vm.consultarDisponibilidad(comunaId: 'A');
      final b = vm.consultarDisponibilidad(comunaId: 'B');
      api.completers[1].complete(_servicio());
      await b;
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
      api.completers[0].complete(null);
      await a;
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
    });

    test('una respuesta despues de dispose se descarta', () async {
      final api = _ApiClientConCompleters();
      final vm = crear(api, DateTime(2026, 11, 19));
      final futuro = vm.consultarDisponibilidad(comunaId: 'A');
      vm.dispose();
      api.completers[0].complete(_servicio());
      await futuro;
    });

    test('solo notifica cuando el valor cambia', () async {
      final vm = crear(
        ApiClientFalso(servicioRetiro: _servicio()),
        DateTime(2026, 11, 19),
      );
      var avisos = 0;
      vm.addListener(() => avisos++);
      await vm.consultarDisponibilidad(comunaId: '13129');
      // Ya estaba desconocida al empezar: solo avisa el resultado.
      expect(avisos, 1);
    });

    test('una consulta nueva vuelve a desconocida antes de su respuesta', () async {
      final api = _ApiClientConCompleters();
      final vm = crear(api, DateTime(2026, 11, 19));
      final a = vm.consultarDisponibilidad(comunaId: 'A');
      api.completers[0].complete(null);
      await a;
      expect(vm.disponibilidad, DisponibilidadCamion.sinServicio);

      final b = vm.consultarDisponibilidad(comunaId: 'B');

      expect(vm.disponibilidad, DisponibilidadCamion.desconocida);
      api.completers[1].complete(_servicio());
      await b;
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
    });

    test('una consulta previa en vuelo no pisa el resultado de abrir', () async {
      final api = _ApiClientConCompleters();
      final vm = crear(api, DateTime(2026, 11, 19));
      final consulta = vm.consultarDisponibilidad(comunaId: 'A');
      final apertura = vm.abrir(comunaId: 'B');
      api.completers[1].complete(_servicio());
      await apertura;
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);

      api.completers[0].complete(null);
      await consulta;

      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
    });

    test('abrir actualiza disponibilidad', () async {
      final vm = crear(ApiClientFalso(), DateTime(2026, 11, 19));
      await vm.abrir(comunaId: '13129');
      expect(vm.disponibilidad, DisponibilidadCamion.sinServicio);
    });

    test('abrir con servicio queda conServicio y con error no cambia', () async {
      final api = _ApiClientQueSeRecupera(_servicio());
      final vm = crear(api, DateTime(2026, 11, 19));
      await vm.abrir(comunaId: '13129');
      expect(vm.estado, isA<CamionError>());
      expect(vm.disponibilidad, DisponibilidadCamion.desconocida);
      api.fallar = false;
      await vm.reintentar();
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
      api.fallar = true;
      await vm.reintentar();
      expect(vm.estado, isA<CamionError>());
      expect(vm.disponibilidad, DisponibilidadCamion.conServicio);
    });
  });

  group('un solo sector por dia', () {
    /// Cuadrado de lado `lado` grados con esquina suroeste en (lat, lng).
    ZonaRetiro sector(String id, List<String> dias, double lat, double lng, double lado) =>
        ZonaRetiro(
          id: id,
          nombre: 'Sector $id',
          dias: dias,
          calles: const [],
          poligonos: [
            [
              LatLng(lat, lng),
              LatLng(lat, lng + lado),
              LatLng(lat + lado, lng + lado),
              LatLng(lat + lado, lng),
              LatLng(lat, lng),
            ],
          ],
        );

    final norte = sector('norte', ['martes'], -33.40, -70.60, 0.02);
    final sur = sector('sur', ['martes'], -33.60, -70.60, 0.05);
    final otroDia = sector('jueves', ['jueves'], -33.50, -70.60, 0.01);

    test('gana el sector del usuario si tiene el dia', () async {
      final vm = crear(
        ApiClientFalso(
          servicioRetiro: _servicio(zonaActualId: 'norte', zonas: [sur, norte, otroDia]),
        ),
        DateTime(2026, 11, 17),
      );
      await vm.abrir(comunaId: '13129', ubicacion: const LatLng(-33.61, -70.59));
      expect(vm.zonaDelDia?.id, 'norte');
    });

    test('gana el mas cercano si el sector del usuario no tiene el dia', () async {
      final vm = crear(
        ApiClientFalso(
          servicioRetiro: _servicio(zonaActualId: 'jueves', zonas: [sur, norte, otroDia]),
        ),
        DateTime(2026, 11, 17),
      );
      await vm.abrir(comunaId: '13129', ubicacion: const LatLng(-33.39, -70.59));
      vm.seleccionarDia('martes');
      expect(vm.zonaDelDia?.id, 'norte');
    });

    test('gana el mas grande si no hay ubicacion', () async {
      final vm = crear(
        ApiClientFalso(servicioRetiro: _servicio(zonas: [norte, sur, otroDia])),
        DateTime(2026, 11, 17),
      );
      await vm.abrir(comunaId: '13129');
      expect(vm.zonaDelDia?.id, 'sur');
    });

    test('con empate gana el primero de la lista', () async {
      final a = sector('a', ['martes'], -33.40, -70.60, 0.02);
      final b = sector('b', ['martes'], -33.60, -70.60, 0.02);
      final vm = crear(
        ApiClientFalso(servicioRetiro: _servicio(zonas: [a, b])),
        DateTime(2026, 11, 17),
      );
      await vm.abrir(comunaId: '13129');
      expect(vm.zonaDelDia?.id, 'a');
    });

    test('acepta comunaId y ubicacion: consulta por comuna y usa la ubicacion', () async {
      final api = ApiClientFalso(servicioRetiro: _servicio(zonas: [norte, sur]));
      final vm = crear(api, DateTime(2026, 11, 17));
      const ubicacion = LatLng(-33.39, -70.59);
      await vm.abrir(comunaId: '13129', ubicacion: ubicacion);
      expect(api.ultimaComunaIdServicioRetiro, '13129');
      expect(api.ultimaUbicacionServicioRetiro, isNull);
      expect(vm.zonaDelDia?.id, 'norte');

      await vm.reintentar();
      expect(vm.zonaDelDia?.id, 'norte');
    });

    ZonaRetiro cuadrado(String id, double lat, double lng, double lado) =>
        sector(id, ['martes'], lat - lado / 2, lng - lado / 2, lado);

    test('usa el centroide del poligono, no el promedio de sus vertices', () async {
      // Rectangulo con 20 vertices extra sobre el borde poniente: el promedio
      // de vertices queda mucho mas al poniente que el centroide real.
      final denso = ZonaRetiro(
        id: 'denso',
        nombre: 'Sector denso',
        dias: const ['martes'],
        calles: const [],
        poligonos: [
          [
            const LatLng(-33.40, -70.60),
            for (var i = 1; i <= 20; i++) LatLng(-33.40 + i * 0.02 / 21, -70.60),
            const LatLng(-33.38, -70.60),
            const LatLng(-33.38, -70.58),
            const LatLng(-33.40, -70.58),
            const LatLng(-33.40, -70.60),
          ],
        ],
      );
      final chico = cuadrado('chico', -33.39, -70.5965, 0.01);
      final vm = crear(
        ApiClientFalso(servicioRetiro: _servicio(zonas: [chico, denso])),
        DateTime(2026, 11, 17),
      );
      await vm.abrir(comunaId: '13129', ubicacion: const LatLng(-33.39, -70.5930));
      expect(vm.zonaDelDia?.id, 'denso');
    });

    test('la distancia corrige la longitud por la latitud', () async {
      // A -33.5 un grado de longitud mide ~0.83 de uno de latitud: el sector
      // al oriente (0.010 de lng) esta mas cerca que el del norte (0.009 de lat).
      final oriente = cuadrado('oriente', -33.5, -70.59, 0.002);
      final norteCerca = cuadrado('norteCerca', -33.491, -70.60, 0.002);
      final vm = crear(
        ApiClientFalso(servicioRetiro: _servicio(zonas: [norteCerca, oriente])),
        DateTime(2026, 11, 17),
      );
      await vm.abrir(comunaId: '13129', ubicacion: const LatLng(-33.5, -70.60));
      expect(vm.zonaDelDia?.id, 'oriente');
    });
  });
}
