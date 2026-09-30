import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/data/models/material.dart';
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_state.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';

import '../../../../fakes.dart';

const _laFlorida = Comuna(
  id: 'la-florida',
  nombre: 'La Florida',
  region: 'Metropolitana',
  centro: LatLng(-33.50, -70.60),
);

RecyclingPoint _punto() {
  return RecyclingPoint(
    id: '1',
    nombre: 'Punto Limpio',
    direccion: 'Av. Siempre Viva 123',
    ubicacion: const LatLng(-33.52, -70.60),
    tipo: 'punto_limpio',
    materiales: const ['plastico'],
    horario: null,
    esEmpresa: false,
    sitioWeb: null,
    confianza: 'media',
  );
}

void main() {
  test('permiso concedido y comuna cubierta -> ConDatos con los puntos', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
  });

  test('miUbicacion refleja la posicion geolocalizada cuando la geolocalizacion funciona', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(latitude: -33.55, longitude: -70.65),
      ),
    );

    expect(viewModel.miUbicacion, isNull);
    await viewModel.iniciar();

    expect(viewModel.miUbicacion, const LatLng(-33.55, -70.65));
  });

  test('miUbicacion es null si no hubo geolocalizacion', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await viewModel.iniciar();

    expect(viewModel.miUbicacion, isNull);
  });

  test('miUbicacion deja de aplicar despues de elegir una comuna manualmente', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida], resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(latitude: -33.55, longitude: -70.65),
      ),
    );
    await viewModel.iniciar();
    expect(viewModel.miUbicacion, isNotNull);

    await viewModel.seleccionarComuna(_laFlorida.id);

    expect(viewModel.miUbicacion, isNull);
  });

  test('tienePermisoDeUbicacion es true despues de iniciar con permiso concedido', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    expect(viewModel.tienePermisoDeUbicacion, isFalse);
    await viewModel.iniciar();

    expect(viewModel.tienePermisoDeUbicacion, isTrue);
  });

  test('tienePermisoDeUbicacion sigue false si el permiso fue denegado', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await viewModel.iniciar();

    expect(viewModel.tienePermisoDeUbicacion, isFalse);
  });

  test('iniciar carga la lista de comunas para el selector, aunque geolocalizacion funcione', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        comunas: [_laFlorida],
        resultadoCercanos: Covered([_punto()]),
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.comunas, [_laFlorida]);
  });

  test('permiso concedido pero sin cobertura -> SinSeleccion con mensaje', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida], resultadoCercanos: const NotCovered([])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    final estado = viewModel.cuerpo as SinSeleccion;
    expect(estado.mensaje, isNotNull);
    expect(viewModel.comunas, [_laFlorida]);
  });

  test('geolocalizacion fuera de Chile -> FueraDeRango, sin llamar al backend', () async {
    final apiClient = ApiClientFalso(resultadoCercanos: Covered([_punto()]));
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(latitude: -34.60, longitude: -58.38), // Buenos Aires
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<FueraDeRango>());
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 0);
  });

  test('geolocalizacion fuera de Chile igual guarda miUbicacion para centrar el mapa', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(latitude: -34.60, longitude: -58.38),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.miUbicacion, const LatLng(-34.60, -58.38));
  });

  test('permiso denegado (temporal) -> SinSeleccion sin mensaje, via GET /comunas', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida]),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await viewModel.iniciar();

    final estado = viewModel.cuerpo as SinSeleccion;
    expect(estado.mensaje, isNull);
    expect(viewModel.comunas, [_laFlorida]);
  });

  test('permiso denegado permanente -> SinSeleccion con mensaje explicando Ajustes', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: const []),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.denegadoPermanente,
      ),
    );

    await viewModel.iniciar();

    final estado = viewModel.cuerpo as SinSeleccion;
    expect(estado.mensaje, contains('Ajustes'));
  });

  test('error del backend al iniciar -> ErrorAlCargar', () async {
    final apiClient = ApiClientFalso(excepcion: const ReciclaiApiException('fallo simulado'));
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<ErrorAlCargar>());
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 3);
  });

  test(
      'Render "dormido" al abrir: falla 2 veces y al tercer reintento carga bien, sin '
      'que el usuario tenga que tocar nada', () async {
    final apiClient = ApiClientFalso(
      excepcion: const ReciclaiApiException('el backend respondio 502'),
      resultadoCercanos: Covered([_punto()]),
      fallosDeObtenerPuntosCercanosAntesDeExito: 2,
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<ConDatos>());
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 3);
  });

  test('si los 3 reintentos automaticos fallan, cae a ErrorAlCargar con el ultimo mensaje',
      () async {
    final apiClient = ApiClientFalso(
      excepcion: const ReciclaiApiException('el backend respondio 502'),
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<ErrorAlCargar>());
    expect((viewModel.cuerpo as ErrorAlCargar).mensaje, 'el backend respondio 502');
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 3);
  });

  test('reintentar() tras el fallo definitivo dispara una nueva tanda de 3 reintentos',
      () async {
    // Falla las primeras 4 llamadas (agotando los 3 intentos automaticos de la
    // primera tanda) y recien responde bien desde la 5ta — para comprobar que
    // tocar "Reintentar" arranca una tanda nueva completa, no una continuacion.
    final apiClient = ApiClientFalso(
      excepcion: const ReciclaiApiException('el backend respondio 502'),
      resultadoCercanos: Covered([_punto()]),
      fallosDeObtenerPuntosCercanosAntesDeExito: 4,
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    expect(viewModel.cuerpo, isA<ErrorAlCargar>());
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 3);

    await viewModel.reintentar();

    expect(viewModel.cuerpo, isA<ConDatos>());
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 5);
  });

  test('centroComunaSeleccionada es null hasta elegir una comuna', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida]),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await viewModel.iniciar();

    expect(viewModel.centroComunaSeleccionada, isNull);
  });

  test('centroComunaSeleccionada devuelve el centro de la comuna elegida manualmente', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        comunas: [_laFlorida],
        puntosPorComuna: [_punto()],
      ),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await viewModel.iniciar();

    await viewModel.seleccionarComuna(_laFlorida.id);

    expect(viewModel.centroComunaSeleccionada, _laFlorida.centro);
  });

  test('seleccionarComuna reemplaza el estado anterior por completo y guarda la seleccion', () async {
    final apiClient = ApiClientFalso(
      resultadoCercanos: Covered([_punto(), _punto()]),
      puntosPorComuna: [_punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(2));

    await viewModel.seleccionarComuna('san-joaquin');

    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
    expect(viewModel.comunaSeleccionadaId, 'san-joaquin');
  });

  test('reintentar sin comuna elegida vuelve a correr el flujo de iniciar', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.reintentar();

    expect(viewModel.cuerpo, isA<ConDatos>());
  });

  test('reintentar despues de elegir una comuna manualmente reintenta esa comuna', () async {
    final apiClient = ApiClientFalso(puntosPorComuna: [_punto()]);
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await viewModel.seleccionarComuna('san-joaquin');
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));

    await viewModel.reintentar();

    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
    expect(viewModel.comunaSeleccionadaId, 'san-joaquin');
  });

  test(
      'seleccionar una comuna manualmente mientras la geolocalizacion sigue en curso: '
      'la seleccion manual no es pisada cuando la geolocalizacion resuelve despues', () async {
    final completerPosicion = Completer<Position>();
    final apiClient = ApiClientFalso(
      resultadoCercanos: Covered([_punto(), _punto()]),
      puntosPorComuna: [_punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        completerPosicion: completerPosicion,
      ),
    );

    final futuroIniciar = viewModel.iniciar();
    await Future<void>.delayed(Duration.zero);

    await viewModel.seleccionarComuna('san-joaquin');
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));

    completerPosicion.complete(posicionDePrueba());
    await futuroIniciar;

    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
    expect(viewModel.comunaSeleccionadaId, 'san-joaquin');
  });

  test('excepcion al pedir permiso cae a SinSeleccion, no se cuelga', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida]),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        excepcionAlPedirPermiso: Exception('fallo simulado de plataforma'),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<SinSeleccion>());
  });

  test('GPS desactivado (excepcion al obtener posicion) cae a SinSeleccion, no queda en loop', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida]),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        excepcionAlObtenerPosicion: Exception('GPS desactivado simulado'),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<SinSeleccion>());
  });

  test('iniciar carga los nombres de materiales para mostrar en el detalle', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        resultadoCercanos: Covered([_punto()]),
        materiales: [const Material(codigo: 'aceite_usado', nombre: 'Aceite Usado')],
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.nombresDeMateriales['aceite_usado'], 'Aceite Usado');
  });

  test('aplicarFiltroMateriales reemplaza toda la seleccion de una vez y notifica', () {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    viewModel.aplicarFiltroMateriales({'aceite_usado'});
    var notificado = false;
    viewModel.addListener(() => notificado = true);

    viewModel.aplicarFiltroMateriales({'plastico', 'vidrio'});

    expect(viewModel.materialesSeleccionados, {'plastico', 'vidrio'});
    expect(notificado, isTrue);
  });

  test('aplicarFiltroMateriales con un set vacio limpia la seleccion', () {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    viewModel.aplicarFiltroMateriales({'plastico', 'vidrio'});

    viewModel.aplicarFiltroMateriales({});

    expect(viewModel.materialesSeleccionados, isEmpty);
  });

  test(
      'limpiarComuna con permiso concedido vuelve a buscar por la ubicacion actual, '
      'sin exigir que el usuario busque su comuna de nuevo', () async {
    final apiClient = ApiClientFalso(
      comunas: [_laFlorida],
      resultadoCercanos: Covered([_punto()]),
      puntosPorComuna: [_punto(), _punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(latitude: -33.55, longitude: -70.65),
      ),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarComuna(_laFlorida.id);
    expect(viewModel.comunaSeleccionadaId, _laFlorida.id);
    expect(viewModel.miUbicacion, isNull);

    await viewModel.limpiarComuna();

    expect(viewModel.comunaSeleccionadaId, isNull);
    expect(viewModel.miUbicacion, const LatLng(-33.55, -70.65));
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
  });

  test('limpiarComuna sin permiso de ubicacion vuelve a SinSeleccion para elegir manualmente', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(puntosPorComuna: [_punto()]),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await viewModel.seleccionarComuna('san-joaquin');
    expect(viewModel.comunaSeleccionadaId, 'san-joaquin');

    await viewModel.limpiarComuna();

    expect(viewModel.comunaSeleccionadaId, isNull);
    expect(viewModel.cuerpo, isA<SinSeleccion>());
  });

  test('radioActivo arranca en false', () {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    expect(viewModel.radioActivo, isFalse);
  });

  test('alternarRadio(true) con permiso concedido carga puntos por radio', () async {
    final apiClient = ApiClientFalso(
      resultadoEnRadio: [_punto()],
      resultadoCercanos: Covered([]),
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();

    await viewModel.alternarRadio(true);

    expect(viewModel.radioActivo, isTrue);
    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 1);
  });

  test('activar el radio con una comuna elegida la limpia y geolocaliza de nuevo', () async {
    final apiClient = ApiClientFalso(
      comunas: [_laFlorida],
      puntosPorComuna: [_punto()],
      resultadoEnRadio: [_punto(), _punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarComuna('la-florida');
    expect(viewModel.comunaSeleccionadaId, 'la-florida');

    await viewModel.alternarRadio(true);

    expect(viewModel.comunaSeleccionadaId, isNull);
    expect(viewModel.radioActivo, isTrue);
    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(2));
  });

  test('elegir una comuna con el radio activo lo desactiva', () async {
    final apiClient = ApiClientFalso(
      comunas: [_laFlorida],
      puntosPorComuna: [_punto()],
      resultadoEnRadio: [_punto(), _punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    await viewModel.alternarRadio(true);
    expect(viewModel.radioActivo, isTrue);

    await viewModel.seleccionarComuna('la-florida');

    expect(viewModel.radioActivo, isFalse);
    expect(viewModel.comunaSeleccionadaId, 'la-florida');
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
  });

  test('alternarRadio al mismo valor que ya tenia no recarga nada', () async {
    final apiClient = ApiClientFalso(resultadoCercanos: Covered([]));
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);

    await viewModel.alternarRadio(false); // ya esta en false

    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 1); // solo el de iniciar()
  });

  test('alternarRadio(true) sin permiso de ubicacion no intenta nada', () async {
    final apiClient = ApiClientFalso();
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await viewModel.iniciar();

    await viewModel.alternarRadio(true);

    expect(viewModel.radioActivo, isTrue);
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
  });

  test('alternarRadio(true) muestra Cargando de inmediato, antes de esperar la respuesta',
      () async {
    // Sin esto, la pantalla se queda mostrando el contenido viejo (hasta 60s en un
    // Render frio) sin ningun indicio de que el toque se registro -- el mismo
    // problema de "se siente pegada" que ya resolvimos para la apertura de la app,
    // reintroducido acá porque alternarRadio no marcaba Cargando antes de esperar.
    final apiClient = ApiClientFalso(
      resultadoCercanos: Covered([]),
      resultadoEnRadio: [_punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();

    final future = viewModel.alternarRadio(true);
    expect(viewModel.cuerpo, isA<Cargando>());
    await future;

    expect(viewModel.cuerpo, isA<ConDatos>());
  });

  test('el modo radio nunca cae en SinSeleccion por falta de cobertura', () async {
    // NotCovered es un concepto exclusivo del modo comuna -- el endpoint de radio
    // no lo tiene (spec, seccion 1.3). Este test prueba que activar el radio
    // cuando el modo comuna habria dicho "sin cobertura" igual carga bien.
    final apiClient = ApiClientFalso(
      resultadoCercanos: const NotCovered([]),
      resultadoEnRadio: [_punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    expect(viewModel.cuerpo, isA<SinSeleccion>());

    await viewModel.alternarRadio(true);

    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
  });
}
