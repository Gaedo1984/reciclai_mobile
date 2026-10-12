import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/glass_bar.dart';
import '../../../core/spacing.dart';
import '../view_models/map_view_model.dart';

/// Panel de 4 distancias (Off / 3 / 5 / 7 km), pensado para vivir pegado
/// arriba de la barra principal (`GlassBar`) en `map_view.dart` -- reusa el
/// mismo `GlassBar` (mismo vidrio esmerilado) para que se lea como una
/// extension de esa barra, no como una tarjeta/aviso aparte.
class RadiusSelectorPanel extends StatelessWidget {
  const RadiusSelectorPanel({super.key, required this.viewModel, required this.onCerrar});

  final MapViewModel viewModel;
  final VoidCallback onCerrar;

  void _elegir(double? metros) {
    viewModel.seleccionarRadio(metros);
    onCerrar();
  }

  @override
  Widget build(BuildContext context) {
    final seleccionado = viewModel.radioMetrosSeleccionado;
    return GlassBar(
      children: [
        for (final metros in MapViewModel.radiosDisponiblesMetros) ...[
          _BotonDeRadio(
            etiqueta: '${(metros / 1000).round()} km',
            seleccionado: seleccionado == metros,
            onTap: () => _elegir(metros),
          ),
          const SizedBox(width: 1.5),
        ],
        _BotonDeRadio(
          etiqueta: 'Off',
          seleccionado: false,
          habilitado: seleccionado != null,
          onTap: () => _elegir(null),
        ),
        const SizedBox(width: espacioXs),
        BotonCerrarHoja(onTap: onCerrar, color: Colors.white),
      ],
    );
  }
}

class _BotonDeRadio extends StatelessWidget {
  const _BotonDeRadio({
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
    this.habilitado = true,
  });

  final String etiqueta;
  final bool seleccionado;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final colorTexto = seleccionado
        ? colores.onPrimary
        : (habilitado ? Colors.white : Colors.white.withValues(alpha: 0.4));
    return Material(
      color: seleccionado ? colores.primary : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: habilitado ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: espacioSm, vertical: espacioXs),
          child: Text(
            etiqueta,
            // Sombra oscura, mismo motivo que el contorno de `GlassBarAction`
            // -- sin ella, el texto blanco se perdia sobre el vidrio cuando
            // el mapa debajo es claro (hallazgo de la revision final).
            style: TextStyle(
              color: colorTexto,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}
