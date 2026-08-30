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
