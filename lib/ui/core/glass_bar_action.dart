import 'package:flutter/material.dart';

const _diametro = 48.0;

// Contorno negro solido: una sombra por direccion (sin blur, bien opaca) para
// que se vea como un borde nitido en vez de un halo difuso. Sirve para que el
// icono se note tanto sobre un vidrio claro como uno oscuro, sin depender del
// color de lo que haya detras (el mapa puede ser de cualquier tono).
const _direccionesDeContorno = [
  Offset(-1, -1), Offset(0, -1), Offset(1, -1),
  Offset(-1, 0), Offset(1, 0),
  Offset(-1, 1), Offset(0, 1), Offset(1, 1),
];

/// Un ícono tocable, sin chrome propio (sin blur/tinte/borde) — pensado para
/// vivir dentro de un `GlassBar`, que es quien pone el vidrio esmerilado
/// compartido para todos sus hijos.
class GlassBarAction extends StatelessWidget {
  const GlassBarAction({super.key, required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback? onTap;

  /// Color del ícono. Por defecto blanco intenso, para que se note sobre el
  /// vidrio; se puede sobreescribir para resaltar un estado activo (p. ej.
  /// el acento del tema cuando un filtro está aplicado).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _diametro,
          height: _diametro,
          child: Icon(
            icon,
            color: color ?? Colors.white,
            shadows: [
              for (final direccion in _direccionesDeContorno)
                Shadow(color: Colors.black.withValues(alpha: 0.85), offset: direccion),
              Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
