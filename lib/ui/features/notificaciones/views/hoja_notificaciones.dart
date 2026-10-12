import 'package:flutter/material.dart';

import '../../../../data/models/notificacion.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../view_models/notificaciones_view_model.dart';
import 'detalle_notificacion_modal.dart';

const _cantidadInicial = 5;

/// Mismo criterio que el modal de detalle: solo la X cierra, ni el boton
/// atras ni tocar afuera (quien la abre, con el bloqueado, confirma que
/// `isDismissible: false`/`enableDrag: false` ya aplicados por
/// `CampanaNotificaciones` al abrirla).
class HojaNotificaciones extends StatefulWidget {
  const HojaNotificaciones({super.key, required this.viewModel});

  final NotificacionesViewModel viewModel;

  @override
  State<HojaNotificaciones> createState() => _HojaNotificacionesState();
}

class _HojaNotificacionesState extends State<HojaNotificaciones> {
  bool _mostrarTodas = false;

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
    return PopScope(
      canPop: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FloatingSheetCard(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              final todas = widget.viewModel.notificaciones;
              // El corte es estrictamente > 5, no >= 5 -- con exactamente 5
              // no debe aparecer "Mostrar todas" (ver Review Focus del plan).
              final hayMas = !_mostrarTodas && todas.length > _cantidadInicial;
              final mostrar = _mostrarTodas ? todas : todas.take(_cantidadInicial).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Notificaciones', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: espacioMd),
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: mostrar.length + (hayMas ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < mostrar.length) {
                            final notificacion = mostrar[index];
                            final leida = widget.viewModel.estaLeida(notificacion.id);
                            return ListTile(
                              onTap: () => _abrirDetalle(context, notificacion),
                              leading: leida
                                  ? null
                                  : Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              title: Text(
                                notificacion.titulo,
                                style: TextStyle(
                                  fontWeight: leida ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return TextButton(
                            onPressed: () => setState(() => _mostrarTodas = true),
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
      ),
    );
  }
}
