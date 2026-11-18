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

  /// Sector que se muestra para el dia seleccionado: el del usuario si pasa
  /// ese dia; si no, el mas cercano a su ubicacion (por centroide) o, sin
  /// ubicacion, el de mayor area. Con empate gana el primero de la lista.
  ZonaRetiro? get zonaDelDia {
    final servicio = _servicio;
    final dia = _diaSeleccionado;
    if (servicio == null || dia == null) return null;
    final delUsuario = _zonaDelUsuario;
    if (delUsuario != null && delUsuario.dias.contains(dia)) return delUsuario;
    final candidatas = servicio.zonas.where((z) => z.dias.contains(dia));
    final ubicacion = _ultimaUbicacion;
    ZonaRetiro? mejor;
    var mejorPuntaje = double.infinity;
    for (final zona in candidatas) {
      // Menor puntaje gana: distancia al centroide, o area negativa.
      final puntaje = ubicacion != null
          ? _distanciaAlCentroide(zona, ubicacion)
          : -_area(zona);
      if (mejor == null || puntaje < mejorPuntaje) {
        mejor = zona;
        mejorPuntaje = puntaje;
      }
    }
    return mejor;
  }

  /// Area total de la zona (formula del poligono de Gauss) en grados
  /// cuadrados; solo sirve para comparar zonas entre si.
  static double _area(ZonaRetiro zona) =>
      zona.poligonos.fold(0.0, (suma, anillo) => suma + _areaDelAnillo(anillo).abs());

  static double _areaDelAnillo(List<LatLng> anillo) {
    if (anillo.isEmpty) return 0;
    // Se resta el primer vertice para no perder precision con coordenadas
    // grandes (y que poligonos iguales den el mismo area).
    final origen = anillo.first;
    var doble = 0.0;
    for (var i = 0; i < anillo.length; i++) {
      final a = anillo[i];
      final b = anillo[(i + 1) % anillo.length];
      doble +=
          (a.longitude - origen.longitude) * (b.latitude - origen.latitude) -
          (b.longitude - origen.longitude) * (a.latitude - origen.latitude);
    }
    return doble / 2;
  }

  /// Distancia (en grados) del punto al centroide de los vertices de la zona;
  /// infinita si la zona no tiene poligonos.
  static double _distanciaAlCentroide(ZonaRetiro zona, LatLng punto) {
    final vertices = zona.poligonos.expand((p) => p).toList();
    if (vertices.isEmpty) return double.infinity;
    final lat = vertices.fold(0.0, (s, v) => s + v.latitude) / vertices.length;
    final lng = vertices.fold(0.0, (s, v) => s + v.longitude) / vertices.length;
    final dLat = lat - punto.latitude;
    final dLng = lng - punto.longitude;
    return dLat * dLat + dLng * dLng;
  }

  /// Horario de la zona del dia si trae uno propio; si no, el del servicio.
  String? get horarioDelDia => zonaDelDia?.horario ?? _servicio?.horario;

  /// Zona donde esta el usuario, o null si no se supo.
  ZonaRetiro? get _zonaDelUsuario {
    final servicio = _servicio;
    final zonaActualId = servicio?.zonaActualId;
    if (servicio == null || zonaActualId == null) return null;
    for (final zona in servicio.zonas) {
      if (zona.id == zonaActualId) return zona;
    }
    return null;
  }

  /// Primer dia de la zona donde esta el usuario, o null si no se supo.
  String? get diaDelUsuario {
    final dias = _zonaDelUsuario?.dias;
    return dias == null || dias.isEmpty ? null : dias.first;
  }

  /// true si el camion pasa por la zona del usuario el dia seleccionado
  /// (cualquiera de sus dias, no solo el primero).
  bool get diaEsDelUsuario {
    final dia = _diaSeleccionado;
    return dia != null && (_zonaDelUsuario?.dias.contains(dia) ?? false);
  }

  /// La consulta usa `comunaId` si viene; si no, `ubicacion`. `ubicacion`
  /// tambien se guarda como la del usuario para elegir sector.
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
