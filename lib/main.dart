import 'package:flutter/material.dart';

import 'data/reciclai_api_client.dart';
import 'domain/location_service.dart';
import 'ui/features/map/view_models/map_view_model.dart';
import 'ui/features/map/views/map_view.dart';

void main() {
  runApp(const ReciclaiApp());
}

class ReciclaiApp extends StatelessWidget {
  const ReciclaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReciclAI',
      theme: _construirTema(Brightness.light),
      darkTheme: _construirTema(Brightness.dark),
      themeMode: ThemeMode.system,
      home: MapView(
        viewModel: MapViewModel(
          apiClient: ReciclaiApiClient(),
          locationService: LocationService(),
        ),
      ),
    );
  }
}

ThemeData _construirTema(Brightness brillo) {
  final base = ThemeData(
    colorSchemeSeed: Colors.green,
    brightness: brillo,
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(letterSpacing: 0.1),
    ),
  );
}
