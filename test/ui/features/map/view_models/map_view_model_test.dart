import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/comuna.dart';
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_state.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';

import '../../../../fakes.dart';

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

    expect(viewModel.state, isA<ConDatos>());
    expect((viewModel.state as ConDatos).puntos, hasLength(1));
  });

  test('permiso concedido pero sin cobertura -> RequierePicker con mensaje', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        resultadoCercanos: NotCovered([
          const Comuna(id: 'la-florida', nombre: 'La Florida', region: 'Metropolitana'),
        ]),
      ),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.iniciar();

    final estado = viewModel.state as RequierePicker;
    expect(estado.comunasDisponibles, hasLength(1));
    expect(estado.mensaje, isNotNull);
  });

  test('permiso denegado (temporal) -> RequierePicker sin mensaje, via GET /comunas', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        comunas: [const Comuna(id: 'la-florida', nombre: 'La Florida', region: 'Metropolitana')],
      ),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await viewModel.iniciar();

    final estado = viewModel.state as RequierePicker;
    expect(estado.comunasDisponibles, hasLength(1));
    expect(estado.mensaje, isNull);
  });

  test('permiso denegado permanente -> RequierePicker con mensaje explicando Ajustes', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: const []),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.denegadoPermanente,
      ),
    );

    await viewModel.iniciar();

    final estado = viewModel.state as RequierePicker;
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

    expect(viewModel.state, isA<ErrorAlCargar>());
  });

  test('seleccionarComuna reemplaza el estado anterior por completo', () async {
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
    expect((viewModel.state as ConDatos).puntos, hasLength(2));

    await viewModel.seleccionarComuna('san-joaquin');

    expect((viewModel.state as ConDatos).puntos, hasLength(1));
  });

  test('reintentar vuelve a correr el flujo de iniciar', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );

    await viewModel.reintentar();

    expect(viewModel.state, isA<ConDatos>());
  });
}
