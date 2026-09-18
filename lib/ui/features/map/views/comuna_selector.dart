import 'package:flutter/material.dart';

import '../../../../data/models/comuna.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/glass_bar_action.dart';
import '../../../core/spacing.dart';

class ComunaSelector extends StatelessWidget {
  const ComunaSelector({
    super.key,
    required this.comunas,
    required this.onElegirComuna,
    required this.onLimpiarComuna,
    this.comunaSeleccionadaId,
  });

  final List<Comuna> comunas;
  final void Function(String comunaId) onElegirComuna;

  /// Quita la comuna elegida a mano y vuelve al flujo por ubicación actual —
  /// sin esto, el único modo de "volver" a la ubicación real era buscar de
  /// nuevo la propia comuna a mano.
  final VoidCallback onLimpiarComuna;

  final String? comunaSeleccionadaId;

  @override
  Widget build(BuildContext context) {
    return GlassBarAction(
      icon: Icons.search,
      onTap: comunas.isEmpty ? null : () => _abrirBuscador(context),
    );
  }

  Future<void> _abrirBuscador(BuildContext context) async {
    final comunaId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuscadorDeComunas(
        comunas: comunas,
        comunaSeleccionadaId: comunaSeleccionadaId,
        onLimpiarComuna: onLimpiarComuna,
      ),
    );
    if (comunaId != null) onElegirComuna(comunaId);
  }
}

class _BuscadorDeComunas extends StatefulWidget {
  const _BuscadorDeComunas({
    required this.comunas,
    required this.comunaSeleccionadaId,
    required this.onLimpiarComuna,
  });

  final List<Comuna> comunas;
  final String? comunaSeleccionadaId;
  final VoidCallback onLimpiarComuna;

  @override
  State<_BuscadorDeComunas> createState() => _BuscadorDeComunasState();
}

class _BuscadorDeComunasState extends State<_BuscadorDeComunas> {
  String _consulta = '';

  void _limpiar() {
    widget.onLimpiarComuna();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final consulta = _consulta.trim().toLowerCase();
    final resultados = consulta.isEmpty
        ? widget.comunas
        : widget.comunas.where((c) => c.nombre.toLowerCase().contains(consulta)).toList();

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
                  child: Text('Selecciona la comuna', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (widget.comunaSeleccionadaId != null)
                  TextButton(
                    onPressed: _limpiar,
                    // Sin esto, el area de toque completa de Material (48px de alto)
                    // infla la fila del titulo y desborda la lista de comunas, que ya
                    // usa un alto maximo fijo — visto en produccion con las 345 comunas
                    // reales (BOTTOM OVERFLOWED BY 8.6 PIXELS).
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: espacioXs),
                    ),
                    child: const Text('Borrar comuna'),
                  ),
                BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: espacioMd),
            TextField(
              autofocus: true,
              onChanged: (valor) => setState(() => _consulta = valor),
              decoration: InputDecoration(
                hintText: 'Busca tu comuna',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(radioDeHojaFlotante - espacioMd)),
              ),
            ),
            const SizedBox(height: espacioSm),
            // Flexible en vez de un `ConstrainedBox` con una fraccion fija de
            // MediaQuery.size.height: esa fraccion ignoraba el teclado (que reduce
            // el espacio real disponible al abrir el buscador) y producia un
            // "BOTTOM OVERFLOWED" con el catalogo completo de comunas. Mismo fix
            // que en material_filter_button.dart.
            Flexible(
              child: resultados.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: espacioLg),
                      child: Text('No se encontraron comunas.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: resultados.length,
                      itemBuilder: (context, index) {
                        final comuna = resultados[index];
                        return ListTile(
                          title: Text(comuna.nombre),
                          onTap: () => Navigator.of(context).pop(comuna.id),
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
