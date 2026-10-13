import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../view_models/notificaciones_view_model.dart';
import 'hoja_notificaciones.dart';

/// Campana con punto rojo en el AppBar -- al tocarla, cuelga la hoja justo
/// debajo de si misma (mismo patron del `OverlayEntry` que ya usa
/// `TourOverlay` en `map_view.dart`: ancla via un `GlobalKey` + `RenderBox`,
/// no una ruta nueva), para que se vea como una extension de la campana en
/// vez de una hoja que sube desde el borde inferior de toda la pantalla.
class CampanaNotificaciones extends StatefulWidget {
  const CampanaNotificaciones({super.key, required this.viewModel});

  final NotificacionesViewModel viewModel;

  @override
  State<CampanaNotificaciones> createState() => _CampanaNotificacionesState();
}

class _CampanaNotificacionesState extends State<CampanaNotificaciones> {
  final _keyCampana = GlobalKey();
  OverlayEntry? _entrada;

  @override
  void dispose() {
    _entrada?.remove();
    super.dispose();
  }

  void _alternar() {
    if (_entrada != null) {
      _cerrar();
      return;
    }
    // Refresca contra el backend cada vez que se toca la campana -- sin
    // ningun Timer en segundo plano (ver Global Constraints del plan).
    widget.viewModel.cargar();

    final renderBox =
        _keyCampana.currentContext!.findRenderObject() as RenderBox;
    final posicion = renderBox.localToGlobal(Offset.zero);
    final entrada = OverlayEntry(
      builder: (context) {
        final anchoPantalla = MediaQuery.of(context).size.width;
        return Stack(
          children: [
            // Absorbe los toques afuera (para que no lleguen al mapa de
            // atras) SIN cerrar la hoja -- solo su propia X la cierra, mismo
            // criterio que ya exigia isDismissible:false en el bottom sheet
            // que esto reemplaza.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
            Positioned(
              top: posicion.dy + renderBox.size.height + espacioXs,
              right: anchoPantalla - (posicion.dx + renderBox.size.width),
              child: HojaNotificaciones(
                viewModel: widget.viewModel,
                onCerrar: _cerrar,
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(entrada);
    setState(() => _entrada = entrada);
  }

  void _cerrar() {
    _entrada?.remove();
    setState(() => _entrada = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        // El punto va pegado al icono, no al area de toque completa del
        // IconButton (48x48) -- Badge envuelve el Icon, no el IconButton.
        return IconButton(
          key: _keyCampana,
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
