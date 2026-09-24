import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reciclai_mobile/data/models/points_nearby_result.dart';
import 'package:reciclai_mobile/data/reciclai_api_client.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';

class _ClienteFalso extends http.BaseClient {
  _ClienteFalso(this._handler);

  final http.StreamedResponse Function(http.BaseRequest request) _handler;
  http.BaseRequest? ultimaPeticion;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    ultimaPeticion = request;
    return _handler(request);
  }
}

http.StreamedResponse _respuestaJson(int status, Object cuerpo) {
  final bytes = utf8.encode(jsonEncode(cuerpo));
  return http.StreamedResponse(Stream.value(bytes), status);
}

void main() {
  test('obtenerComunas manda el header X-API-Key y parsea la lista', () async {
    final cliente = _ClienteFalso((request) {
      return _respuestaJson(200, [
        {
          'id': 'la-florida',
          'nombre': 'La Florida',
          'region': 'Metropolitana',
          'centro': {'lat': -33.50, 'lng': -70.60},
        },
      ]);
    });
    final api = ReciclaiApiClient(client: cliente);

    final comunas = await api.obtenerComunas();

    expect(comunas, hasLength(1));
    expect(comunas.first.id, 'la-florida');
    expect(cliente.ultimaPeticion!.headers.containsKey('X-API-Key'), isTrue);
  });

  test('obtenerMateriales parsea la lista del backend', () async {
    final cliente = _ClienteFalso((request) {
      return _respuestaJson(200, [
        {'codigo': 'plastico', 'nombre': 'Plástico'},
      ]);
    });
    final api = ReciclaiApiClient(client: cliente);

    final materiales = await api.obtenerMateriales();

    expect(materiales, hasLength(1));
    expect(materiales.first.codigo, 'plastico');
  });

  test('obtenerPuntosPorComuna arma la URL con comuna_id y parsea los puntos', () async {
    final cliente = _ClienteFalso((request) {
      expect(request.url.queryParameters['comuna_id'], 'la-florida');
      return _respuestaJson(200, [
        {
          'id': '1',
          'nombre': 'Punto Limpio',
          'direccion': 'Av. Siempre Viva 123',
          'ubicacion': {'lat': -33.52, 'lng': -70.60},
          'tipo': 'punto_limpio',
          'materiales': ['plastico'],
          'horario': null,
          'es_empresa': false,
          'sitio_web': null,
          'confianza': 'media',
        },
      ]);
    });
    final api = ReciclaiApiClient(client: cliente);

    final puntos = await api.obtenerPuntosPorComuna('la-florida');

    expect(puntos, hasLength(1));
    expect(puntos.first.nombre, 'Punto Limpio');
  });

  test('obtenerPuntosPorComuna codifica correctamente un comuna_id con caracteres especiales',
      () async {
    // Si la URL se arma con interpolacion de texto ('/points?comuna_id=$comunaId') en vez
    // de queryParameters, un '&' en el valor rompe la query: en vez de un solo parametro
    // "comuna_id=la&florida" quedan dos ("comuna_id=la" y "florida"), y el backend recibe
    // un comuna_id distinto al que se le pidio a la funcion.
    final cliente = _ClienteFalso((request) {
      expect(request.url.queryParameters['comuna_id'], 'la&florida');
      return _respuestaJson(200, []);
    });
    final api = ReciclaiApiClient(client: cliente);

    await api.obtenerPuntosPorComuna('la&florida');
  });

  test('obtenerPuntosCercanos con covered=true devuelve Covered con los puntos', () async {
    final cliente = _ClienteFalso((request) {
      return _respuestaJson(200, [
        {
          'id': '1',
          'nombre': 'Punto Limpio',
          'direccion': 'Av. Siempre Viva 123',
          'ubicacion': {'lat': -33.52, 'lng': -70.60},
          'tipo': 'punto_limpio',
          'materiales': ['plastico'],
          'horario': null,
          'es_empresa': false,
          'sitio_web': null,
          'confianza': 'media',
        },
      ]);
    });
    final api = ReciclaiApiClient(client: cliente);

    final resultado = await api.obtenerPuntosCercanos(-33.52, -70.60);

    expect(resultado, isA<Covered>());
    expect((resultado as Covered).puntos, hasLength(1));
  });

  test('obtenerPuntosCercanos con covered=false devuelve NotCovered con las comunas', () async {
    final cliente = _ClienteFalso((request) {
      return _respuestaJson(200, {
        'covered': false,
        'comunas_disponibles': [
          {
          'id': 'la-florida',
          'nombre': 'La Florida',
          'region': 'Metropolitana',
          'centro': {'lat': -33.50, 'lng': -70.60},
        },
        ],
      });
    });
    final api = ReciclaiApiClient(client: cliente);

    final resultado = await api.obtenerPuntosCercanos(-40.0, -70.0);

    expect(resultado, isA<NotCovered>());
    expect((resultado as NotCovered).comunasDisponibles, hasLength(1));
  });

  test('respuesta con status distinto de 200 lanza ReciclaiApiException', () async {
    final cliente = _ClienteFalso((request) {
      return http.StreamedResponse(Stream.value(utf8.encode('unauthorized')), 401);
    });
    final api = ReciclaiApiClient(client: cliente);

    expect(() => api.obtenerComunas(), throwsA(isA<ReciclaiApiException>()));
  });

  test('JSON invalido lanza ReciclaiApiException', () async {
    final cliente = _ClienteFalso((request) {
      return http.StreamedResponse(Stream.value(utf8.encode('esto no es json')), 200);
    });
    final api = ReciclaiApiClient(client: cliente);

    expect(() => api.obtenerComunas(), throwsA(isA<ReciclaiApiException>()));
  });

  test('error de red lanza ReciclaiApiException', () async {
    final cliente = _ClienteFalso((request) {
      throw http.ClientException('fallo de red simulado');
    });
    final api = ReciclaiApiClient(client: cliente);

    expect(() => api.obtenerComunas(), throwsA(isA<ReciclaiApiException>()));
  });

  test('respuesta 200 con forma inesperada lanza ReciclaiApiException, no TypeError', () async {
    final cliente = _ClienteFalso((request) {
      return _respuestaJson(200, {'esto': 'no es una lista de comunas'});
    });
    final api = ReciclaiApiClient(client: cliente);

    expect(() => api.obtenerComunas(), throwsA(isA<ReciclaiApiException>()));
  });
}
