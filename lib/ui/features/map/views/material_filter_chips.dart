import 'package:flutter/material.dart';

import '../../../core/spacing.dart';

/// Fila horizontal con un chip por cada material activo en una selección,
/// para que se vea de un vistazo qué se está filtrando/marcando — y sacar
/// uno solo tocando su "x", sin afectar al resto.
///
/// Sin lógica propia de `MapViewModel`: quien lo use decide si `onQuitar`
/// aplica el cambio de inmediato (filtro real del mapa) o solo actualiza un
/// borrador local (dentro de la hoja de selección, antes de "Aplicar").
class MaterialFilterChips extends StatelessWidget {
  const MaterialFilterChips({
    super.key,
    required this.seleccionados,
    required this.nombresDeMateriales,
    required this.onQuitar,
  });

  final Set<String> seleccionados;
  final Map<String, String> nombresDeMateriales;
  final void Function(String codigo) onQuitar;

  @override
  Widget build(BuildContext context) {
    if (seleccionados.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: espacioSm),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final codigo in seleccionados)
              Padding(
                padding: const EdgeInsets.only(right: espacioXs),
                child: InputChip(
                  label: Text(nombresDeMateriales[codigo] ?? codigo),
                  onDeleted: () => onQuitar(codigo),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
