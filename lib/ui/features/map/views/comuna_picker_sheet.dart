import 'package:flutter/material.dart';

import '../../../../data/models/comuna.dart';

class ComunaPickerSheet extends StatelessWidget {
  const ComunaPickerSheet({
    super.key,
    required this.comunas,
    required this.onElegirComuna,
    this.mensaje,
  });

  final List<Comuna> comunas;
  final String? mensaje;
  final void Function(String comunaId) onElegirComuna;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mensaje != null) ...[
              Text(mensaje!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
            ],
            const Text('Elegí tu comuna', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: comunas.length,
                itemBuilder: (context, index) {
                  final comuna = comunas[index];
                  return ListTile(
                    title: Text(comuna.nombre),
                    onTap: () => onElegirComuna(comuna.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
