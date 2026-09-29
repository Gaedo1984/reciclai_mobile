import 'dart:async';

import 'package:flutter/material.dart';

import '../map/view_models/map_state.dart';
import '../map/view_models/map_view_model.dart';
import '../map/views/map_view.dart';
import 'splash_readiness.dart';

const _rutaDeLaImagen = 'assets/branding/imagen_intro.jpg';
const _duracionMinima = Duration(seconds: 3);

/// Pantalla de intro: muestra la imagen de carga mientras `viewModel` trae
/// los datos iniciales de la app en paralelo. Pasa al mapa recién cuando se
/// cumplió el tiempo mínimo de exhibición Y los datos ya están listos, en
/// cualquier orden — nunca antes de cualquiera de las dos cosas.
class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  late final SplashReadiness _listo;
  late final Timer _temporizador;
  bool _yaNavego = false;

  @override
  void initState() {
    super.initState();
    _listo = SplashReadiness(onListo: _irAlMapa);
    _temporizador = Timer(_duracionMinima, _listo.marcarTiempoMinimoCumplido);

    widget.viewModel.addListener(_alCambiarElViewModel);
    widget.viewModel.iniciar();
  }

  void _alCambiarElViewModel() {
    if (widget.viewModel.cuerpo is Cargando) return;
    widget.viewModel.removeListener(_alCambiarElViewModel);
    _listo.marcarDatosListos();
  }

  void _irAlMapa() {
    if (_yaNavego || !mounted) return;
    _yaNavego = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MapView(viewModel: widget.viewModel, iniciarAlMontar: false),
      ),
    );
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiarElViewModel);
    _temporizador.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FractionallySizedBox(
          widthFactor: 0.75,
          child: Image.asset(_rutaDeLaImagen),
        ),
      ),
    );
  }
}
