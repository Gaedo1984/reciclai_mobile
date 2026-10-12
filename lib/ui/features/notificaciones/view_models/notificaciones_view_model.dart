import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/models/notificacion.dart';
import '../../../../data/reciclai_api_client.dart';

const _claveIdsLeidas = 'notificaciones_leidas';

class NotificacionesViewModel extends ChangeNotifier {
  NotificacionesViewModel({required ReciclaiApiClient apiClient}) : _apiClient = apiClient;

  final ReciclaiApiClient _apiClient;

  List<Notificacion> _notificaciones = [];
  List<Notificacion> get notificaciones => _notificaciones;

  Set<String> _idsLeidas = {};
  bool _idsLeidasCargadas = false;

  bool get hayNoLeidas => _notificaciones.any((n) => !_idsLeidas.contains(n.id));

  bool estaLeida(String id) => _idsLeidas.contains(id);

  /// Sin ningun Timer -- se llama una vez al abrir la app y de nuevo cada
  /// vez que se toca la campana (ver UI), nunca en un ciclo recurrente.
  Future<void> cargar() async {
    if (!_idsLeidasCargadas) {
      await _cargarIdsLeidas();
      _idsLeidasCargadas = true;
    }
    try {
      _notificaciones = await _apiClient.obtenerNotificaciones();
    } catch (_) {
      // Fallo silencioso -- igual que comunas/materiales en MapViewModel:
      // la campana simplemente no se actualiza hasta una carga posterior
      // exitosa, sin bloquear el resto de la app ni dejar un estado a medias.
    }
    notifyListeners();
  }

  Future<void> marcarLeida(String id) async {
    if (_idsLeidas.contains(id)) return;
    _idsLeidas = {..._idsLeidas, id};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveIdsLeidas, jsonEncode(_idsLeidas.toList()));
  }

  Future<void> _cargarIdsLeidas() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_claveIdsLeidas);
    if (guardado == null) return;
    try {
      _idsLeidas = (jsonDecode(guardado) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      // Dato corrupto (no deberia pasar -- solo esta app lo escribe) -- se
      // trata como "nada leido" en vez de lanzar y bloquear la campana.
    }
  }
}
