import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'models/comuna.dart';
import 'models/material.dart' as modelo_material;
import 'models/points_nearby_result.dart';
import 'models/recycling_point.dart';
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
  }) async {
    final cuerpo = await _get(
      '/points/nearby/radius',
      queryParameters: {'lat': '$lat', 'lng': '$lng'},
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

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParameters,
    Duration? timeout,
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
