/// Formatea una distancia en metros para mostrarla al usuario: metros
/// enteros bajo 1 km, kilometros con un decimal desde ahi.
String formatearDistancia(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1)} km';
}
