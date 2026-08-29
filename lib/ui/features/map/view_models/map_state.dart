import '../../../../data/models/comuna.dart';
import '../../../../data/models/recycling_point.dart';

sealed class MapState {
  const MapState();
}

class Cargando extends MapState {
  const Cargando();
}

class ConDatos extends MapState {
  const ConDatos(this.puntos);

  final List<RecyclingPoint> puntos;
}

class RequierePicker extends MapState {
  const RequierePicker(this.comunasDisponibles, {this.mensaje});

  final List<Comuna> comunasDisponibles;
  final String? mensaje;
}

class ErrorAlCargar extends MapState {
  const ErrorAlCargar(this.mensaje);

  final String mensaje;
}
