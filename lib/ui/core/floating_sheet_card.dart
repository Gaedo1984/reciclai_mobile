import 'package:flutter/material.dart';

/// Tarjeta flotante para hojas modales: bordes redondeados en las 4 esquinas
/// y separada del borde inferior de la pantalla, en vez del rectángulo pegado
/// abajo que da `showModalBottomSheet` por defecto. El `builder` que la use
/// debe pasar `backgroundColor: Colors.transparent` a `showModalBottomSheet`
/// para que el redondeo se vea contra el scrim, no contra un fondo cuadrado.
const radioDeHojaFlotante = 20.0;

class FloatingSheetCard extends StatelessWidget {
  const FloatingSheetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radioDeHojaFlotante),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
