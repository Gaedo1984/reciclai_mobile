import 'package:flutter/material.dart';

import '../../../../data/models/comuna.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';

class ComunaSelector extends StatelessWidget {
  const ComunaSelector({
    super.key,
    required this.comunas,
    required this.comunaSeleccionadaId,
    required this.onElegirComuna,
  });

  final List<Comuna> comunas;
  final String? comunaSeleccionadaId;
  final void Function(String comunaId) onElegirComuna;

  Comuna? get _comunaSeleccionada {
    for (final comuna in comunas) {
      if (comuna.id == comunaSeleccionadaId) return comuna;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(espacioMd, espacioSm, espacioMd, espacioMd - espacioXs),
      child: Material(
        color: colores.surface,
        borderRadius: BorderRadius.circular(radioDeHojaFlotante),
        child: InkWell(
          borderRadius: BorderRadius.circular(radioDeHojaFlotante),
          onTap: comunas.isEmpty ? null : () => _abrirBuscador(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: espacioMd, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radioDeHojaFlotante),
              border: Border.all(color: colores.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.location_city_outlined, color: colores.onSurfaceVariant),
                const SizedBox(width: espacioMd - espacioXs),
                Expanded(
                  child: Text(
                    _comunaSeleccionada?.nombre ?? 'Selecciona la comuna',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _comunaSeleccionada == null ? colores.onSurfaceVariant : null,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: colores.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirBuscador(BuildContext context) async {
    final comunaId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuscadorDeComunas(comunas: comunas),
    );
    if (comunaId != null) onElegirComuna(comunaId);
  }
}

class _BuscadorDeComunas extends StatefulWidget {
  const _BuscadorDeComunas({required this.comunas});

  final List<Comuna> comunas;

  @override
  State<_BuscadorDeComunas> createState() => _BuscadorDeComunasState();
}

class _BuscadorDeComunasState extends State<_BuscadorDeComunas> {
  String _consulta = '';

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
            Text('Selecciona la comuna', style: Theme.of(context).textTheme.titleMedium),
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
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
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
