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
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: MapView(
        viewModel: MapViewModel(
          apiClient: ReciclaiApiClient(),
          locationService: LocationService(),
        ),
      ),
    );
  }
}
