import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/data/models/material.dart';
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/domain/filtro_material.dart';
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

  test(
      'sin permiso concedido (denegado), nunca se suscribe al stream de posicion en vivo',
      () async {
    // Suscribirse al stream ANTES de que el permiso se resuelva es lo que
    // causo un bug real reportado por un tester en una instalacion nueva: la
    // primera vez que se abre la app, el permiso todavia no esta concedido
    // en el momento en que arranca `iniciar()` -- si el stream nativo se
    // pide en ese instante, puede quedar sin emitir nunca aunque el usuario
    // conceda el permiso un segundo despues.
    final locationService = LocationServiceFalsa(
      permiso: LocationPermissionStatus.denegado,
      streamDePosicion: const Stream.empty(),
    );
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: locationService,
    );

    await viewModel.iniciar();

    expect(locationService.vecesLlamadoPosicionEnVivo, 0);
  });

  test(
      'el stream de posicion en vivo del LocationService se crea una sola vez, aunque se '
      'acceda tanto desde iniciar() (recarga en segundo plano) como desde la vista '
      '(punto azul / boton "mi ubicacion")', () async {
    final locationService = LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
      streamDePosicion: const Stream.empty(),
    );
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: locationService,
    );

    await viewModel.iniciar();
    // Simula lo que hace la vista: accede al getter para armar el punto azul
    // y el boton "mi ubicacion" -- si cada acceso dispara otra llamada a
    // `posicionEnVivo()`, en el dispositivo real cada una crea su propia
    // suscripcion nativa, y solo una de ellas recibe eventos.
    viewModel.posicionEnVivo;
    viewModel.posicionEnVivo;

    expect(locationService.vecesLlamadoPosicionEnVivo, 1);
  });

  group('recarga en segundo plano al moverse (cruzar de comuna manejando)', () {
    RecyclingPoint puntoB() {
      return RecyclingPoint(
        id: '2',
        nombre: 'Punto Limpio B',
        direccion: 'Otra direccion 456',
        ubicacion: const LatLng(-33.60, -70.70),
        tipo: 'punto_limpio',
        materiales: const ['vidrio'],
        horario: null,
        esEmpresa: false,
        sitioWeb: null,
        confianza: 'media',
      );
    }

    test(
        'pasado el intervalo minimo, moverse recarga los puntos de la nueva posicion y '
        'reemplaza los anteriores', () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        resultadoCercanosPorLlamada: (n) => n == 1 ? Covered([_punto()]) : Covered([puntoB()]),
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
          streamDePosicion: controlador.stream,
        ),
        ahora: () => reloj,
      );

      await viewModel.iniciar();
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);

      reloj = reloj.add(const Duration(seconds: 31));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
    });

    test('antes de pasar el intervalo minimo, moverse no dispara otra recarga', () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        resultadoCercanosPorLlamada: (n) => n == 1 ? Covered([_punto()]) : Covered([puntoB()]),
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
          streamDePosicion: controlador.stream,
        ),
        ahora: () => reloj,
      );

      await viewModel.iniciar();

      reloj = reloj.add(const Duration(seconds: 10));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);
      expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 1);
    });

    test('con una comuna elegida a mano, moverse no dispara ninguna recarga', () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        puntosPorComuna: [_punto()],
        resultadoCercanosPorLlamada: (_) => Covered([puntoB()]),
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
          streamDePosicion: controlador.stream,
        ),
        ahora: () => reloj,
      );

      await viewModel.iniciar();
      await viewModel.seleccionarComuna('la-florida');
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);

      reloj = reloj.add(const Duration(seconds: 31));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);
      // La unica llamada contada es la de `iniciar()` (geolocalizacion, antes
      // de elegir la comuna a mano) -- el movimiento posterior no suma otra.
      expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 1);
    });

    test('en modo radio de 3km, moverse tambien recarga los puntos del radio', () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        resultadoEnRadio: [_punto()],
        resultadoEnRadioPorLlamada: (n) => n == 1 ? [_punto()] : [puntoB()],
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
          streamDePosicion: controlador.stream,
        ),
        ahora: () => reloj,
      );

      await viewModel.iniciar();
      await viewModel.alternarRadio(true);
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);

      reloj = reloj.add(const Duration(seconds: 31));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
    });

    test('la recarga por movimiento nunca pasa por el estado Cargando', () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        resultadoCercanosPorLlamada: (n) => n == 1 ? Covered([_punto()]) : Covered([puntoB()]),
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
          streamDePosicion: controlador.stream,
        ),
        ahora: () => reloj,
      );
      await viewModel.iniciar();

      final estadosVistos = <CuerpoMapaState>[];
      viewModel.addListener(() => estadosVistos.add(viewModel.cuerpo));

      reloj = reloj.add(const Duration(seconds: 31));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(estadosVistos, isNot(contains(isA<Cargando>())));
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
    });

    test(
        'si la recarga por movimiento falla (ej. sin señal), se mantienen los puntos '
        'anteriores sin mostrar error', () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        resultadoCercanosPorLlamada: (n) {
          if (n == 1) return Covered([_punto()]);
          throw const ReciclaiApiException('sin señal');
        },
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
          streamDePosicion: controlador.stream,
        ),
        ahora: () => reloj,
      );
      await viewModel.iniciar();

      reloj = reloj.add(const Duration(seconds: 31));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);
    });
  });

  group('resiliencia de comunas/materiales ante un Render que tarda en despertar', () {
    // Bug real: cuando Render esta dormido, la carga principal del mapa
    // reintenta (ver _cargarPorGeolocalizacion) y termina funcionando -- pero
    // `_cargarComunas`/`_cargarNombresDeMateriales` solo lo intentaban una
    // vez, en el mismo instante en que Render todavia estaba despertando. Si
    // esa unica llamada fallaba, el selector de comuna y el filtro de
    // materiales quedaban deshabilitados para siempre en esa sesion (sus
    // botones usan `onTap: null` cuando la lista esta vacia), aunque el mapa
    // principal hubiera cargado bien.
    test('la carga de comunas reintenta y termina poblando el selector', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([_punto()]),
        comunas: [_laFlorida],
        fallosDeObtenerComunasAntesDeExito: 2,
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );

      await viewModel.iniciar();
      // _cargarComunas() es "fire and forget" (unawaited) -- hay que dejar
      // que sus reintentos internos terminen antes de revisar el resultado.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(viewModel.comunas, isNotEmpty);
      expect(apiClient.vecesLlamadoObtenerComunas, 3);
    });

    test('la carga de materiales reintenta y termina poblando el catalogo', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([_punto()]),
        materiales: const [Material(codigo: 'plastico', nombre: 'Plástico')],
        fallosDeObtenerMaterialesAntesDeExito: 2,
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );

      await viewModel.iniciar();
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(viewModel.nombresDeMateriales, isNotEmpty);
      expect(apiClient.vecesLlamadoObtenerMateriales, 3);
    });
  });

  group('busqueda ampliada cuando el filtro de materiales no encuentra nada', () {
    RecyclingPoint puntoConMaterial(String id, String material) {
      return RecyclingPoint(
        id: id,
        nombre: 'Punto $id',
        direccion: 'Direccion $id',
        ubicacion: const LatLng(-33.52, -70.60),
        tipo: 'punto_limpio',
        materiales: [material],
        horario: null,
        esEmpresa: false,
        sitioWeb: null,
        confianza: 'media',
      );
    }

    test('no aparece sin ningun material seleccionado', () async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();

      expect(viewModel.mostrarBusquedaAmpliada, isFalse);
    });

    test('no aparece si el filtro de materiales si encuentra puntos', () async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'plastico'});

      expect(viewModel.mostrarBusquedaAmpliada, isFalse);
    });

    test('no aparece con una comuna elegida a mano, aunque el filtro de cero', () async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(
          comunas: [_laFlorida],
          puntosPorComuna: [puntoConMaterial('1', 'plastico')],
        ),
        locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
      );
      await viewModel.iniciar();
      await viewModel.seleccionarComuna('la-florida');
      viewModel.aplicarFiltroMateriales({'vidrio'});

      expect(viewModel.mostrarBusquedaAmpliada, isFalse);
    });

    test('aparece en modo geolocalizacion con filtro activo y cero resultados', () async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'vidrio'});

      expect(viewModel.mostrarBusquedaAmpliada, isTrue);
    });

    test('buscarEnRadioAmplio pide el radio de 15km alrededor de la ultima posicion conocida',
        () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(latitude: -33.50, longitude: -70.60),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'vidrio'});
      expect(viewModel.mostrarBusquedaAmpliada, isTrue);

      await viewModel.buscarEnRadioAmplio();

      expect(apiClient.ultimoRadioMetrosPedido, 15000.0);
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
    });

    test('despues de buscarEnRadioAmplio con resultados, mostrarBusquedaAmpliada pasa a falso',
        () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'vidrio'});

      await viewModel.buscarEnRadioAmplio();

      expect(viewModel.mostrarBusquedaAmpliada, isFalse);
    });

    test('buscarEnRadioAmplio mantiene el filtro de materiales sobre el resultado ampliado',
        () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'vidrio'), puntoConMaterial('3', 'plastico')],
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'vidrio'});

      await viewModel.buscarEnRadioAmplio();

      final puntosFiltrados = filtrarPorMateriales(
        (viewModel.cuerpo as ConDatos).puntos,
        viewModel.materialesSeleccionados,
      );
      expect(puntosFiltrados.map((p) => p.id), ['2']);
    });

    test('si buscarEnRadioAmplio falla, se mantienen los puntos anteriores sin mostrar error',
        () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadioPorLlamada: (_) => throw const ReciclaiApiException('sin señal'),
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'vidrio'});

      await viewModel.buscarEnRadioAmplio();

      expect(viewModel.cuerpo, isA<ConDatos>());
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);
      expect(viewModel.mostrarBusquedaAmpliada, isTrue);
    });

    test('activar el radio de 3km no interfiere con la busqueda ampliada ni viceversa', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'vidrio'});

      await viewModel.buscarEnRadioAmplio();

      expect(viewModel.radioActivo, isFalse);
    });

    test('buscarEnRadioAmplio funciona igual con el radio de 3km ya activo de antes', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        // La primera llamada a obtenerPuntosEnRadio (el radio de 3km via
        // alternarRadio) no debe traer 'vidrio' todavia -- si no, el filtro ya
        // encontraria algo antes de llamar a buscarEnRadioAmplio y el test no
        // probaria lo que dice probar.
        resultadoEnRadioPorLlamada: (n) =>
            n == 1 ? [puntoConMaterial('3km', 'plastico')] : [puntoConMaterial('2', 'vidrio')],
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
      viewModel.aplicarFiltroMateriales({'vidrio'});
      expect(viewModel.mostrarBusquedaAmpliada, isTrue);

      await viewModel.buscarEnRadioAmplio();

      expect(apiClient.ultimoRadioMetrosPedido, 15000.0);
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
      expect(viewModel.radioActivo, isTrue);
    });

    test('buscarEnRadioAmplio sin ninguna posicion conocida no falla ni llama al API', () async {
      final apiClient = ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]));
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
      );
      await viewModel.iniciar();

      await viewModel.buscarEnRadioAmplio();

      expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
    });
  });
}
