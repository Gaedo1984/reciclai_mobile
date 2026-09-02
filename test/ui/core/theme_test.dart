import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/core/theme.dart';

void main() {
  test('el color primario se deriva de la semilla verde bosque, en ambos modos', () {
    for (final brillo in Brightness.values) {
      final esperado = ColorScheme.fromSeed(
        seedColor: colorSemillaBosque,
        brightness: brillo,
      ).primary;

      expect(construirTemaReciclai(brillo).colorScheme.primary, esperado);
    }
  });

  test('el acento (secondary) es terracota, distinto entre modo claro y oscuro', () {
    final claro = construirTemaReciclai(Brightness.light).colorScheme;
    final oscuro = construirTemaReciclai(Brightness.dark).colorScheme;

    expect(claro.secondary, isNot(claro.primary));
    expect(oscuro.secondary, isNot(oscuro.primary));
    expect(claro.secondary, isNot(oscuro.secondary));
  });

  test('el contenedor del acento tiene contraste legible con su texto', () {
    for (final brillo in Brightness.values) {
      final esquema = construirTemaReciclai(brillo).colorScheme;
      final contraste = esquema.secondaryContainer.computeLuminance() >
          esquema.onSecondaryContainer.computeLuminance()
          ? esquema.secondaryContainer.computeLuminance()
          : esquema.onSecondaryContainer.computeLuminance();
      final oscuridad = esquema.secondaryContainer.computeLuminance() <
          esquema.onSecondaryContainer.computeLuminance()
          ? esquema.secondaryContainer.computeLuminance()
          : esquema.onSecondaryContainer.computeLuminance();

      // Razon de contraste minima informal (no WCAG estricto): evita
      // texto casi invisible sobre su propio contenedor.
      expect((contraste + 0.05) / (oscuridad + 0.05), greaterThan(2.5));
    }
  });

  test('la superficie es un neutro calido, no el gris frio por defecto de Material', () {
    final claro = construirTemaReciclai(Brightness.light).colorScheme;
    final oscuro = construirTemaReciclai(Brightness.dark).colorScheme;

    expect(claro.surface, const Color(0xFFF5F1E8));
    expect(oscuro.surface, const Color(0xFF16211C));
  });

  test('el contenedor elevado (hojas flotantes) tambien es del mismo neutro calido', () {
    final claro = construirTemaReciclai(Brightness.light).colorScheme;
    final oscuro = construirTemaReciclai(Brightness.dark).colorScheme;

    // Debe notarse un escalon de elevacion respecto a la superficie base,
    // pero seguir en la misma familia calida (no el tono verdoso que
    // deriva el seed por defecto para surfaceContainerHigh).
    expect(claro.surfaceContainerHigh, isNot(claro.surface));
    expect(claro.surfaceContainerHigh, const Color(0xFFECE4D3));
    expect(oscuro.surfaceContainerHigh, isNot(oscuro.surface));
    expect(oscuro.surfaceContainerHigh, const Color(0xFF212E27));
  });

  test('los titulos son mas pesados y compactos que el cuerpo del texto', () {
    final texto = construirTemaReciclai(Brightness.light).textTheme;

    expect(texto.titleLarge!.fontWeight, FontWeight.w800);
    expect(texto.titleMedium!.fontWeight, FontWeight.w700);
    expect(texto.titleLarge!.letterSpacing, lessThan(0));
    expect(texto.bodyMedium!.letterSpacing, 0.1);
  });
}
