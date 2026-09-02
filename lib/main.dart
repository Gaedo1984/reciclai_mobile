import 'package:flutter/material.dart';

import 'data/reciclai_api_client.dart';
import 'domain/location_service.dart';
import 'ui/core/theme.dart';
import 'ui/features/map/view_models/map_view_model.dart';
import 'ui/features/splash/splash_view.dart';

void main() {
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
