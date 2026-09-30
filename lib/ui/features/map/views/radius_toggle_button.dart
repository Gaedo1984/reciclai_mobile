import 'package:flutter/material.dart';

import '../../../core/glass_bar_action.dart';
import '../view_models/map_view_model.dart';

class RadiusToggleButton extends StatelessWidget {
  const RadiusToggleButton({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final activo = viewModel.radioActivo;
    return GlassBarAction(
      icon: activo ? Icons.wifi_tethering : Icons.wifi_tethering_outlined,
      color: activo ? Theme.of(context).colorScheme.secondary : null,
      onTap: viewModel.tienePermisoDeUbicacion ? () => viewModel.alternarRadio(!activo) : null,
    );
  }
}
