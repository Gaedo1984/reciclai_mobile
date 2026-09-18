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

/// Quita tildes y pasa a minúsculas — sin esto, buscar "plastico" (como
/// escribe la mayoría en un teclado sin tildes) no encontraba "Plástico".
String _normalizar(String texto) {
  const conTilde = 'áéíóúÁÉÍÓÚñÑ';
  const sinTilde = 'aeiouAEIOUnN';
  var normalizado = texto.toLowerCase();
  for (var i = 0; i < conTilde.length; i++) {
    normalizado = normalizado.replaceAll(conTilde[i].toLowerCase(), sinTilde[i].toLowerCase());
  }
  return normalizado;
}

class _SelectorDeMaterialesState extends State<_SelectorDeMateriales> {
  late Set<String> _seleccionEnBorrador = {...widget.viewModel.materialesSeleccionados};
  String _busqueda = '';

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
    final consulta = _normalizar(_busqueda.trim());
    final entradas = widget.viewModel.nombresDeMateriales.entries
        .where((entrada) => consulta.isEmpty || _normalizar(entrada.value).contains(consulta))
        .toList();

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
                Expanded(
                  child: Text('Filtrar por material', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (_seleccionEnBorrador.isNotEmpty)
                  TextButton(
                    onPressed: _borrar,
                    // Sin esto, el area de toque completa de Material (48px de alto)
                    // infla la fila del titulo — mismo problema ya resuelto en
                    // "Borrar comuna" (comuna_selector.dart).
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: espacioXs),
                    ),
                    child: const Text('Borrar filtros'),
                  ),
                BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: espacioMd),
            TextField(
              onChanged: (valor) => setState(() => _busqueda = valor),
              decoration: InputDecoration(
                hintText: 'Busca un material',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radioDeHojaFlotante - espacioMd),
                ),
              ),
            ),
            const SizedBox(height: espacioSm),
            // Flexible en vez de un `ConstrainedBox` con una fraccion fija de
            // MediaQuery.size.height: esa fraccion ignoraba el teclado (que reduce
            // el espacio real disponible al abrir el buscador) y producia un
            // "BOTTOM OVERFLOWED" con el catalogo completo de materiales. Flexible
            // respeta el espacio realmente disponible del layout (que si se reduce
            // correctamente cuando aparece el teclado), sin overflow, y sigue
            // dejando que la hoja se achique para catalogos cortos.
            Flexible(
              child: entradas.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: espacioLg),
                      child: Text('No se encontraron materiales.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final entrada in entradas)
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
