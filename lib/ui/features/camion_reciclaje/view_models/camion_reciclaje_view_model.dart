import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/servicio_retiro.dart';
import '../../../../data/reciclai_api_client.dart';

/// Orden de la semana; el indice + 1 coincide con `DateTime.weekday`.
const _diasDeLaSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

sealed class EstadoCamion {
  const EstadoCamion();
}

class CamionCargando extends EstadoCamion {
  const CamionCargando();
}

/// El backend respondio 404: la comuna no tiene servicio de retiro.
class CamionSinServicio extends EstadoCamion {
  const CamionSinServicio();
}

class CamionError extends EstadoCamion {
  const CamionError();
}

class CamionListo extends EstadoCamion {
  const CamionListo(this.servicio);

  final ServicioRetiro servicio;
}

class CamionReciclajeViewModel extends ChangeNotifier {
  CamionReciclajeViewModel({
    required ReciclaiApiClient apiClient,
    DateTime Function()? ahora,
  }) : _apiClient = apiClient,
       _ahora = ahora ?? DateTime.now;

  final ReciclaiApiClient _apiClient;
  final DateTime Function() _ahora;

  EstadoCamion _estado = const CamionCargando();
  EstadoCamion get estado => _estado;

  String? _diaSeleccionado;
  String? get diaSeleccionado => _diaSeleccionado;

  /// Identifica la ultima llamada a abrir; una respuesta de una llamada
  /// anterior (o posterior a dispose) se descarta sin tocar el estado.
  int _solicitud = 0;

  String? _ultimaComunaId;
  LatLng? _ultimaUbicacion;

  ServicioRetiro? get _servicio {
    final estado = _estado;
    return estado is CamionListo ? estado.servicio : null;
  }

  /// Union de los dias de todas las zonas, de lunes a domingo.
  List<String> get diasDelServicio {
    final servicio = _servicio;
    if (servicio == null) return const [];
    final dias = servicio.zonas.expand((z) => z.dias).toSet();
    return _diasDeLaSemana.where(dias.contains).toList();
  }

  ZonaRetiro? get zonaDelDia {
    final servicio = _servicio;
    final dia = _diaSeleccionado;
    if (servicio == null || dia == null) return null;
    for (final zona in servicio.zonas) {
      if (zona.dias.contains(dia)) return zona;
    }
    return null;
  }

  /// Primer dia de la zona donde esta el usuario, o null si no se supo.
  String? get diaDelUsuario {
    final servicio = _servicio;
    final zonaActualId = servicio?.zonaActualId;
    if (servicio == null || zonaActualId == null) return null;
    for (final zona in servicio.zonas) {
      if (zona.id == zonaActualId) {
        return zona.dias.isEmpty ? null : zona.dias.first;
      }
    }
    return null;
  }

  /// `comunaId` tiene prioridad sobre `ubicacion` si vienen los dos.
  Future<void> abrir({String? comunaId, LatLng? ubicacion}) async {
    assert(
      comunaId != null || ubicacion != null,
      'abrir necesita comunaId o ubicacion',
    );
    final solicitud = ++_solicitud;
    _ultimaComunaId = comunaId;
    _ultimaUbicacion = ubicacion;
    _estado = const CamionCargando();
    _diaSeleccionado = null;
    notifyListeners();
    try {
      final servicio = comunaId != null
          ? await _apiClient.obtenerServicioRetiro(comunaId: comunaId)
          : await _apiClient.obtenerServicioRetiro(ubicacion: ubicacion);
      if (solicitud != _solicitud) return;
      if (servicio == null) {
        _estado = const CamionSinServicio();
      } else {
        _estado = CamionListo(servicio);
        _diaSeleccionado = _diaInicial();
      }
    } catch (_) {
      if (solicitud != _solicitud) return;
      _estado = const CamionError();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _solicitud++;
    super.dispose();
  }

  void seleccionarDia(String dia) {
    if (!diasDelServicio.contains(dia)) return;
    _diaSeleccionado = dia;
    notifyListeners();
  }

  Future<void> reintentar() =>
      abrir(comunaId: _ultimaComunaId, ubicacion: _ultimaUbicacion);

  String? _diaInicial() {
    final dias = diasDelServicio;
    if (dias.isEmpty) return null;
    final delUsuario = diaDelUsuario;
    if (delUsuario != null) return delUsuario;
    final hoy = _diasDeLaSemana[_ahora().weekday - 1];
    return dias.contains(hoy) ? hoy : dias.first;
  }
}
