import 'package:flutter/material.dart';

/// Tarjeta flotante para hojas modales: bordes redondeados en las 4 esquinas
/// y separada del borde inferior de la pantalla, en vez del rectángulo pegado
/// abajo que da `showModalBottomSheet` por defecto. El `builder` que la use
/// debe pasar `backgroundColor: Colors.transparent` a `showModalBottomSheet`
/// para que el redondeo se vea contra el scrim, no contra un fondo cuadrado.
const radioDeHojaFlotante = 20.0;

/// Margen minimo entre el borde superior de la pantalla y la tarjeta, sumado al
/// area segura (notch/isla dinamica/barra de estado). Sin esto, una hoja con
/// contenido largo (el listado completo de materiales o comunas) crecia hasta
/// tocar el borde superior — `showModalBottomSheet(isScrollControlled: true)` le
/// da al builder casi toda la altura de la pantalla como limite, y la tarjeta no
/// tenia un tope propio mas estricto. Pegada arriba, los controles del
/// encabezado (filtros, boton de cerrar) quedaban incomodos de alcanzar.
const _margenSuperiorMinimo = 56.0;

/// Botón "X" para el encabezado de una hoja modal (`FloatingSheetCard`) — le
/// da al usuario una forma explícita de cerrar además de deslizar/tocar
/// afuera, que en un modal alto (como el listado completo de comunas o
/// materiales) no siempre es obvio. Tamaño compacto (sin el área de toque
/// Material completa de 48px) para no inflar el alto de la fila del título,
/// mismo motivo por el que "Borrar comuna"/"Borrar filtros" ya usan
/// `tapTargetSize: shrinkWrap`.
class BotonCerrarHoja extends StatelessWidget {
  const BotonCerrarHoja({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.close),
      tooltip: 'Cerrar',
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }
}

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
    // Se resta tambien el teclado (viewInsets.bottom): sin esto, el tope dejaba
    // de ser la restriccion mas estricta apenas aparecia el teclado (la
    // restriccion real, ya achicada por el teclado via el Padding que envuelve
    // esta tarjeta en los buscadores, pasaba a ser mayor que este tope) y la
    // tarjeta volvia a crecer hasta pegarse arriba.
    final alturaMaxima = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).viewInsets.bottom -
        _margenSuperiorMinimo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radioDeHojaFlotante),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
