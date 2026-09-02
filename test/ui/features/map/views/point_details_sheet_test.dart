import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/ui/core/material_colors.dart';
import 'package:reciclai_mobile/ui/features/map/views/point_details_sheet.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../fakes.dart';

RecyclingPoint _punto() {
  return RecyclingPoint(
    id: '1',
    nombre: 'Punto Limpio',
    direccion: 'Av. Siempre Viva 123',
    ubicacion: const LatLng(-33.52, -70.60),
    tipo: 'punto_limpio',
    materiales: const ['plastico', 'vidrio'],
    horario: null,
    esEmpresa: false,
    sitioWeb: null,
    confianza: 'media',
  );
}

void main() {
  testWidgets('cada chip de material usa el color de su categoria', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointDetailsSheet(punto: _punto()))));

    final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
    expect(chips, hasLength(2));

    final avatarPlastico = chips[0].avatar as CircleAvatar;
    expect(avatarPlastico.backgroundColor, colorParaMaterial('plastico'));

    final avatarVidrio = chips[1].avatar as CircleAvatar;
    expect(avatarVidrio.backgroundColor, colorParaMaterial('vidrio'));
  });

  testWidgets('sin posicion conocida, no muestra la distancia', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointDetailsSheet(punto: _punto()))));

    expect(find.textContaining(' km'), findsNothing);
    expect(find.textContaining(' m'), findsNothing);
  });

  testWidgets('con posicion conocida, muestra la distancia formateada hacia el punto', (
    tester,
  ) async {
    // El punto esta en (-33.52, -70.60); una posicion muy cerca para que la
    // distancia caiga bajo 1 km y sea facil de verificar sin acoplarse a la
    // formula exacta de Geolocator.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointDetailsSheet(punto: _punto(), miUbicacion: const LatLng(-33.5205, -70.6005)),
        ),
      ),
    );

    expect(find.textContaining(' m'), findsOneWidget);
  });

  testWidgets('muestra un boton "Ruta" con su icono', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointDetailsSheet(punto: _punto()))));

    expect(find.widgetWithText(OutlinedButton, 'Ruta'), findsOneWidget);
    expect(find.byIcon(Icons.directions), findsOneWidget);
  });

  testWidgets('tocar "Ruta" abre una hoja con Google Maps y Waze, sin Maps (no es iOS)', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointDetailsSheet(punto: _punto()))));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ruta'));
    await tester.pumpAndSettle();

    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Waze'), findsOneWidget);
    expect(find.text('Maps'), findsNothing);
  });

  testWidgets('en iOS, la hoja de Ruta tambien ofrece Maps', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointDetailsSheet(punto: _punto()))));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ruta'));
    await tester.pumpAndSettle();

    expect(find.text('Maps'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('tocar una opcion de la hoja lanza su link universal y cierra la hoja', (
    tester,
  ) async {
    final urlLauncherFalso = UrlLauncherPlatformFalso();
    UrlLauncherPlatform.instance = urlLauncherFalso;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointDetailsSheet(punto: _punto()))));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ruta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();

    expect(
      urlLauncherFalso.urlsLanzadas,
      contains('https://www.google.com/maps/dir/?api=1&destination=-33.52,-70.6'),
    );
    expect(find.text('Google Maps'), findsNothing);
  });
}
