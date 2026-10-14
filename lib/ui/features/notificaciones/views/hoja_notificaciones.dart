import 'package:flutter/material.dart';

import '../../../../data/models/notificacion.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../formato_fecha.dart';
import '../view_models/notificaciones_view_model.dart';
import 'detalle_notificacion_modal.dart';

const _cantidadInicial = 5;
const _anchoColumnaFecha = 56.0;
const _anchoColumnaEstado = 20.0;

/// Panel de ancho completo que cuelga de la campana (`CampanaNotificaciones`,
/// que la monta como una ruta propia del Navigator pegada justo debajo del
/// AppBar, no superpuesta). Cada fila es una tabla de 2 columnas (fecha |
/// titulo) para que el titulo, por largo que sea, nunca pueda superponerse
/// con la fecha -- viven en columnas separadas, no pueden tocarse.
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
  // Explicito -- esto vive en una ruta propia sin PrimaryScrollController
  // implicito, asi que el Scrollbar(thumbVisibility: true) no lo encuentra
  // solo.
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
    final alturaMaxima =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        alturaAppBar -
        espacioLg;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(radioDeHojaFlotante),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            espacioMd,
            espacioSm,
            espacioMd,
            espacioSm,
          ),
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
                      Image.asset(
                        'assets/branding/reciclai_news.png',
                        height: 32,
                        fit: BoxFit.contain,
                        semanticLabel: 'Notificaciones',
                      ),
                      BotonCerrarHoja(onTap: widget.onCerrar),
                    ],
                  ),
                  // espacioXs (4px), no espacioMd (16px) -- un tester lo
                  // reporto como demasiado separado del titulo.
                  const SizedBox(height: espacioXs),
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
                        child: ListView.separated(
                          controller: _scrollController,
                          shrinkWrap: true,
                          itemCount: mostrar.length + (hayMas ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const Divider(height: espacioMd),
                          itemBuilder: (context, index) {
                            if (index < mostrar.length) {
                              return _FilaNotificacion(
                                notificacion: mostrar[index],
                                leida: widget.viewModel.estaLeida(
                                  mostrar[index].id,
                                ),
                                onTap: () =>
                                    _abrirDetalle(context, mostrar[index]),
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
      ),
    );
  }
}

class _FilaNotificacion extends StatelessWidget {
  const _FilaNotificacion({
    required this.notificacion,
    required this.leida,
    required this.onTap,
  });

  final Notificacion notificacion;
  final bool leida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: espacioSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _anchoColumnaFecha,
              child: Text(
                formatearFechaCorta(notificacion.creadaEn),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: espacioSm),
            // Columna de ancho fijo para el estado (icono de marca / check)
            // -- asi el titulo arranca siempre en la misma posicion sin
            // importar si la fila esta leida o no, consistente con el resto
            // de la tabla (fecha | estado | titulo).
            SizedBox(
              width: _anchoColumnaEstado,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: leida
                    ? Icon(Icons.check, size: 16, color: colores.primary)
                    : Image.asset('assets/branding/icono_marcador.png', width: 16, height: 16),
              ),
            ),
            const SizedBox(width: espacioSm),
            Expanded(
              child: Text(
                notificacion.titulo,
                style: TextStyle(
                  fontWeight: leida ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
