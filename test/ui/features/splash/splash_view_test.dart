import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/splash/splash_view.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../fakes.dart';

void main() {
  late VideoPlayerPlatform plataformaOriginal;

  setUp(() {
    plataformaOriginal = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = VideoPlayerPlatformFalso();
  });

  tearDown(() {
    VideoPlayerPlatform.instance = plataformaOriginal;
  });

  MapViewModel viewModelDePrueba() {
    return MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
  }

  testWidgets('muestra un spinner mientras carga, para no verse pegada', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SplashView(viewModel: viewModelDePrueba())));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('no se desborda en ventanas bajas (ej. macOS achicada), una vez que el '
      'video termino de inicializarse', (tester) async {
    // Visto en macOS con una ventana chica: el contenido de intro + spinner
    // juntos superaban el alto disponible ("BOTTOM OVERFLOWED"). 800x500
    // logicos reproduce ese espacio reducido.
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: SplashView(viewModel: viewModelDePrueba())));
    await tester.pump(); // build inicial
    await tester.pump(); // procesa el evento "initialized" del fake (microtask)

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'una vez que el video completa una vuelta y los datos estan listos, pasa al mapa',
      (tester) async {
    final viewModel = viewModelDePrueba();
    await tester.pumpWidget(MaterialApp(home: SplashView(viewModel: viewModel)));
    await tester.pump(); // build inicial
    await tester.pump(); // "initialized" -> controller llama play()

    // El controller real lee la posicion via un timer periodico de 100ms; el
    // fake ya deja la posicion en el final apenas se llama play().
    await tester.pump(const Duration(milliseconds: 150));
    // Deja terminar la transicion de pushReplacement — sin pumpAndSettle:
    // MapView tiene animaciones infinitas propias (el pulso del boton de
    // Tour) que nunca asientan.
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(SplashView), findsNothing);
  });
}
