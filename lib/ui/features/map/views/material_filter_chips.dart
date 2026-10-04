import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../view_models/map_view_model.dart';

/// Fila horizontal con un chip por cada material activo en el filtro, para
/// que se vea de un vistazo qué se está filtrando sin tener que reabrir la
/// hoja de selección — y sacar uno solo tocando su "x", sin afectar al resto.
class MaterialFilterChips extends StatelessWidget {
  const MaterialFilterChips({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final seleccionados = viewModel.materialesSeleccionados;
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
                  label: Text(viewModel.nombresDeMateriales[codigo] ?? codigo),
                  onDeleted: () => viewModel.aplicarFiltroMateriales(
                    {...seleccionados}..remove(codigo),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
