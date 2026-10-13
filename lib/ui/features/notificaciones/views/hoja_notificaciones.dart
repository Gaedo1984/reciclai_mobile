import 'package:flutter/material.dart';

import '../../../../data/models/notificacion.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../formato_fecha.dart';
import '../view_models/notificaciones_view_model.dart';
import 'detalle_notificacion_modal.dart';

const _cantidadInicial = 5;
const _anchoPanel = 320.0;

/// Dropdown que cuelga de la campana (`CampanaNotificaciones`, que la monta
/// en un `OverlayEntry` anclado debajo del icono) -- no es una ruta propia,
/// asi que no hay nada que el boton atras del sistema pueda cerrar. La
/// barrera transparente que pone `CampanaNotificaciones` detras absorbe los
/// toques afuera sin cerrarla -- solo `onCerrar` (la X) la cierra.
class HojaNotificaciones extends StatefulWidget {
  const HojaNotificaciones({
    super.key,
    required this.viewModel,
    required this.onCerrar,
  });

  final NotificacionesViewModel viewModel;
  final VoidCallback onCerrar;

  @override
  State<HojaNotificaciones> createState() => _HojaNotificacionesState();
}

class _HojaNotificacionesState extends State<HojaNotificaciones> {
  bool _mostrarTodas = false;
  // Explicito -- sin ruta propia (esto vive en un OverlayEntry, no en una
  // ruta), no hay un PrimaryScrollController implicito para que el
  // Scrollbar(thumbVisibility: true) lo encuentre solo.
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _abrirDetalle(BuildContext context, Notificacion notificacion) {
    widget.viewModel.marcarLeida(notificacion.id);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DetalleNotificacionModal(notificacion: notificacion),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchoDisponible = MediaQuery.of(context).size.width - espacioMd * 2;
    return SizedBox(
      width: _anchoPanel > anchoDisponible ? anchoDisponible : _anchoPanel,
      child: FloatingSheetCard(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final todas = widget.viewModel.notificaciones;
            // El corte es estrictamente > 5, no >= 5 -- con exactamente 5
            // no debe aparecer "Mostrar todas" (ver Review Focus del plan).
            final hayMas = !_mostrarTodas && todas.length > _cantidadInicial;
            final mostrar = _mostrarTodas
                ? todas
                : todas.take(_cantidadInicial).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Notificaciones',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    BotonCerrarHoja(onTap: widget.onCerrar),
                  ],
                ),
                const SizedBox(height: espacioMd),
                if (todas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: espacioLg),
                    child: Text('No hay notificaciones'),
                  )
                else
                  Flexible(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        itemCount: mostrar.length + (hayMas ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < mostrar.length) {
                            final notificacion = mostrar[index];
                            final leida = widget.viewModel.estaLeida(
                              notificacion.id,
                            );
                            return ListTile(
                              onTap: () => _abrirDetalle(context, notificacion),
                              leading: leida
                                  ? null
                                  : Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              title: Text(
                                notificacion.titulo,
                                style: TextStyle(
                                  fontWeight: leida
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                formatearFechaCorta(notificacion.creadaEn),
                              ),
                            );
                          }
                          return TextButton(
                            onPressed: () =>
                                setState(() => _mostrarTodas = true),
                            child: const Text('Mostrar todas'),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
