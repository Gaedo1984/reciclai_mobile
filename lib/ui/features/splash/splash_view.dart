import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../map/view_models/map_state.dart';
import '../map/view_models/map_view_model.dart';
import '../map/views/map_view.dart';
import 'splash_readiness.dart';

const _rutaDelVideo = 'assets/branding/video_carga.mp4';
const _margenDeFinDeVideo = Duration(milliseconds: 200);

/// Pantalla de intro: reproduce el video de carga mientras `viewModel` trae
/// los datos iniciales de la app en paralelo. Pasa al mapa recién cuando el
/// video completó al menos una vuelta Y los datos ya están listos, en
/// cualquier orden — nunca antes de cualquiera de las dos cosas.
class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  late final VideoPlayerController _video;
  late final SplashReadiness _listo;
  bool _videoYaCompletoUnaVuelta = false;
  bool _yaNavego = false;

  @override
  void initState() {
    super.initState();
    _listo = SplashReadiness(onListo: _irAlMapa);

    // No se puede usar el operador cascada (`..`) acá: si alguna de estas
    // llamadas dispara una notificación sincrónica (setLooping lo hace),
    // el listener intentaría leer `_video` antes de que termine de
    // asignarse, con un LateInitializationError.
    _video = VideoPlayerController.asset(_rutaDelVideo);
    _video.addListener(_alAvanzarElVideo);
    _video.setLooping(true);
    _video.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _video.play();
    });

    widget.viewModel.addListener(_alCambiarElViewModel);
    widget.viewModel.iniciar();
  }

  void _alAvanzarElVideo() {
    if (_videoYaCompletoUnaVuelta) return;
    final valor = _video.value;
    if (!valor.isInitialized || valor.duration == Duration.zero) return;
    if (valor.position >= valor.duration - _margenDeFinDeVideo) {
      _videoYaCompletoUnaVuelta = true;
      _listo.marcarVideoTerminado();
    }
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
    _video.removeListener(_alAvanzarElVideo);
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FractionallySizedBox(
          widthFactor: 0.375,
          child: _video.value.isInitialized
              ? ClipRect(
                  child: AspectRatio(
                    aspectRatio: _video.value.aspectRatio,
                    // El archivo de video trae una franja de relleno del propio
                    // codificador en un borde, que se ve como una línea fina. La
                    // agrandamos un poco y recortamos el sobrante para que quede
                    // fuera del área visible, sin cambiar el tamaño mostrado.
                    child: Transform.scale(scale: 1.03, child: VideoPlayer(_video)),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
