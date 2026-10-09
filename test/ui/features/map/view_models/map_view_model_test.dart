import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

    // Bug real reportado por un tester: con Render particularmente lento,
    // la carga de comunas/materiales (que arranca antes, sin esperar el
    // permiso de ubicacion) agotaba sus 3 reintentos justo antes de que
    // Render terminara de despertar, mientras la carga principal del mapa
    // (que arranca despues, y por lo tanto "llega" cuando Render ya estaba
    // casi listo) si lograba cargar. El selector de comuna y el filtro de
    // materiales quedaban deshabilitados para siempre en esa sesion, sin
    // ningun "Reintentar" visible porque el mapa principal no mostraba error.
    test(
        'si comunas agota sus reintentos mientras el mapa principal sigue esperando la '
        'posicion, pero el mapa despues si logra cargar, se le da una oportunidad mas a '
        'comunas', () async {
      final completerPosicion = Completer<Position>();
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([_punto()]),
        comunas: [_laFlorida],
        fallosDeObtenerComunasAntesDeExito: 4,
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          completerPosicion: completerPosicion,
        ),
      );

      final futuroIniciar = viewModel.iniciar();
      // Deja que la primera tanda de comunas (3 intentos, todos fallidos)
      // termine del todo mientras el mapa principal sigue trabado esperando
      // la posicion (el completer no se completa todavia).
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(apiClient.vecesLlamadoObtenerComunas, 3);
      expect(viewModel.comunas, isEmpty);

      completerPosicion.complete(posicionDePrueba());
      await futuroIniciar;
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(viewModel.comunas, isNotEmpty);
      expect(apiClient.vecesLlamadoObtenerComunas, 5);
    });

    test(
        'si materiales agota sus reintentos mientras el mapa principal sigue esperando la '
        'posicion, pero el mapa despues si logra cargar, se le da una oportunidad mas a '
        'materiales', () async {
      final completerPosicion = Completer<Position>();
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([_punto()]),
        materiales: const [Material(codigo: 'plastico', nombre: 'Plástico')],
        fallosDeObtenerMaterialesAntesDeExito: 4,
      );
      final viewModel = MapViewModel(
        apiClient: apiClient,
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          completerPosicion: completerPosicion,
        ),
      );

      final futuroIniciar = viewModel.iniciar();
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(apiClient.vecesLlamadoObtenerMateriales, 3);
      expect(viewModel.nombresDeMateriales, isEmpty);

      completerPosicion.complete(posicionDePrueba());
      await futuroIniciar;
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(viewModel.nombresDeMateriales, isNotEmpty);
      expect(apiClient.vecesLlamadoObtenerMateriales, 5);
    });

    test(
        'si comunas ya cargo bien en la primera tanda, el mapa principal no dispara una '
        'segunda tanda de mas', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([_punto()]),
        comunas: [_laFlorida],
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

      expect(apiClient.vecesLlamadoObtenerComunas, 1);
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

    test('buscarEnRadioAmplio exitoso deja busquedaAmpliadaActiva en true', () async {
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

      expect(viewModel.busquedaAmpliadaActiva, isTrue);
    });

    // Bug real reportado por un tester: el boton "Buscar en 15 km" (y su X)
    // se quedaba en pantalla despues de tocarlo, aunque la busqueda ampliada
    // ya se hubiera hecho y no encontrara nada -- no habia ninguna señal de
    // "ya se intento, no ofrecer de nuevo". `mostrarBusquedaAmpliada` ahora
    // tambien chequea `busquedaAmpliadaActiva`.
    test(
        'una vez que buscarEnRadioAmplio ya se intento (sin encontrar nada), '
        'mostrarBusquedaAmpliada deja de ofrecerse', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'plastico')],
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
      expect(viewModel.mostrarBusquedaAmpliada, isTrue);

      await viewModel.buscarEnRadioAmplio();

      expect(viewModel.mostrarBusquedaAmpliada, isFalse);
    });

    test(
        'un nuevo filtro sin resultados (normal, sin ampliar) vuelve a ofrecer '
        'mostrarBusquedaAmpliada, aunque el anterior ya se haya intentado', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'plastico')],
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

      viewModel.aplicarFiltroMateriales({'carton'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.mostrarBusquedaAmpliada, isTrue);
    });

    test(
        'mientras la busqueda ampliada esta activa, moverse no la reemplaza con la recarga normal',
        () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        // La recarga normal (comuna/geolocalizacion) trae un punto sin
        // 'vidrio' -- si el movimiento la aplicara, el resultado ampliado se
        // perderia y el test lo detectaria.
        resultadoCercanosPorLlamada: (_) => Covered([puntoConMaterial('normal', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
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
      viewModel.aplicarFiltroMateriales({'vidrio'});
      await viewModel.buscarEnRadioAmplio();
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);

      reloj = reloj.add(const Duration(seconds: 31));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
    });

    test('aplicarFiltroMateriales desactiva busquedaAmpliadaActiva (vuelve a recargar normal)',
        () async {
      final controlador = StreamController<Position>.broadcast();
      addTearDown(controlador.close);
      var reloj = DateTime(2026, 1, 1, 12, 0, 0);
      final apiClient = ApiClientFalso(
        resultadoCercanosPorLlamada: (_) => Covered([puntoConMaterial('normal', 'vidrio')]),
        resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
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
      viewModel.aplicarFiltroMateriales({'vidrio'});
      await viewModel.buscarEnRadioAmplio();
      expect(viewModel.busquedaAmpliadaActiva, isTrue);

      viewModel.aplicarFiltroMateriales({'vidrio'});
      expect(viewModel.busquedaAmpliadaActiva, isFalse);

      reloj = reloj.add(const Duration(seconds: 31));
      controlador.add(posicionDePrueba(latitude: -33.60, longitude: -70.70));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['normal']);
    });

    test(
        'descartarBusquedaAmpliada oculta el aviso sin tocar el filtro -- a lo mejor el '
        'usuario no quiere buscar en 15km', () async {
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

      viewModel.descartarBusquedaAmpliada();

      expect(viewModel.mostrarBusquedaAmpliada, isFalse);
    });

    test(
        'descartarBusquedaAmpliada no desactiva el filtro de materiales ni dispara una '
        'busqueda', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
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

      viewModel.descartarBusquedaAmpliada();

      expect(viewModel.materialesSeleccionados, {'vidrio'});
      expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
    });

    test(
        'un nuevo toque al filtro de materiales le da otra oportunidad al aviso de '
        'busqueda ampliada, aunque el anterior se haya descartado', () async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();
      viewModel.aplicarFiltroMateriales({'vidrio'});
      viewModel.descartarBusquedaAmpliada();
      expect(viewModel.mostrarBusquedaAmpliada, isFalse);

      viewModel.aplicarFiltroMateriales({'carton'});

      expect(viewModel.mostrarBusquedaAmpliada, isTrue);
    });

    test('seleccionarComuna desactiva busquedaAmpliadaActiva', () async {
      final apiClient = ApiClientFalso(
        comunas: [_laFlorida],
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
        puntosPorComuna: [puntoConMaterial('3', 'vidrio')],
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
      expect(viewModel.busquedaAmpliadaActiva, isTrue);

      await viewModel.seleccionarComuna('la-florida');

      expect(viewModel.busquedaAmpliadaActiva, isFalse);
    });

    test(
        'al apagar la busqueda ampliada (nuevo toque al filtro), recarga de inmediato el '
        'cuerpo normal sin esperar un movimiento', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanosPorLlamada: (_) => Covered([puntoConMaterial('normal', 'vidrio')]),
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
      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);

      viewModel.aplicarFiltroMateriales({'vidrio'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['normal']);
    });

    test(
        'al apagar la busqueda ampliada, recarga igual aunque el nuevo cuerpo quede sin '
        'puntos con el filtro puesto', () async {
      final apiClient = ApiClientFalso(
        // Sin 'vidrio' -- el filtro sigue puesto, pero el cuerpo normal no trae nada.
        resultadoCercanosPorLlamada: (_) => Covered([puntoConMaterial('normal', 'plastico')]),
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

      viewModel.aplicarFiltroMateriales({'vidrio'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['normal']);
      expect(
        filtrarPorMateriales((viewModel.cuerpo as ConDatos).puntos, viewModel.materialesSeleccionados),
        isEmpty,
      );
    });
  });

  group('aviso de "sin resultados" para el filtro de materiales', () {
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

    test('avisoSinResultados arranca en null', () {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(),
        locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
      );

      expect(viewModel.avisoSinResultados, isNull);
    });

    test(
        'aplicarFiltroMateriales en modo comuna sin resultados muestra el aviso de '
        '"sin puntos cercanos"', () async {
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

      expect(viewModel.avisoSinResultados, 'No hay puntos cercanos para el filtro indicado');
    });

    test('aplicarFiltroMateriales que si encuentra puntos no muestra el aviso', () async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(
          comunas: [_laFlorida],
          puntosPorComuna: [puntoConMaterial('1', 'plastico')],
        ),
        locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
      );
      await viewModel.iniciar();
      await viewModel.seleccionarComuna('la-florida');

      viewModel.aplicarFiltroMateriales({'plastico'});

      expect(viewModel.avisoSinResultados, isNull);
    });

    test('limpiar el filtro de materiales (set vacio) no muestra el aviso', () async {
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
      expect(viewModel.avisoSinResultados, isNotNull);

      viewModel.aplicarFiltroMateriales({});

      expect(viewModel.avisoSinResultados, isNull);
    });

    test(
        'buscarEnRadioAmplio que sigue sin encontrar nada con el filtro muestra el mismo '
        'aviso', () async {
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'plastico')],
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

      // Mensaje distinto (mas largo) al de un filtro normal sin resultados --
      // aca ya no hay "boton de 15km" que ofrecer, asi que el aviso debe
      // sugerir una salida (otro filtro, o borrarlo).
      expect(
        viewModel.avisoSinResultados,
        'No hay puntos cercanos para el filtro indicado. Prueba otros materiales o borra el filtro.',
      );
    });

    test('buscarEnRadioAmplio que si encuentra algo con el filtro no muestra el aviso', () async {
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

      expect(viewModel.avisoSinResultados, isNull);
    });

    test('descartarAviso limpia el aviso y notifica', () async {
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
      expect(viewModel.avisoSinResultados, isNotNull);
      var notificado = false;
      viewModel.addListener(() => notificado = true);

      viewModel.descartarAviso();

      expect(viewModel.avisoSinResultados, isNull);
      expect(notificado, isTrue);
    });

    // El temporizador de 3s vive en el ViewModel, no en el widget -- un bug
    // real reportado en un dispositivo real era que el aviso nunca
    // desaparecia (ni mostraba la X) cuando el temporizador vivia en el
    // widget: cualquier reconstruccion del arbol (otro aviso condicional del
    // mismo Stack entrando/saliendo, una recarga en segundo plano, etc.)
    // podia reiniciar su `State` y, con el, el temporizador. Un temporizador
    // de pared en el ViewModel no depende en absoluto del ciclo de vida de
    // ningun widget.
    test('el aviso se cierra solo a los 3 segundos, sin que la vista haga nada', () {
      fakeAsync((async) {
        final viewModel = MapViewModel(
          apiClient: ApiClientFalso(
            comunas: [_laFlorida],
            puntosPorComuna: [puntoConMaterial('1', 'plastico')],
          ),
          locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
        );
        unawaited(viewModel.iniciar());
        async.flushMicrotasks();
        unawaited(viewModel.seleccionarComuna('la-florida'));
        async.flushMicrotasks();
        viewModel.aplicarFiltroMateriales({'vidrio'});
        expect(viewModel.avisoSinResultados, isNotNull);

        async.elapse(const Duration(seconds: 2));
        expect(viewModel.avisoSinResultados, isNotNull);

        async.elapse(const Duration(seconds: 2));
        expect(viewModel.avisoSinResultados, isNull);
      });
    });

    test(
        'si se establece un aviso nuevo antes de que termine el anterior, el plazo de 3 '
        'segundos se reinicia (no se corta a mitad de camino)', () {
      fakeAsync((async) {
        final viewModel = MapViewModel(
          apiClient: ApiClientFalso(
            comunas: [_laFlorida],
            puntosPorComuna: [puntoConMaterial('1', 'plastico')],
          ),
          locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
        );
        unawaited(viewModel.iniciar());
        async.flushMicrotasks();
        unawaited(viewModel.seleccionarComuna('la-florida'));
        async.flushMicrotasks();
        viewModel.aplicarFiltroMateriales({'vidrio'});

        async.elapse(const Duration(seconds: 2));
        viewModel.aplicarFiltroMateriales({'vidrio'});
        async.elapse(const Duration(seconds: 2));

        expect(viewModel.avisoSinResultados, isNotNull);
      });
    });

    test(
        'aplicar un segundo filtro distinto, tambien sin resultados, mantiene el aviso '
        'visible', () async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
        locationService: LocationServiceFalsa(
          permiso: LocationPermissionStatus.concedido,
          posicion: posicionDePrueba(),
        ),
      );
      await viewModel.iniciar();

      viewModel.aplicarFiltroMateriales({'vidrio'});
      expect(viewModel.avisoSinResultados, isNotNull, reason: 'primer filtro');

      viewModel.aplicarFiltroMateriales({'carton'});
      expect(viewModel.avisoSinResultados, isNotNull, reason: 'segundo filtro');
    });

    // Bug real reportado por un tester: despues de usar buscarEnRadioAmplio()
    // (que si encontro un punto con el filtro viejo, en un radio mas amplio),
    // agregar otro material -- tambien sin resultados en el radio normal --
    // no mostraba el aviso. Causa: `aplicarFiltroMateriales` evaluaba el
    // aviso contra `_cuerpo`, que en ese instante todavia era el resultado
    // de los 15km (el nuevo material matcheaba ahi, en un radio mas amplio),
    // no el cuerpo normal recien recargado que llega despues, en segundo
    // plano.
    test(
        'tras apagar la busqueda ampliada, el aviso se evalua contra el cuerpo normal '
        'recargado -- no contra el cuerpo (mas amplio) que estaba vigente', () async {
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
      expect(viewModel.avisoSinResultados, isNull, reason: 'la busqueda ampliada si encontro vidrio');

      viewModel.aplicarFiltroMateriales({'vidrio', 'carton'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // El cuerpo normal (el punto '1', plastico) no matchea ni 'vidrio' ni
      // 'carton' -- el aviso deberia aparecer.
      expect(viewModel.avisoSinResultados, isNotNull);
    });

    // Bug real reportado por un tester: al aplicar un filtro nuevo justo
    // despues de haber usado buscarEnRadioAmplio(), el boton de 15km
    // reaparecia de inmediato (mostrarBusquedaAmpliada se evalua en forma
    // sincronica contra el cuerpo -- todavia el de la busqueda ampliada,
    // stale -- de la recarga previa), mientras el aviso (toast) recien se
    // actualiza async, un instante despues, cuando el cuerpo fresco llega.
    // El boton aparecia antes que el mensaje, en vez de los dos juntos.
    test(
        'mientras se recarga el cuerpo tras apagar la busqueda ampliada, '
        'mostrarBusquedaAmpliada no se adelanta (no aparece sin el aviso)', () async {
      final completerCercanos = Completer<PointsNearbyResult>();
      final apiClient = ApiClientFalso(
        resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
        resultadoEnRadio: [puntoConMaterial('2', 'plastico')],
        completerCercanosDesdeLaSegundaLlamada: completerCercanos,
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
      expect(viewModel.busquedaAmpliadaActiva, isTrue);

      viewModel.aplicarFiltroMateriales({'carton'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // La recarga sigue pendiente (el completer no se resolvio todavia) --
      // ni el boton ni un aviso stale deberian mostrarse en este instante.
      expect(viewModel.mostrarBusquedaAmpliada, isFalse);
      expect(viewModel.avisoSinResultados, isNull);

      completerCercanos.complete(Covered([puntoConMaterial('1', 'plastico')]));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Recien ahora, los dos juntos (el cuerpo fresco sigue sin 'carton').
      expect(viewModel.mostrarBusquedaAmpliada, isTrue);
      expect(viewModel.avisoSinResultados, isNotNull);
    });

    test('descartarAviso cancela el temporizador pendiente (no vuelve a notificar despues)', () {
      fakeAsync((async) {
        final viewModel = MapViewModel(
          apiClient: ApiClientFalso(
            comunas: [_laFlorida],
            puntosPorComuna: [puntoConMaterial('1', 'plastico')],
          ),
          locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
        );
        unawaited(viewModel.iniciar());
        async.flushMicrotasks();
        unawaited(viewModel.seleccionarComuna('la-florida'));
        async.flushMicrotasks();
        viewModel.aplicarFiltroMateriales({'vidrio'});
        viewModel.descartarAviso();
        var vecesNotificado = 0;
        viewModel.addListener(() => vecesNotificado++);

        async.elapse(const Duration(seconds: 3));

        expect(vecesNotificado, 0);
      });
    });
  });
}
