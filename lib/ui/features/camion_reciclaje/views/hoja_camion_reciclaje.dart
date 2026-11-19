import 'package:flutter/material.dart';

import '../../../../data/models/servicio_retiro.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../../notificaciones/formato_fecha.dart';
import '../view_models/camion_reciclaje_view_model.dart';

/// Alto maximo de la hoja como fraccion de la pantalla -- el mapa usa el
/// mismo valor para dejar visible la zona del dia por encima de la hoja.
const fraccionAlturaHojaCamion = 0.62;

// Secuencia de las calles: la primera aparece a los 450 ms y cada siguiente
// 420 ms despues; cada una tarda 350 ms en entrar. El marcador final de
// "recorrido completo" va en el turno siguiente a la ultima calle.
const _inicioMs = 450;
const _pasoMs = 420;
const _entradaMs = 350;
const _desplazamientoEntrada = 8.0;

const _etiquetasDeDia = {
  'lunes': 'Lun',
  'martes': 'Mar',
  'miércoles': 'Mié',
  'jueves': 'Jue',
  'viernes': 'Vie',
  'sábado': 'Sáb',
  'domingo': 'Dom',
};

const _anchoPunto = 24.0;

Future<void> mostrarHojaCamionReciclaje(
  BuildContext context,
  CamionReciclajeViewModel viewModel,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Sin oscurecer: el mapa de fondo muestra la zona y las calles numeradas.
    barrierColor: Colors.transparent,
    builder: (_) => HojaCamionReciclaje(viewModel: viewModel),
  );
}

class HojaCamionReciclaje extends StatefulWidget {
  const HojaCamionReciclaje({super.key, required this.viewModel});

  final CamionReciclajeViewModel viewModel;

  @override
  State<HojaCamionReciclaje> createState() => _HojaCamionReciclajeState();
}

class _HojaCamionReciclajeState extends State<HojaCamionReciclaje>
    with SingleTickerProviderStateMixin {
  /// Una sola secuencia para todas las calles del dia (cada una con su
  /// `Interval`); se reinicia desde cero al cambiar de dia.
  late final AnimationController _secuencia = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _inicioMs + _entradaMs),
  );

  /// Dia cuya secuencia ya se lanzo; null mientras no hay servicio listo.
  String? _diaAnimado;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_alCambiarViewModel);
    _alCambiarViewModel();
  }

  @override
  void didUpdateWidget(HojaCamionReciclaje anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.viewModel != widget.viewModel) {
      anterior.viewModel.removeListener(_alCambiarViewModel);
      widget.viewModel.addListener(_alCambiarViewModel);
      _diaAnimado = null;
      _alCambiarViewModel();
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiarViewModel);
    _secuencia.dispose();
    super.dispose();
  }

  void _alCambiarViewModel() {
    final viewModel = widget.viewModel;
    if (viewModel.estado is! CamionListo) {
      _diaAnimado = null;
      return;
    }
    final dia = viewModel.diaSeleccionado;
    if (dia == null) {
      // Servicio sin dias: no hay calles que animar.
      _secuencia.value = 1;
      return;
    }
    if (dia == _diaAnimado) return;
    _diaAnimado = dia;
    final calles = viewModel.zonaDelDia?.calles.length ?? 0;
    _secuencia.duration = Duration(
      milliseconds: _inicioMs + calles * _pasoMs + _entradaMs,
    );
    _secuencia.forward(from: 0);
  }

  /// Animacion de entrada (0 a 1) del elemento `indice` de la secuencia.
  Animation<double> _entrada(BuildContext context, int indice) {
    if (MediaQuery.disableAnimationsOf(context)) return kAlwaysCompleteAnimation;
    final total = _secuencia.duration!.inMilliseconds;
    final inicio = _inicioMs + indice * _pasoMs;
    return _secuencia.drive(
      CurveTween(
        curve: Interval(
          inicio / total,
          (inicio + _entradaMs) / total,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('hoja-camion'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * fraccionAlturaHojaCamion,
      ),
      child: FloatingSheetCard(
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) => switch (widget.viewModel.estado) {
              CamionCargando() => _conEncabezado(
                context,
                null,
                const Padding(
                  padding: EdgeInsets.all(espacioLg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              CamionSinServicio() => _conEncabezado(
                context,
                null,
                const Text(
                  'Aún no tenemos el recorrido del camión de reciclaje para esta comuna.',
                ),
              ),
              CamionError() => _conEncabezado(
                context,
                null,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No pudimos cargar el recorrido.'),
                    const SizedBox(height: espacioSm),
                    FilledButton.tonal(
                      onPressed: widget.viewModel.reintentar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              CamionListo(:final servicio) => _contenidoListo(context, servicio),
            },
          ),
        ),
      ),
    );
  }

  Widget _conEncabezado(BuildContext context, String? subtitulo, Widget cuerpo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Encabezado(subtitulo: subtitulo),
        const SizedBox(height: espacioMd),
        cuerpo,
      ],
    );
  }

  Widget _contenidoListo(BuildContext context, ServicioRetiro servicio) {
    final viewModel = widget.viewModel;
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    final zona = viewModel.zonaDelDia;
    final dia = viewModel.diaSeleccionado;
    final calles = zona?.calles ?? const [];
    final estiloSeccion = textos.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    return _conEncabezado(
      context,
      zona == null
          ? servicio.comunaNombre
          : '${servicio.comunaNombre} · ${zona.nombre}',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dia != null)
            _TarjetaDelDia(
              etiqueta: viewModel.diaEsDelUsuario
                  ? 'El camión pasa por tu casa los'
                  : 'En este sector pasa los',
              dia: dia[0].toUpperCase() + dia.substring(1),
              horario: viewModel.horarioDelDia ?? servicio.horario,
            ),
          const SizedBox(height: espacioSm),
          // Una sola fila que reparte el ancho: con un Wrap, los seis dias de La
          // Florida dejaban "Sáb" solo en una segunda fila.
          Row(
            // Arriba: las etiquetas "Tu día" / "Hoy" van bajo su chip y no
            // deben bajar los chips sin etiqueta.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, diaDelServicio) in viewModel.diasDelServicio.indexed) ...[
                if (i > 0) const SizedBox(width: espacioXs + 2),
                Expanded(
                  child: _ChipDia(
                    key: Key('chip-dia-$diaDelServicio'),
                    etiqueta: _etiquetasDeDia[diaDelServicio] ?? diaDelServicio,
                    seleccionado: diaDelServicio == dia,
                    dia: diaDelServicio,
                    esDelUsuario: diaDelServicio == viewModel.diaDelUsuario,
                    esHoy: diaDelServicio == viewModel.diaDeHoy,
                    onTap: () => viewModel.seleccionarDia(diaDelServicio),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: espacioMd),
          Text('Recorre el sector entre', style: estiloSeccion),
          const SizedBox(height: espacioSm),
          // La linea que une los puntos va por tramos: el tramo `i` une el
          // punto `i - 1` con el `i` y se dibuja en dos partes, la cola bajo el
          // punto anterior y la cabeza sobre el suyo. Las dos aparecen con la
          // animacion del punto `i`, asi la linea crece junto con los puntos
          // aunque el texto de una calle ocupe varias lineas.
          for (final (i, calle) in calles.indexed)
            _Entrada(
              clave: Key('calle-$i'),
              animacion: _entrada(context, i),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _anchoPunto,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Las partes se cortan en el centro del punto, que
                          // se dibuja encima.
                          Padding(
                            padding: const EdgeInsets.only(bottom: espacioSm),
                            child: Column(
                              children: [
                                Expanded(
                                  child: i == 0
                                      ? const SizedBox.shrink()
                                      : _Tramo(clave: Key('tramo-$i-cabeza')),
                                ),
                                // Cola del tramo siguiente: sigue por el
                                // espacio entre calles hasta el borde inferior.
                                Expanded(
                                  child: FadeTransition(
                                    opacity: _entrada(context, i + 1),
                                    child: _Tramo(
                                      clave: Key('tramo-${i + 1}-cola'),
                                      extraAbajo: espacioSm,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: espacioSm),
                            child: Center(
                              child: _PuntoCalle(
                                key: Key('punto-$i'),
                                numero: i + 1,
                                animacion: _entrada(context, i),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: espacioSm + espacioXs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: espacioSm),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              calle.nombre,
                              style: textos.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              calle.referencia,
                              style: textos.bodySmall?.copyWith(
                                color: colores.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _Entrada(
            clave: const Key('camion-recorrido-completo'),
            animacion: _entrada(context, calles.length),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _anchoPunto,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: calles.isEmpty
                                  ? const SizedBox.shrink()
                                  : _Tramo(clave: Key('tramo-${calles.length}-cabeza')),
                            ),
                            const Spacer(),
                          ],
                        ),
                        Center(
                          child: Icon(
                            Icons.check_circle,
                            key: Key('punto-${calles.length}'),
                            color: colorVerdeLogo,
                            size: _anchoPunto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: espacioSm + espacioXs),
                  // Expanded para que el texto pueda partirse en pantallas
                  // angostas en vez de desbordar la fila.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        calles.length == 1
                            ? '1 calle · recorrido completo'
                            : '${calles.length} calles · recorrido completo',
                        style: textos.bodyMedium?.copyWith(
                          color: colorVerdeLogo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: espacioMd),
          Text('Qué puedes sacar', style: estiloSeccion),
          const SizedBox(height: espacioSm),
          Wrap(
            spacing: espacioSm,
            runSpacing: espacioXs,
            children: [
              for (final material in servicio.materiales)
                Chip(label: Text(material)),
            ],
          ),
          const SizedBox(height: espacioMd),
          Text(
            'Fuente: ${servicio.fuenteNombre} · actualizado '
            '${formatearMesAnio(servicio.actualizado)}',
            style: textos.bodySmall?.copyWith(color: colores.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.subtitulo});

  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final subtitulo = this.subtitulo;
    final textos = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: colorVerdeLogo, shape: BoxShape.circle),
          child: const Icon(Icons.local_shipping, color: Colors.white, size: 22),
        ),
        const SizedBox(width: espacioSm + espacioXs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Camión de reciclaje', style: textos.titleLarge),
              if (subtitulo != null)
                Text(
                  subtitulo,
                  style: textos.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          key: const Key('aviso-camion'),
          tooltip: 'Sobre esta información',
          icon: const Icon(Icons.error_outline),
          onPressed: () => _mostrarAvisoRutasReferenciales(context),
        ),
        BotonCerrarHoja(onTap: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}

/// Aviso legal del camion de reciclaje (pedido del usuario, 2026-11-17): las
/// zonas, dias y horarios se dibujan a partir de informacion publicada por
/// municipalidades y empresas privadas, asi que son referenciales.
const textoAvisoRutasReferenciales =
    'Las rutas, días y horarios del camión de reciclaje son referenciales. '
    'Se obtuvieron de información publicada en sitios municipales y de '
    'empresas privadas, por lo que pueden cambiar o tener diferencias con el '
    'servicio real. ReciclAI no es responsable de esta información. Ante '
    'cualquier duda, confirma con tu municipalidad.';

Future<void> _mostrarAvisoRutasReferenciales(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (contexto) => AlertDialog(
      icon: const Icon(Icons.error_outline),
      title: const Text('Información referencial'),
      content: const Text(textoAvisoRutasReferenciales),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

class _TarjetaDelDia extends StatelessWidget {
  const _TarjetaDelDia({
    required this.etiqueta,
    required this.dia,
    required this.horario,
  });

  final String etiqueta;
  final String dia;
  final String horario;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(espacioMd),
      decoration: BoxDecoration(
        color: colores.primaryContainer,
        borderRadius: BorderRadius.circular(espacioMd),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available, color: colores.onPrimaryContainer, size: 32),
          const SizedBox(width: espacioMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: textos.bodyMedium?.copyWith(color: colores.onPrimaryContainer),
                ),
                Text(
                  dia,
                  style: textos.headlineSmall?.copyWith(
                    color: colores.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  horario,
                  style: textos.bodySmall?.copyWith(color: colores.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({
    super.key,
    required this.etiqueta,
    required this.dia,
    required this.seleccionado,
    required this.esDelUsuario,
    required this.esHoy,
    required this.onTap,
  });

  final String etiqueta;

  /// Nombre completo del dia ("martes"), para las claves de las etiquetas.
  final String dia;
  final bool seleccionado;

  /// Dia de la zona donde esta el usuario: lleva "Tu día" debajo.
  final bool esDelUsuario;

  /// Dia de hoy: lleva "Hoy" debajo.
  final bool esHoy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    // Chip propio en vez de ChoiceChip: el ChoiceChip tiene un ancho minimo
    // que no deja repartir seis dias en una fila de telefono.
    final forma = StadiumBorder(
      side: BorderSide(color: seleccionado ? colores.primary : colores.outlineVariant),
    );
    final estiloEtiqueta = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colores.primary,
      fontWeight: FontWeight.w600,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          selected: seleccionado,
          child: Material(
            color: seleccionado ? colores.primary : Colors.transparent,
            shape: forma,
            child: InkWell(
              customBorder: forma,
              onTap: onTap,
              child: SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: seleccionado ? colores.onPrimary : colores.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (esDelUsuario)
          Text(
            'Tu día',
            key: Key('etiqueta-tu-dia-$dia'),
            maxLines: 1,
            style: estiloEtiqueta,
          ),
        if (esHoy)
          Text(
            'Hoy',
            key: Key('etiqueta-hoy-$dia'),
            maxLines: 1,
            style: estiloEtiqueta,
          ),
      ],
    );
  }
}

/// Fade + desplazamiento de -8 px a 0 con la misma animacion. La `clave` va
/// en el `FadeTransition` para que los tests lean su opacidad directamente.
class _Entrada extends StatelessWidget {
  const _Entrada({required this.clave, required this.animacion, required this.child});

  final Key clave;
  final Animation<double> animacion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: clave,
      opacity: animacion,
      child: AnimatedBuilder(
        animation: animacion,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -_desplazamientoEntrada * (1 - animacion.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// Parte de la linea entre puntos: 2 px de ancho, centrada bajo los puntos y
/// del alto que le dan, mas `extraAbajo` px que se dibujan hacia abajo.
class _Tramo extends StatelessWidget {
  const _Tramo({required this.clave, this.extraAbajo = 0});

  final Key clave;
  final double extraAbajo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -extraAbajo,
          child: Center(
            child: Container(
              key: clave,
              width: 2,
              color: colorVerdeLogo.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }
}

/// Circulo verde con el numero de la calle, el mismo que lleva en el mapa.
/// Entra creciendo de 0.4 a su tamano junto con su calle.
class _PuntoCalle extends StatelessWidget {
  const _PuntoCalle({super.key, required this.numero, required this.animacion});

  final int numero;
  final Animation<double> animacion;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: animacion.drive(Tween(begin: 0.4, end: 1)),
      child: Container(
        width: _anchoPunto,
        height: _anchoPunto,
        decoration: const BoxDecoration(color: colorVerdeLogo, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          '$numero',
          // Tamano fijo: el numero tiene que caber en el circulo aunque el
          // usuario agrande el texto del sistema.
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
