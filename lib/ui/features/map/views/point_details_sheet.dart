import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/models/recycling_point.dart';
import '../../../../domain/formatear_distancia.dart';
import '../../../../domain/mapas_externos.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/material_colors.dart';
import '../../../core/spacing.dart';

class PointDetailsSheet extends StatelessWidget {
  const PointDetailsSheet({
    super.key,
    required this.punto,
    this.nombresDeMateriales = const {},
    this.miUbicacion,
  });

  final RecyclingPoint punto;
  final Map<String, String> nombresDeMateriales;

  /// Posición actual del usuario, para mostrar a qué distancia está este
  /// punto. Null si no se conoce (sin permiso de ubicación, o sin GPS aún).
  final LatLng? miUbicacion;

  @override
  Widget build(BuildContext context) {
    final miUbicacion = this.miUbicacion;
    return FloatingSheetCard(
      // El contenido (nombre/direccion/horario largos + varios materiales) puede superar
      // el alto que showModalBottomSheet le da a la hoja por defecto — sin esto, el Column
      // no tenia como scrollear y desbordaba (RenderFlex overflowed).
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(punto.nombre, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: espacioSm),
            Text(punto.direccion),
            if (miUbicacion != null) ...[
              const SizedBox(height: espacioSm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.social_distance,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: espacioXs),
                  Text(
                    '${formatearDistancia(Geolocator.distanceBetween(
                      miUbicacion.latitude,
                      miUbicacion.longitude,
                      punto.ubicacion.latitude,
                      punto.ubicacion.longitude,
                    ))} de tu ubicación',
                  ),
                ],
              ),
            ],
            if (punto.horario != null) ...[
              const SizedBox(height: espacioSm),
              Text('Horario: ${punto.horario}'),
            ],
            const SizedBox(height: espacioSm),
            Wrap(
              spacing: espacioSm,
              children: [
                for (final material in punto.materiales)
                  Chip(
                    avatar: CircleAvatar(backgroundColor: colorParaMaterial(material), radius: 8),
                    label: Text(nombresDeMateriales[material] ?? material),
                  ),
              ],
            ),
            const SizedBox(height: espacioMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _abrirSelectorDeRuta(context),
                    icon: const Icon(Icons.directions),
                    label: const Text('Ruta'),
                  ),
                ),
                if (punto.sitioWeb != null) ...[
                  const SizedBox(width: espacioSm),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => launchUrl(Uri.parse(punto.sitioWeb!)),
                      child: const Text('Visitar sitio web'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _abrirSelectorDeRuta(BuildContext context) {
    final opciones = opcionesDeRuta(
      punto.ubicacion,
      incluirAppleMaps: defaultTargetPlatform == TargetPlatform.iOS,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (contextDeLaHoja) => FloatingSheetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Abrir ruta en', style: Theme.of(contextDeLaHoja).textTheme.titleMedium),
            for (final opcion in opciones)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_iconoDeRuta(opcion.nombre)),
                title: Text(opcion.nombre),
                onTap: () {
                  Navigator.of(contextDeLaHoja).pop();
                  launchUrl(opcion.uri, mode: LaunchMode.externalApplication);
                },
              ),
          ],
        ),
      ),
    );
  }
}

IconData _iconoDeRuta(String nombreDeLaApp) => switch (nombreDeLaApp) {
      'Google Maps' => Icons.map,
      'Waze' => Icons.navigation,
      _ => Icons.map_outlined,
    };
