import 'package:flutter/foundation.dart';

/// Decide cuándo la pantalla de intro terminó de cumplir su función: recién
/// cuando el video completó al menos una vuelta Y los datos iniciales de la
/// app ya están listos, sin importar en qué orden lleguen esas dos señales.
class SplashReadiness {
  SplashReadiness({required this.onListo});

  final VoidCallback onListo;

  bool _videoTerminado = false;
  bool _datosListos = false;
  bool _yaAviso = false;

  void marcarVideoTerminado() {
    _videoTerminado = true;
    _avisarSiListo();
  }

  void marcarDatosListos() {
    _datosListos = true;
    _avisarSiListo();
  }

  void _avisarSiListo() {
    if (_yaAviso || !_videoTerminado || !_datosListos) return;
    _yaAviso = true;
    onListo();
  }
}
