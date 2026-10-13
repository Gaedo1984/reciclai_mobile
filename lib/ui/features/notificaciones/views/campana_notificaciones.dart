import 'package:flutter/material.dart';

import '../view_models/notificaciones_view_model.dart';
import 'hoja_notificaciones.dart';

class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key, required this.viewModel});

  final NotificacionesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        // El punto va pegado al icono, no al area de toque completa del
        // IconButton (48x48) -- Badge envuelve el Icon, no el IconButton.
        return IconButton(
          icon: Badge(
            isLabelVisible: viewModel.hayNoLeidas,
            smallSize: 8,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => _abrir(context),
        );
      },
    );
  }

  Future<void> _abrir(BuildContext context) async {
    // Refresca contra el backend cada vez que se toca la campana -- sin
    // ningun Timer en segundo plano (ver Global Constraints del plan).
    viewModel.cargar();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaNotificaciones(viewModel: viewModel),
    );
  }
}
