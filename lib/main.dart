import 'package:flutter/material.dart';

import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';

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
      home: HomeView(viewModel: HomeViewModel()),
    );
  }
}
