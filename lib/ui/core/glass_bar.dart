import 'dart:ui';

import 'package:flutter/material.dart';

import 'spacing.dart';

const _difuminado = 24.0;
const _alphaDelTinte = 0.28;
const _alphaDelBorde = 0.45;
const _radioPildora = 999.0;

/// Barra flotante "vidrio esmerilado" con los extremos totalmente
/// redondeados (forma píldora) — blur + tinte translúcido + borde sutil, al
/// estilo de las barras flotantes de apps como WhatsApp. Sus `children` van
/// en fila, compartiendo este mismo fondo de vidrio; cada uno es responsable
/// de su propia zona tocable (ver `GlassBarAction`).
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radioPildora),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _difuminado, sigmaY: _difuminado),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: espacioXs),
          decoration: BoxDecoration(
            color: colores.surface.withValues(alpha: _alphaDelTinte),
            borderRadius: BorderRadius.circular(_radioPildora),
            border: Border.all(color: Colors.white.withValues(alpha: _alphaDelBorde)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
