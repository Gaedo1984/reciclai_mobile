import '../data/models/recycling_point.dart';

/// Deja solo los puntos que aceptan al menos uno de los `materiales` elegidos
/// (selección múltiple, unión — no intersección). Un `materiales` vacío
/// significa "sin filtro": devuelve `puntos` sin cambios.
List<RecyclingPoint> filtrarPorMateriales(List<RecyclingPoint> puntos, Set<String> materiales) {
  if (materiales.isEmpty) return puntos;
  return puntos.where((punto) => punto.materiales.any(materiales.contains)).toList();
}
