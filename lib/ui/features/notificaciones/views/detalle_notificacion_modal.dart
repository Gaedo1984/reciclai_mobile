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
    // Tope de alto + el cuerpo en un SingleChildScrollView propio -- sin
    // esto, un cuerpo largo (el backend no le pone limite de longitud a
    // `texto`) desborda el Dialog por abajo y los links cerca del final
    // (justo donde suelen ir) quedan inalcanzables. Mismo fix que ya usa
    // point_details_sheet.dart para su propio contenido largo.
    final alturaMaxima = MediaQuery.of(context).size.height * 0.7;
    return PopScope(
      canPop: false,
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: alturaMaxima),
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
                      child: Text(
                        notificacion.titulo,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: espacioSm),
                Flexible(
                  child: SingleChildScrollView(
                    child: TextoConLinks(texto: notificacion.texto),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
