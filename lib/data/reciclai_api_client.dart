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
  static const _timeout = Duration(seconds: 10);

  Future<List<Comuna>> obtenerComunas() async {
    final cuerpo = await _get('/comunas');
    return (cuerpo as List<dynamic>)
        .map((e) => Comuna.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<modelo_material.Material>> obtenerMateriales() async {
    final cuerpo = await _get('/materiales');
    return (cuerpo as List<dynamic>)
        .map((e) => modelo_material.Material.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecyclingPoint>> obtenerPuntosPorComuna(String comunaId) async {
    final cuerpo = await _get('/points?comuna_id=$comunaId');
    return (cuerpo as List<dynamic>)
        .map((e) => RecyclingPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PointsNearbyResult> obtenerPuntosCercanos(double lat, double lng) async {
    final cuerpo = await _get('/points/nearby?lat=$lat&lng=$lng');
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
  }

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    late final http.Response respuesta;
    try {
      respuesta = await _client
          .get(uri, headers: {'X-API-Key': AppConfig.apiKey})
          .timeout(_timeout);
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
