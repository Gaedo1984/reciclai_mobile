import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/models/recycling_point.dart';

class PointDetailsSheet extends StatelessWidget {
  const PointDetailsSheet({super.key, required this.punto});

  final RecyclingPoint punto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(punto.nombre, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(punto.direccion),
            if (punto.horario != null) ...[
              const SizedBox(height: 8),
              Text('Horario: ${punto.horario}'),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [for (final material in punto.materiales) Chip(label: Text(material))],
            ),
            if (punto.sitioWeb != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => launchUrl(Uri.parse(punto.sitioWeb!)),
                child: const Text('Visitar sitio web'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
