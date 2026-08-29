import 'package:flutter/material.dart';

import '../view_models/home_view_model.dart';

/// View: lean widget, only renders. All data comes from the ViewModel.
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ReciclAI')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return Center(
            child: Text(
              viewModel.greeting,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          );
        },
      ),
    );
  }
}
