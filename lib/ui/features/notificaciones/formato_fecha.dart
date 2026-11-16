const _mesesAbreviados = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Formato corto en español para mostrar junto a una notificación, ej.
/// "12 oct." -- sin año (todas las notificaciones son recientes) ni hora
/// (no aporta nada para avisos puntuales).
String formatearFechaCorta(DateTime fecha) {
  return '${fecha.day} ${_mesesAbreviados[fecha.month - 1]}.';
}

/// Mes abreviado en minúscula y año, ej. "nov 2026" -- para fechas de
/// actualización de una fuente, donde el día no aporta.
String formatearMesAnio(DateTime fecha) {
  return '${_mesesAbreviados[fecha.month - 1]} ${fecha.year}';
}
