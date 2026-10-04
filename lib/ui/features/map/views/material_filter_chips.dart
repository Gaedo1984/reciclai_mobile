import 'package:flutter/material.dart';

import '../../../core/spacing.dart';

// 2 filas visibles antes de que el propio widget empiece a scrollear
// verticalmente en vez de seguir empujando lo que venga despues (la lista de
// materiales, en la hoja de seleccion) -- ver `multilinea`.
const _altoDeFila = 48.0;
const _filasVisiblesAntesDeScroll = 2;

/// Fila con un chip por cada material activo en una selección, para que se
/// vea de un vistazo qué se está filtrando/marcando — y sacar uno solo
/// tocando su "x", sin afectar al resto.
///
/// Sin lógica propia de `MapViewModel`: quien lo use decide si `onQuitar`
/// aplica el cambio de inmediato (filtro real del mapa) o solo actualiza un
/// borrador local (dentro de la hoja de selección, antes de "Aplicar").
class MaterialFilterChips extends StatefulWidget {
  const MaterialFilterChips({
    super.key,
    required this.seleccionados,
    required this.nombresDeMateriales,
    required this.onQuitar,
    this.multilinea = false,
  });

  final Set<String> seleccionados;
  final Map<String, String> nombresDeMateriales;
  final void Function(String codigo) onQuitar;

  /// `false` (default, usado flotando sobre el mapa): una sola fila que se
  /// desliza horizontalmente — compacto, para un elemento flotante.
  /// `true` (usado dentro de la hoja de selección): grilla de a 2 por fila,
  /// creciendo hacia abajo a medida que se marcan mas materiales, con su
  /// propio scroll vertical (y una scrollbar visible) a partir de la 3ra
  /// fila — para no empujar la lista de materiales cada vez que se marca
  /// uno mas.
  final bool multilinea;

  @override
  State<MaterialFilterChips> createState() => _MaterialFilterChipsState();
}

class _MaterialFilterChipsState extends State<MaterialFilterChips> {
  // Propio y no el PrimaryScrollController por defecto: la hoja de
  // seleccion ya tiene su propia lista vertical (los checkboxes) usando
  // ese mismo controller implicito -- con dos scrollables compitiendo por
  // el, el Scrollbar(thumbVisibility: true) revienta con "attached to more
  // than one ScrollPosition".
  final _controlDeScroll = ScrollController();

  @override
  void dispose() {
    _controlDeScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seleccionados.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: espacioSm),
      child: widget.multilinea ? _grillaDeDos(context) : _filaUnica(),
    );
  }

  Widget _filaUnica() {
    return SizedBox(
      height: _altoDeFila,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final codigo in widget.seleccionados)
            Padding(
              padding: const EdgeInsets.only(right: espacioXs),
              child: _chip(codigo),
            ),
        ],
      ),
    );
  }

  Widget _grillaDeDos(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoPorChip = (constraints.maxWidth - espacioSm) / 2;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _altoDeFila * _filasVisiblesAntesDeScroll + espacioSm,
          ),
          // thumbVisibility: true, no solo al arrastrar -- es la señal de que
          // hay mas filtros aplicados de los que entran en las 2 filas
          // visibles, sin que el usuario tenga que intentar scrollear para
          // descubrirlo.
          child: Scrollbar(
            controller: _controlDeScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _controlDeScroll,
              child: Wrap(
                spacing: espacioSm,
                runSpacing: espacioSm,
                children: [
                  for (final codigo in widget.seleccionados)
                    SizedBox(width: anchoPorChip, child: _chip(codigo)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String codigo) {
    return InputChip(
      label: Text(
        widget.nombresDeMateriales[codigo] ?? codigo,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      onDeleted: () => widget.onQuitar(codigo),
    );
  }
}
