import 'package:flutter/material.dart';

const _diametro = 48.0;

/// Un ícono tocable, sin chrome propio (sin blur/tinte/borde) — pensado para
/// vivir dentro de un `GlassBar`, que es quien pone el vidrio esmerilado
/// compartido para todos sus hijos.
class GlassBarAction extends StatelessWidget {
  const GlassBarAction({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

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
            color: Colors.white,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
