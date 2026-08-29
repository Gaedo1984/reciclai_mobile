import 'comuna.dart';
import 'recycling_point.dart';

sealed class PointsNearbyResult {
  const PointsNearbyResult();
}

class Covered extends PointsNearbyResult {
  const Covered(this.puntos);

  final List<RecyclingPoint> puntos;
}

class NotCovered extends PointsNearbyResult {
  const NotCovered(this.comunasDisponibles);

  final List<Comuna> comunasDisponibles;
}
