import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/reciclai_api_client.dart';
import 'domain/location_service.dart';
import 'ui/core/theme.dart';
import 'ui/features/map/view_models/map_view_model.dart';
import 'ui/features/splash/splash_view.dart';

Future<void> main() async {
  // La UI (AppBar, GlassBar, el mapa) esta pensada solo para vertical -- sin
  // esto, girar el telefono la rompe (nada se reacomoda para horizontal).
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ReciclaiApp());
}

class ReciclaiApp extends StatelessWidget {
  const ReciclaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReciclAI',
      theme: construirTemaReciclai(Brightness.light),
      darkTheme: construirTemaReciclai(Brightness.dark),
      themeMode: ThemeMode.system,
      home: SplashView(
        viewModel: MapViewModel(
          apiClient: ReciclaiApiClient(),
          locationService: LocationService(),
        ),
      ),
    );
  }
}
