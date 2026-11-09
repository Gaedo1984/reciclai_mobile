import 'package:flutter/material.dart';

import '../../../core/glass_bar_action.dart';
import '../view_models/map_view_model.dart';

/// Icono disparador del selector de radio en el `GlassBar` -- al tocarlo,
/// `onTap` (manejado por quien lo monta, `_MapViewState`) abre o cierra el
/// panel `RadiusSelectorPanel`. No administra su propio estado de
/// abierto/cerrado: ese es un detalle de UI transitorio, no una
/// responsabilidad de este icono (ver `map_view.dart`).
class RadiusSelectorTrigger extends StatelessWidget {
  const RadiusSelectorTrigger({super.key, required this.viewModel, required this.onTap});

  final MapViewModel viewModel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activo = viewModel.radioMetrosSeleccionado != null;
    return GlassBarAction(
      icon: activo ? Icons.wifi_tethering : Icons.wifi_tethering_outlined,
      color: activo ? Theme.of(context).colorScheme.primary : null,
      onTap: viewModel.tienePermisoDeUbicacion ? onTap : null,
    );
  }
}
