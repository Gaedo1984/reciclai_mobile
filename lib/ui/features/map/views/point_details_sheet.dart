import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/models/recycling_point.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/material_colors.dart';
import '../../../core/spacing.dart';

class PointDetailsSheet extends StatelessWidget {
  const PointDetailsSheet({
    super.key,
    required this.punto,
    this.nombresDeMateriales = const {},
  });

  final RecyclingPoint punto;
  final Map<String, String> nombresDeMateriales;

  @override
  Widget build(BuildContext context) {
    return FloatingSheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(punto.nombre, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: espacioSm),
          Text(punto.direccion),
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
          if (punto.sitioWeb != null) ...[
            const SizedBox(height: espacioMd),
            FilledButton.tonal(
              onPressed: () => launchUrl(Uri.parse(punto.sitioWeb!)),
              child: const Text('Visitar sitio web'),
            ),
          ],
        ],
      ),
    );
  }
}
