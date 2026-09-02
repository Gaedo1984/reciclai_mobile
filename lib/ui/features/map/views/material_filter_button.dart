import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/glass_bar_action.dart';
import '../../../core/spacing.dart';
import '../view_models/map_view_model.dart';

class MaterialFilterButton extends StatelessWidget {
  const MaterialFilterButton({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final activo = viewModel.materialesSeleccionados.isNotEmpty;
    return GlassBarAction(
      icon: activo ? Icons.filter_alt : Icons.filter_alt_outlined,
      color: activo ? Theme.of(context).colorScheme.secondary : null,
      onTap: viewModel.nombresDeMateriales.isEmpty ? null : () => _abrirFiltro(context),
    );
  }

  Future<void> _abrirFiltro(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorDeMateriales(viewModel: viewModel),
    );
  }
}

/// Las casillas se marcan en un borrador local (`_seleccionEnBorrador`) — el
/// filtro real del mapa (`viewModel.materialesSeleccionados`) recién se
/// actualiza cuando se toca "Aplicar". Cerrar la hoja de cualquier otra
/// forma (deslizarla, tocar afuera) descarta el borrador sin tocar el
/// filtro real: mejor experiencia que ir filtrando el mapa en vivo mientras
/// el usuario todavía está eligiendo materiales.
class _SelectorDeMateriales extends StatefulWidget {
  const _SelectorDeMateriales({required this.viewModel});

  final MapViewModel viewModel;

  @override
  State<_SelectorDeMateriales> createState() => _SelectorDeMaterialesState();
}

class _SelectorDeMaterialesState extends State<_SelectorDeMateriales> {
  late Set<String> _seleccionEnBorrador = {...widget.viewModel.materialesSeleccionados};

  void _alternar(String codigo) {
    setState(() {
      final nuevo = {..._seleccionEnBorrador};
      if (!nuevo.remove(codigo)) nuevo.add(codigo);
      _seleccionEnBorrador = nuevo;
    });
  }

  void _borrar() => setState(() => _seleccionEnBorrador = {});

  void _aplicar() {
    widget.viewModel.aplicarFiltroMateriales(_seleccionEnBorrador);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FloatingSheetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filtrar por material', style: Theme.of(context).textTheme.titleMedium),
                if (_seleccionEnBorrador.isNotEmpty)
                  TextButton(onPressed: _borrar, child: const Text('Borrar filtros')),
              ],
            ),
            const SizedBox(height: espacioSm),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entrada in widget.viewModel.nombresDeMateriales.entries)
                    CheckboxListTile(
                      key: ValueKey(entrada.key),
                      value: _seleccionEnBorrador.contains(entrada.key),
                      onChanged: (_) => _alternar(entrada.key),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(entrada.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: espacioSm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(onPressed: _aplicar, child: const Text('Aplicar')),
            ),
          ],
        ),
      ),
    );
  }
}
