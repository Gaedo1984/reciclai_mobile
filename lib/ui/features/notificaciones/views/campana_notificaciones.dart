import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../view_models/notificaciones_view_model.dart';
import 'hoja_notificaciones.dart';

/// Campana con punto rojo en el AppBar -- al tocarla, cuelga el panel de
/// notificaciones pegado justo debajo del AppBar (ancho completo, no
/// superpuesto con el header), como si fuera parte del cuerpo de la
/// pantalla. Se abre como una ruta del Navigator (no un `OverlayEntry`
/// crudo insertado a mano): el modal de detalle tambien se abre via el
/// Navigator (`showDialog`), y dos `OverlayEntry` sin relacion entre si no
/// tienen garantizado un orden de apilado consistente -- bug real
/// encontrado probando en el celular: la X del modal no cerraba nada,
/// habia que cerrar la hoja primero, porque terminaba quedando ARRIBA del
/// modal en vez de abajo. Pasando el panel tambien por el Navigator, ambos
/// quedan ordenados por el mismo mecanismo y el modal (abierto despues)
/// queda arriba, como corresponde.
class CampanaNotificaciones extends StatefulWidget {
  const CampanaNotificaciones({super.key, required this.viewModel});

  final NotificacionesViewModel viewModel;

  @override
  State<CampanaNotificaciones> createState() => _CampanaNotificacionesState();
}

class _CampanaNotificacionesState extends State<CampanaNotificaciones> {
  bool _abierta = false;

  void _alternar() {
    if (_abierta) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    // Refresca contra el backend cada vez que se toca la campana -- sin
    // ningun Timer en segundo plano (ver Global Constraints del plan).
    widget.viewModel.cargar();

    setState(() => _abierta = true);
    Navigator.of(context, rootNavigator: true)
        .push(
          PageRouteBuilder<void>(
            opaque: false,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, animation, secondaryAnimation) {
              return PopScope(
                // Solo la X del panel cierra -- ni el boton atras del
                // sistema ni tocar afuera (la barrera de abajo absorbe el
                // toque sin cerrar).
                canPop: false,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: AbsorbPointer(child: SizedBox.expand()),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + alturaAppBar,
                      left: 0,
                      right: 0,
                      child: HojaNotificaciones(
                        viewModel: widget.viewModel,
                        onCerrar: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        )
        .then((_) {
          if (mounted) setState(() => _abierta = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        // El punto va pegado al icono, no al area de toque completa del
        // IconButton (48x48) -- Badge envuelve el Icon, no el IconButton.
        return IconButton(
          icon: Badge(
            isLabelVisible: widget.viewModel.hayNoLeidas,
            smallSize: 8,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: _alternar,
        );
      },
    );
  }
}
