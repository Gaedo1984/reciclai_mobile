import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/como_reciclar/views/carrusel_pasos_modal.dart';
import 'package:reciclai_mobile/ui/features/como_reciclar/views/menu_lateral.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../fakes.dart';

Widget _envolver() => MaterialApp(
  home: Scaffold(
    appBar: AppBar(),
    drawer: const MenuLateral(),
    body: const SizedBox(),
  ),
);

void main() {
  testWidgets('el drawer arranca con "Como reciclar" colapsado, sin los materiales visibles', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('♻️ Cómo reciclar'), findsOneWidget);
    expect(find.text('Vidrio'), findsNothing);
  });

  testWidgets(
    'el drawer tiene "Materiales especiales" debajo de "Como reciclar", colapsado al abrir',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('♻️ Materiales especiales'), findsOneWidget);
      expect(find.text('Pilas'), findsNothing);

      final comoReciclar = tester.getTopLeft(find.text('♻️ Cómo reciclar'));
      final materialesEspeciales = tester.getTopLeft(find.text('♻️ Materiales especiales'));
      expect(materialesEspeciales.dy, greaterThan(comoReciclar.dy));
    },
  );

  testWidgets('al tocar "Materiales especiales" se despliegan los 6 materiales', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('♻️ Materiales especiales'));
    await tester.pumpAndSettle();

    expect(find.text('Pilas'), findsOneWidget);
    expect(find.text('Aceite usado'), findsOneWidget);
    expect(find.text('Latas de conserva'), findsOneWidget);
    expect(find.text('Filtros de jarro de agua'), findsOneWidget);
    expect(find.text('Envases de yogurt'), findsOneWidget);
    expect(find.text('Envases de aerosol'), findsOneWidget);
  });

  testWidgets('Envases de aerosol usa un icono real de spray, no un emoji', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('♻️ Materiales especiales'));
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('tocar un material especial cierra el drawer y abre su modal de pasos', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Materiales especiales'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilas'));
    await tester.pumpAndSettle();

    // El drawer ya no esta (se cerro).
    expect(find.text('Aceite usado'), findsNothing);
    // El modal del material tocado esta abierto -- mismo carrusel que "Como
    // reciclar".
    expect(find.byType(CarruselPasosModal), findsOneWidget);
    expect(find.text('Pilas'), findsOneWidget);
  });

  testWidgets('Pilas ya tiene sus 4 pasos reales, no el aviso de contenido pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Materiales especiales'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilas'));
    await tester.pumpAndSettle();

    expect(find.text('Pilas'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
    }
  });

  testWidgets('Aceite usado ya tiene sus 4 pasos reales, no el aviso de contenido pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Materiales especiales'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aceite usado'));
    await tester.pumpAndSettle();

    expect(find.text('Aceite usado'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
    }
  });

  testWidgets(
    'Latas de conserva ya tiene sus 4 pasos reales, no el aviso de contenido pendiente',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('♻️ Materiales especiales'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Latas de conserva'));
      await tester.pumpAndSettle();

      expect(find.text('Latas de conserva'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Filtros de jarro de agua ya tiene sus 4 pasos reales, no el aviso de contenido pendiente',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('♻️ Materiales especiales'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filtros de jarro de agua'));
      await tester.pumpAndSettle();

      expect(find.text('Filtros de jarro de agua'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Envases de yogurt ya tiene sus 4 pasos reales, no el aviso de contenido pendiente',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('♻️ Materiales especiales'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Envases de yogurt'));
      await tester.pumpAndSettle();

      expect(find.text('Envases de yogurt'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Envases de aerosol ya tiene sus 5 pasos reales, no el aviso de contenido pendiente',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('♻️ Materiales especiales'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Envases de aerosol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envases de aerosol'));
      await tester.pumpAndSettle();

      expect(find.text('Envases de aerosol'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
      }
    },
  );

  testWidgets('al tocar "Como reciclar" se despliegan los 5 materiales', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('♻️ Cómo reciclar'));
    await tester.pumpAndSettle();

    expect(find.text('Vidrio'), findsOneWidget);
    expect(find.text('Aluminio (latas de bebida)'), findsOneWidget);
    expect(find.text('Botellas de plástico'), findsOneWidget);
    expect(find.text('Cartón y papeles'), findsOneWidget);
    expect(find.text('Tetrapak'), findsOneWidget);
  });

  testWidgets('Botellas de plastico usa un icono real de botella, no un emoji', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Cómo reciclar'));
    await tester.pumpAndSettle();

    // 2, no 1: Vidrio tambien usa iconoSvg (ver mas abajo) -- el emoji de
    // vaso/frasco (🫙) es Unicode 14 (2021) y no se ve en Android 12 o
    // anterior sin el emoji font del sistema actualizado (bug real
    // reportado: "el icono de vidrio no aparece" en Android).
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });

  testWidgets('Vidrio usa un icono real de vaso, no el emoji 🫙', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Cómo reciclar'));
    await tester.pumpAndSettle();

    expect(find.text('🫙'), findsNothing);
  });

  testWidgets(
    'los iconos de material usan el color de icono del tema (no negro fijo), visible en claro y '
    'oscuro',
    (tester) async {
      for (final brillo in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brillo),
            home: Scaffold(appBar: AppBar(), drawer: const MenuLateral(), body: const SizedBox()),
          ),
        );
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('♻️ Cómo reciclar'));
        await tester.pumpAndSettle();

        final svgs = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
        expect(svgs, isNotEmpty);
        for (final svg in svgs) {
          expect(svg.colorFilter, isNotNull);
        }

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('tiene una X en la esquina superior derecha que cierra el drawer', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // El drawer ya no esta -- su contenido no aparece.
    expect(find.text('♻️ Cómo reciclar'), findsNothing);
  });

  testWidgets('la X usa el color de icono del tema, visible en claro y oscuro', (tester) async {
    for (final brillo in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brillo),
          home: Scaffold(appBar: AppBar(), drawer: const MenuLateral(), body: const SizedBox()),
        ),
      );
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      final icono = tester.widget<Icon>(find.byIcon(Icons.close));
      // Sin color fijo -- toma el color de icono ambiente del tema, que ya
      // se adapta solo entre claro/oscuro (a diferencia de una imagen
      // rasterizada con colores fijos, ver el logo de notificaciones).
      expect(icono.color, isNull);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('tocar un material cierra el drawer y abre su modal de pasos', (tester) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Cómo reciclar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vidrio'));
    await tester.pumpAndSettle();

    // El drawer ya no esta (se cerro).
    expect(find.text('Botellas de plástico'), findsNothing);
    // El modal del material tocado esta abierto.
    expect(find.byType(CarruselPasosModal), findsOneWidget);
    expect(find.text('Vidrio'), findsOneWidget);
  });

  testWidgets('Botellas de plastico ya tiene sus 5 pasos reales, no el aviso de contenido pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Cómo reciclar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Botellas de plástico'));
    await tester.pumpAndSettle();

    expect(find.text('Botellas de plástico'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
    }
  });

  testWidgets('Vidrio ya tiene sus 4 pasos reales, no el aviso de contenido pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♻️ Cómo reciclar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vidrio'));
    await tester.pumpAndSettle();

    expect(find.text('Vidrio'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
    }
  });

  testWidgets(
    'Aluminio (latas de bebida) ya tiene sus 4 pasos reales, no el aviso de contenido pendiente',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('♻️ Cómo reciclar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aluminio (latas de bebida)'));
      await tester.pumpAndSettle();

      expect(find.text('Aluminio (latas de bebida)'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Cartón y papeles ya tiene sus 7 pasos reales, no el aviso de contenido pendiente',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('♻️ Cómo reciclar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cartón y papeles'));
      await tester.pumpAndSettle();

      expect(find.text('Cartón y papeles'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('punto-indicador-7')), findsNothing);
    },
  );

  testWidgets(
    'Tetrapak ya tiene sus 3 pasos reales, no el aviso de contenido pendiente',
    (tester) async {
      await tester.pumpWidget(_envolver());
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('♻️ Cómo reciclar'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Tetrapak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetrapak'));
      await tester.pumpAndSettle();

      expect(find.text('Tetrapak'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Todavía no hay contenido para este material.'), findsNothing);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('punto-indicador-$i')), findsOneWidget);
      }
    },
  );

  testWidgets('al fondo del drawer, debajo de una linea separadora, estan Terminos y Privacidad', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsOneWidget);
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(find.text('Privacidad'), findsOneWidget);
  });

  testWidgets('tocar "Terminos y condiciones" abre la pagina publicada', (tester) async {
    final urlLauncherFalso = UrlLauncherPlatformFalso();
    UrlLauncherPlatform.instance = urlLauncherFalso;

    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Términos y condiciones'));
    await tester.pumpAndSettle();

    expect(urlLauncherFalso.urlsLanzadas, [
      'https://gaedo1984.github.io/reciclai_mobile/terminos.html',
    ]);
  });

  testWidgets('tocar "Privacidad" abre la pagina publicada', (tester) async {
    final urlLauncherFalso = UrlLauncherPlatformFalso();
    UrlLauncherPlatform.instance = urlLauncherFalso;

    await tester.pumpWidget(_envolver());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacidad'));
    await tester.pumpAndSettle();

    expect(urlLauncherFalso.urlsLanzadas, [
      'https://gaedo1984.github.io/reciclai_mobile/privacidad.html',
    ]);
  });
}
