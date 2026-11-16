import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import 'models/comuna.dart';
import 'models/material.dart' as modelo_material;
import 'models/notificacion.dart';
import 'models/points_nearby_result.dart';
import 'models/recycling_point.dart';
import 'models/servicio_retiro.dart';
import 'reciclai_api_exception.dart';

class ReciclaiApiClient {
  ReciclaiApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  // 60s, no 10s: el plan free de Render duerme el backend tras inactividad, y el
  // primer request tras despertar puede tardar mas de un minuto en responder.
  static const _timeout = Duration(seconds: 60);

  Future<List<Comuna>> obtenerComunas({Duration? timeout}) async {
    final cuerpo = await _get('/comunas', timeout: timeout);
    try {
      return (cuerpo as List<dynamic>)
          .map((e) => Comuna.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }

  Future<List<modelo_material.Material>> obtenerMateriales({Duration? timeout}) async {
    final cuerpo = await _get('/materiales', timeout: timeout);
    try {
      return (cuerpo as List<dynamic>)
          .map((e) => modelo_material.Material.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }

  Future<List<RecyclingPoint>> obtenerPuntosPorComuna(String comunaId) async {
    final cuerpo = await _get('/points', queryParameters: {'comuna_id': comunaId});
    try {
      return (cuerpo as List<dynamic>)
          .map((e) => RecyclingPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }

  Future<PointsNearbyResult> obtenerPuntosCercanos(
    double lat,
    double lng, {
    Duration? timeout,
  }) async {
    final cuerpo = await _get(
      '/points/nearby',
      queryParameters: {'lat': '$lat', 'lng': '$lng'},
      timeout: timeout,
    );
    try {
      if (cuerpo is List<dynamic>) {
        final puntos =
            cuerpo.map((e) => RecyclingPoint.fromJson(e as Map<String, dynamic>)).toList();
        return Covered(puntos);
      }
      final mapa = cuerpo as Map<String, dynamic>;
      final comunas = (mapa['comunas_disponibles'] as List<dynamic>)
          .map((e) => Comuna.fromJson(e as Map<String, dynamic>))
          .toList();
      return NotCovered(comunas);
    } catch (e) {
      if (e is ReciclaiApiException) rethrow;
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }

  Future<List<RecyclingPoint>> obtenerPuntosEnRadio(
    double lat,
    double lng, {
    Duration? timeout,
    double? radioMetros,
  }) async {
    final cuerpo = await _get(
      '/points/nearby/radius',
      queryParameters: {
        'lat': '$lat',
        'lng': '$lng',
        if (radioMetros != null) 'radio_metros': '$radioMetros',
      },
      timeout: timeout,
    );
    try {
      return (cuerpo as List<dynamic>)
          .map((e) => RecyclingPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }

  Future<List<Notificacion>> obtenerNotificaciones({int limite = 50}) async {
    final cuerpo = await _get('/notificaciones', queryParameters: {'limite': '$limite'});
    try {
      return (cuerpo as List<dynamic>)
          .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }

  /// Servicio de retiro de la comuna (o de la comuna que contiene `ubicacion`).
  /// Devuelve `null` si el backend responde 404 (comuna sin servicio de retiro).
  Future<ServicioRetiro?> obtenerServicioRetiro({String? comunaId, LatLng? ubicacion}) async {
    assert(
      (comunaId == null) != (ubicacion == null),
      'se debe pasar exactamente uno de comunaId o ubicacion',
    );
    final cuerpo = await _get(
      '/zonas-retiro',
      queryParameters: {
        if (comunaId != null) 'comuna_id': comunaId,
        if (ubicacion != null) ...{
          'lat': '${ubicacion.latitude}',
          'lng': '${ubicacion.longitude}',
        },
      },
      nullSi404: true,
    );
    if (cuerpo == null) return null;
    try {
      return ServicioRetiro.fromJson(cuerpo as Map<String, dynamic>);
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParameters,
    Duration? timeout,
    bool nullSi404 = false,
  }) async {
    // Los valores dinamicos viajan como queryParameters (percent-encoding real via
    // Uri.replace), nunca interpolados a mano en el string del path — un '&' u otro
    // caracter reservado en un valor rompia la estructura de la query (ver test).
    var uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    late final http.Response respuesta;
    try {
      respuesta = await _client
          .get(uri, headers: {'X-API-Key': AppConfig.apiKey})
          .timeout(timeout ?? _timeout);
    } on Exception catch (e) {
      throw ReciclaiApiException('error de red: $e');
    }

    if (nullSi404 && respuesta.statusCode == 404) return null;

    if (respuesta.statusCode != 200) {
      throw ReciclaiApiException(
        'el backend respondio ${respuesta.statusCode}: ${respuesta.body}',
      );
    }

    try {
      return jsonDecode(respuesta.body);
    } on FormatException catch (e) {
      throw ReciclaiApiException('respuesta no es JSON valido: $e');
    }
  }
}
