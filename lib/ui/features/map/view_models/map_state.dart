import '../../../../data/models/recycling_point.dart';

sealed class CuerpoMapaState {
  const CuerpoMapaState();
}

class Cargando extends CuerpoMapaState {
  const Cargando();
}

class ConDatos extends CuerpoMapaState {
  const ConDatos(this.puntos);

  final List<RecyclingPoint> puntos;
}

class SinSeleccion extends CuerpoMapaState {
  const SinSeleccion({this.mensaje});

  final String? mensaje;
}

class ErrorAlCargar extends CuerpoMapaState {
  const ErrorAlCargar(this.mensaje);

  final String mensaje;
}

/// La geolocalización funcionó, pero cayó fuera de Chile — la app hoy solo
/// tiene datos de comunas chilenas, así que no tiene sentido ofrecer el
/// buscador de comunas.
class FueraDeRango extends CuerpoMapaState {
  const FueraDeRango();
}
