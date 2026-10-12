import 'package:flutter/material.dart';

import '../../../../data/models/notificacion.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import 'texto_con_links.dart';

/// Mismo criterio que la hoja (`HojaNotificaciones`): solo la X cierra,
/// ni el boton atras ni tocar afuera -- una notificacion que el usuario
/// ya abrio no deberia "perderse" por un gesto accidental antes de
/// terminar de leerla.
class DetalleNotificacionModal extends StatelessWidget {
  const DetalleNotificacionModal({super.key, required this.notificacion});

  final Notificacion notificacion;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(espacioMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(notificacion.titulo, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: espacioSm),
              TextoConLinks(texto: notificacion.texto),
            ],
          ),
        ),
      ),
    );
  }
}
