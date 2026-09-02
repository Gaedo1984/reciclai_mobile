import 'package:latlong2/latlong.dart';

/// Una app de mapas a la que se puede pedir ruta hacia un destino, con el
/// link universal correspondiente. Al ser un link universal (https, no un
/// esquema propio de la app), el sistema operativo abre la app instalada si
/// existe, o su version web en el navegador si no — nunca falla.
class OpcionDeRuta {
  const OpcionDeRuta({required this.nombre, required this.uri});

  final String nombre;
  final Uri uri;
}

/// Arma las opciones de ruta hacia [destino]. "Maps" (Apple Maps) solo tiene
/// sentido en iOS — no existe una app nativa en Android — asi que queda
/// afuera salvo que quien llame pida explicitamente incluirla.
List<OpcionDeRuta> opcionesDeRuta(LatLng destino, {bool incluirAppleMaps = false}) {
  final lat = destino.latitude;
  final lng = destino.longitude;
  return [
    OpcionDeRuta(
      nombre: 'Google Maps',
      uri: Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    ),
    OpcionDeRuta(nombre: 'Waze', uri: Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes')),
    if (incluirAppleMaps)
      OpcionDeRuta(nombre: 'Maps', uri: Uri.parse('https://maps.apple.com/?daddr=$lat,$lng')),
  ];
}
