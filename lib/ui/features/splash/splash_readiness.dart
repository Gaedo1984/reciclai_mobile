import 'package:flutter/foundation.dart';

/// Decide cuándo la pantalla de intro terminó de cumplir su función: recién
/// cuando se cumplió el tiempo mínimo de exhibición Y los datos iniciales de
/// la app ya están listos, sin importar en qué orden lleguen esas dos
/// señales — así la intro nunca desaparece en un parpadeo si los datos
/// cargan muy rápido.
class SplashReadiness {
  SplashReadiness({required this.onListo});

  final VoidCallback onListo;

  bool _tiempoMinimoCumplido = false;
  bool _datosListos = false;
  bool _yaAviso = false;

  void marcarTiempoMinimoCumplido() {
    _tiempoMinimoCumplido = true;
    _avisarSiListo();
  }

  void marcarDatosListos() {
    _datosListos = true;
    _avisarSiListo();
  }

  void _avisarSiListo() {
    if (_yaAviso || !_tiempoMinimoCumplido || !_datosListos) return;
    _yaAviso = true;
    onListo();
  }
}
