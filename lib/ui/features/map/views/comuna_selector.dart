import 'package:flutter/material.dart';

import '../../../../data/models/comuna.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/glass_bar_action.dart';
import '../../../core/spacing.dart';

class ComunaSelector extends StatelessWidget {
  const ComunaSelector({super.key, required this.comunas, required this.onElegirComuna});

  final List<Comuna> comunas;
  final void Function(String comunaId) onElegirComuna;

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
