import 'package:flutter/material.dart';

/// Paleta "Bosque moderno": un verde salvia suave como base tonal, con un
/// único acento terracota reservado para la acción principal del filtro
/// (botón "Aplicar" y el ícono de filtro activo) — el resto de la pantalla
/// se queda en tonos neutros cálidos derivados del mismo verde, en vez del
/// verde saturado y la superficie gris fría que da el seed por defecto de
/// Material 3.
const colorSemillaBosque = Color(0xFF5C8374);

const _terracotaClaro = Color(0xFFC97C5D);
const _terracotaContainerClaro = Color(0xFFF3D9CB);
const _onTerracotaContainerClaro = Color(0xFF5C2E1B);

const _terracotaOscuro = Color(0xFFE0A084);
const _terracotaContainerOscuro = Color(0xFF6B3A22);
const _onTerracotaContainerOscuro = Color(0xFFF3D9CB);

const _superficieClara = Color(0xFFF5F1E8);
const _onSuperficieClara = Color(0xFF20281F);
const _superficieOscura = Color(0xFF16211C);
const _onSuperficieOscura = Color(0xFFE9EDE7);

// Contenedor elevado (hojas flotantes: FloatingSheetCard) — un escalon de
// elevacion sobre la superficie base, pero en la misma familia calida en
// vez del tono verdoso que `ColorScheme.fromSeed` deriva por defecto.
const _superficieContenedorClara = Color(0xFFECE4D3);
const _superficieContenedorOscura = Color(0xFF212E27);

ThemeData construirTemaReciclai(Brightness brillo) {
  final claro = brillo == Brightness.light;
  final esquema = ColorScheme.fromSeed(seedColor: colorSemillaBosque, brightness: brillo).copyWith(
    secondary: claro ? _terracotaClaro : _terracotaOscuro,
    onSecondary: claro ? Colors.white : const Color(0xFF3D2013),
    secondaryContainer: claro ? _terracotaContainerClaro : _terracotaContainerOscuro,
    onSecondaryContainer: claro ? _onTerracotaContainerClaro : _onTerracotaContainerOscuro,
    surface: claro ? _superficieClara : _superficieOscura,
    onSurface: claro ? _onSuperficieClara : _onSuperficieOscura,
    surfaceContainerHigh: claro ? _superficieContenedorClara : _superficieContenedorOscura,
  );

  final base = ThemeData(colorScheme: esquema, useMaterial3: true);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(letterSpacing: 0.1),
    ),
  );
}
