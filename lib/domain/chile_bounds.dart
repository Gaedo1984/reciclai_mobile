const _latitudMinima = -56.0; // sur del cabo de Hornos
const _latitudMaxima = -17.0; // norte de Arica
const _longitudMinima = -76.0; // oeste del territorio continental
const _longitudMaxima = -66.0; // este, límite con Argentina/Bolivia/Perú

/// Caja delimitadora aproximada de Chile continental — no es el polígono
/// exacto del país, pero alcanza para distinguir "claramente fuera de Chile"
/// del resto, que es todo lo que necesita esta app hoy (que solo tiene datos
/// de comunas piloto en la Región Metropolitana).
bool estaEnChile(double latitud, double longitud) {
  return latitud >= _latitudMinima &&
      latitud <= _latitudMaxima &&
      longitud >= _longitudMinima &&
      longitud <= _longitudMaxima;
}
