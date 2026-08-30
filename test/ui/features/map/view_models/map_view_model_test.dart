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
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(excepcion: const ReciclaiApiException('fallo simulado')),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    expect(viewModel.cuerpo, isA<ErrorAlCargar>());
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
}
