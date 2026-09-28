# Tour interactivo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar un tour interactivo bajo demanda a `reciclai_mobile`, disparado por un botón junto
al logo de la AppBar, que resalta en su lugar real el botón de "mi ubicación", el selector de
comuna y el filtro de materiales, y explica con tarjetas simples el mapa y el detalle de un punto.

**Architecture:** Un overlay a pantalla completa (`TourOverlay`, insertado vía `Overlay.of(context)`,
no una ruta nueva) recorre una lista fija de 5 `TourStep`. Cada paso apunta opcionalmente a un
`GlobalKey` ya existente en `MapView` — si el widget de ese `GlobalKey` no está montado (ej. el
botón de ubicación sin permiso GPS), el paso se salta solo. Todo vive en la capa de presentación;
no se toca `MapViewModel` ni el backend.

**Tech Stack:** Flutter/Dart, widgets estándar (`CustomPainter`, `Overlay`, `AnimationController`) —
sin dependencias nuevas en `pubspec.yaml`.

**Spec:** `docs/superpowers/specs/2026-09-28-tour-interactivo-diseno.md`

## Global Constraints

- Cero dependencias nuevas en `pubspec.yaml` — todo se construye con widgets estándar de Flutter.
- El tour es solo bajo demanda (botón), nunca automático — sin persistencia de estado "ya visto".
- No se modifica `MapViewModel`, ningún archivo de `data/` o `domain/`, ni nada del backend.
- Reutilizar tokens visuales existentes: `radioDeHojaFlotante` y `colorScheme.surfaceContainerHigh`
  (de `lib/ui/core/floating_sheet_card.dart`), `espacioXs/Sm/Md/Lg` (de `lib/ui/core/spacing.dart`),
  y `colorScheme.secondary`/`secondaryContainer` (el acento terracota ya reservado para "la acción
  principal" en `lib/ui/core/theme.dart`) — no introducir colores o radios nuevos sueltos.
- Los tests existentes de `test/ui/features/map/views/map_view_test.dart` que usan
  `find.byKey(const Key('boton-mi-ubicacion'))` deben seguir pasando sin modificarse.

## Review Focus

- El botón de "mi ubicación" no está montado al abrir el tour (sin permiso GPS) — el paso debe
  saltarse solo, sin mostrar un hueco vacío ni trabar la navegación. (Task 1, pasos de test 6-7;
  Task 3, test de integración.)
- Saltar el tour en cualquier paso debe remover el `OverlayEntry` limpiamente — un segundo toque al
  botón del tour después de cerrarlo no debe fallar por reusar una entry ya removida. (Task 3.)
- Tocar el área oscurecida fuera de la tarjeta no debe dejar pasar el toque al mapa/widgets de
  abajo (paneo accidental del mapa mientras el tour está abierto). (Task 1, test 8.)
- Si TODOS los pasos de una lista tuvieran su ancla sin montar (caso límite, no ocurre con los 5
  pasos reales de hoy pero el componente debe ser robusto), el overlay debe cerrarse solo en vez de
  quedar en un estado vacío o lanzar una excepción. (Task 1, test 7.)
- El botón "Atrás" debe re-evaluar el montaje del ancla al retroceder, no solo al avanzar — si en
  algún momento futuro se agregan pasos donde retroceder también pueda caer en un ancla no
  montada, no debe quedar atascado. (Task 1, cubierto por la implementación genérica de `_atras`,
  con test explícito de retroceso simple.)

---

## Archivos nuevos y su responsabilidad

```
lib/ui/features/tour/
  tour_step.dart              -- modelo de datos (título, cuerpo, ancla opcional)
  views/
    tour_overlay.dart         -- el overlay: oscurecido + recorte + tarjeta + navegación
    tour_trigger_button.dart  -- la pastilla animada de la AppBar
```

Modificados: `lib/ui/features/map/views/map_view.dart` (agrega las 3 `GlobalKey`, el botón en la
AppBar, y arma/inserta el `TourOverlay`).

---

### Task 1: `TourStep` + `TourOverlay`

**Files:**
- Create: `lib/ui/features/tour/tour_step.dart`
- Create: `lib/ui/features/tour/views/tour_overlay.dart`
- Test: `test/ui/features/tour/views/tour_overlay_test.dart`

**Interfaces:**
- Produces: `TourStep({required String titulo, required String cuerpo, GlobalKey? anchorKey})`.
- Produces: `TourOverlay({required List<TourStep> pasos, required VoidCallback onCerrar})`, un
  `StatefulWidget`. Claves usadas internamente y visibles a los tests:
  `Key('tour-siguiente')`, `Key('tour-atras')`, `Key('tour-saltar')`.

- [ ] **Step 1: Escribir los tests que fallan**

```dart
// test/ui/features/tour/views/tour_overlay_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/tour/tour_step.dart';
import 'package:reciclai_mobile/ui/features/tour/views/tour_overlay.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('un paso sin anchorKey muestra una tarjeta centrada con su texto', (tester) async {
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [TourStep(titulo: 'El mapa', cuerpo: 'Los pines son puntos de reciclaje.')],
          onCerrar: () {},
        ),
      ),
    );

    expect(find.text('El mapa'), findsOneWidget);
    expect(find.text('Los pines son puntos de reciclaje.'), findsOneWidget);
  });

  testWidgets('Siguiente avanza al segundo paso', (tester) async {
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [
            TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso dos', cuerpo: 'Dos'),
          ],
          onCerrar: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(find.text('Paso dos'), findsOneWidget);
    expect(find.text('Paso uno'), findsNothing);
  });

  testWidgets('el ultimo paso dice Listo y cierra el tour al tocarlo', (tester) async {
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [TourStep(titulo: 'Unico paso', cuerpo: 'Contenido')],
          onCerrar: () => cerrado = true,
        ),
      ),
    );

    expect(find.text('Listo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(cerrado, isTrue);
  });

  testWidgets('Atras no aparece en el primer paso, aparece despues y retrocede', (tester) async {
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [
            TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso dos', cuerpo: 'Dos'),
          ],
          onCerrar: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('tour-atras')), findsNothing);

    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();
    expect(find.byKey(const Key('tour-atras')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-atras')));
    await tester.pump();
    expect(find.text('Paso uno'), findsOneWidget);
  });

  testWidgets('Saltar cierra el tour inmediatamente desde cualquier paso', (tester) async {
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [
            TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso dos', cuerpo: 'Dos'),
          ],
          onCerrar: () => cerrado = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tour-saltar')));
    await tester.pump();

    expect(cerrado, isTrue);
  });

  testWidgets('un paso con anchorKey no montado se salta solo', (tester) async {
    final keyNoMontado = GlobalKey();
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: [
            const TourStep(titulo: 'Paso uno', cuerpo: 'Uno'),
            TourStep(titulo: 'Paso saltado', cuerpo: 'No deberia verse', anchorKey: keyNoMontado),
            const TourStep(titulo: 'Paso tres', cuerpo: 'Tres'),
          ],
          onCerrar: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(find.text('Paso tres'), findsOneWidget);
    expect(find.text('Paso saltado'), findsNothing);
  });

  testWidgets('si todos los pasos tienen anclas sin montar, se cierra solo', (tester) async {
    var cerrado = false;
    final keyNoMontado = GlobalKey();
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: [TourStep(titulo: 'Nunca visible', cuerpo: '-', anchorKey: keyNoMontado)],
          onCerrar: () => cerrado = true,
        ),
      ),
    );
    await tester.pump();

    expect(cerrado, isTrue);
    expect(find.text('Nunca visible'), findsNothing);
  });

  testWidgets('tocar el area oscurecida no cierra ni cambia de paso', (tester) async {
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(
        TourOverlay(
          pasos: const [TourStep(titulo: 'Paso uno', cuerpo: 'Uno')],
          onCerrar: () => cerrado = true,
        ),
      ),
    );

    // Esquina superior izquierda: fuera de la tarjeta centrada.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(cerrado, isFalse);
    expect(find.text('Paso uno'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

Run: `flutter test test/ui/features/tour/views/tour_overlay_test.dart`
Expected: FAIL — `package:reciclai_mobile/ui/features/tour/tour_step.dart` y
`.../tour_overlay.dart` no existen todavía.

- [ ] **Step 3: Crear `tour_step.dart`**

```dart
// lib/ui/features/tour/tour_step.dart
import 'package:flutter/widgets.dart';

/// Un paso del tour interactivo: un título, un cuerpo de texto, y opcionalmente
/// el widget real a resaltar. `anchorKey` en `null` significa una tarjeta
/// centrada sin spotlight (para explicar un concepto sin un widget puntual que
/// señalar, ej. "toca cualquier pin del mapa").
class TourStep {
  const TourStep({required this.titulo, required this.cuerpo, this.anchorKey});

  final String titulo;
  final String cuerpo;
  final GlobalKey? anchorKey;
}
```

- [ ] **Step 4: Crear `tour_overlay.dart`**

```dart
// lib/ui/features/tour/views/tour_overlay.dart
import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../tour_step.dart';

class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.pasos, required this.onCerrar});

  final List<TourStep> pasos;
  final VoidCallback onCerrar;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  late int _indice;

  @override
  void initState() {
    super.initState();
    _indice = _primerIndiceMontado();
  }

  bool _montado(int indice) {
    final key = widget.pasos[indice].anchorKey;
    return key == null || key.currentContext != null;
  }

  int _primerIndiceMontado() {
    for (var i = 0; i < widget.pasos.length; i++) {
      if (_montado(i)) return i;
    }
    return widget.pasos.length;
  }

  void _siguiente() {
    var candidato = _indice + 1;
    while (candidato < widget.pasos.length && !_montado(candidato)) {
      candidato++;
    }
    if (candidato >= widget.pasos.length) {
      widget.onCerrar();
    } else {
      setState(() => _indice = candidato);
    }
  }

  void _atras() {
    var candidato = _indice - 1;
    while (candidato > 0 && !_montado(candidato)) {
      candidato--;
    }
    if (candidato < 0) return;
    setState(() => _indice = candidato);
  }

  @override
  Widget build(BuildContext context) {
    if (_indice >= widget.pasos.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCerrar());
      return const SizedBox.shrink();
    }

    final paso = widget.pasos[_indice];
    final esUltimo = _indice == widget.pasos.length - 1;
    final rect = _rectDelAncla(paso.anchorKey);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(painter: _RecortePainter(rect), child: const SizedBox.expand()),
          ),
        ),
        _tarjeta(context, paso, rect, esUltimo),
      ],
    );
  }

  Rect? _rectDelAncla(GlobalKey? key) {
    if (key == null) return null;
    final contexto = key.currentContext;
    if (contexto == null) return null;
    final renderBox = contexto.findRenderObject() as RenderBox;
    final posicion = renderBox.localToGlobal(Offset.zero);
    return posicion & renderBox.size;
  }

  Widget _tarjeta(BuildContext context, TourStep paso, Rect? rect, bool esUltimo) {
    final esquema = Theme.of(context).colorScheme;
    final tarjeta = Material(
      color: esquema.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radioDeHojaFlotante),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(espacioMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(paso.titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: espacioSm),
            Text(paso.cuerpo),
            const SizedBox(height: espacioMd),
            Row(
              children: [
                TextButton(
                  key: const Key('tour-saltar'),
                  onPressed: widget.onCerrar,
                  child: const Text('Saltar'),
                ),
                const Spacer(),
                if (_indice > 0) ...[
                  TextButton(
                    key: const Key('tour-atras'),
                    onPressed: _atras,
                    child: const Text('Atrás'),
                  ),
                  const SizedBox(width: espacioSm),
                ],
                FilledButton(
                  key: const Key('tour-siguiente'),
                  onPressed: _siguiente,
                  child: Text(esUltimo ? 'Listo' : 'Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (rect == null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(espacioLg), child: tarjeta),
      );
    }

    final pantalla = MediaQuery.of(context).size;
    final espacioAbajo = pantalla.height - rect.bottom;
    final vaArriba = espacioAbajo < rect.top;
    return Positioned(
      left: espacioMd,
      right: espacioMd,
      top: vaArriba ? null : rect.bottom + espacioMd,
      bottom: vaArriba ? (pantalla.height - rect.top) + espacioMd : null,
      child: tarjeta,
    );
  }
}

class _RecortePainter extends CustomPainter {
  const _RecortePainter(this.hueco);

  final Rect? hueco;

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final recorte = hueco == null
        ? fondo
        : Path.combine(
            PathOperation.difference,
            fondo,
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(hueco!.inflate(espacioXs), const Radius.circular(espacioSm)),
              ),
          );
    canvas.drawPath(recorte, Paint()..color = Colors.black54);
  }

  @override
  bool shouldRepaint(covariant _RecortePainter oldDelegate) => oldDelegate.hueco != hueco;
}
```

- [ ] **Step 5: Correr los tests y confirmar que pasan**

Run: `flutter test test/ui/features/tour/views/tour_overlay_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/tour/tour_step.dart lib/ui/features/tour/views/tour_overlay.dart test/ui/features/tour/views/tour_overlay_test.dart
git commit -m "feat(tour): agrega TourStep y TourOverlay con navegacion y auto-salto"
```

---

### Task 2: `TourTriggerButton`

**Files:**
- Create: `lib/ui/features/tour/views/tour_trigger_button.dart`
- Test: `test/ui/features/tour/views/tour_trigger_button_test.dart`

**Interfaces:**
- Consumes: nada de tareas anteriores (independiente de `TourStep`/`TourOverlay`).
- Produces: `TourTriggerButton({required VoidCallback onTap})`, key interna
  `Key('tour-trigger-button')`.

- [ ] **Step 1: Escribir los tests que fallan**

```dart
// test/ui/features/tour/views/tour_trigger_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/tour/views/tour_trigger_button.dart';

void main() {
  testWidgets('muestra el icono de tips y llama a onTap al tocarlo', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TourTriggerButton(onTap: () => tocado = true))),
    );

    expect(find.byIcon(Icons.tips_and_updates_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-trigger-button')));
    expect(tocado, isTrue);
  });

  testWidgets('el pulso de escala anima en loop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TourTriggerButton(onTap: () {}))),
    );

    await tester.pump();
    final escalaInicial = tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

    await tester.pump(const Duration(milliseconds: 750));
    final escalaAMitadDeCamino =
        tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

    expect(escalaAMitadDeCamino, greaterThan(escalaInicial));
  });
}
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

Run: `flutter test test/ui/features/tour/views/tour_trigger_button_test.dart`
Expected: FAIL — el archivo no existe todavía.

- [ ] **Step 3: Crear `tour_trigger_button.dart`**

```dart
// lib/ui/features/tour/views/tour_trigger_button.dart
import 'package:flutter/material.dart';

import '../../../core/spacing.dart';

class TourTriggerButton extends StatefulWidget {
  const TourTriggerButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<TourTriggerButton> createState() => _TourTriggerButtonState();
}

class _TourTriggerButtonState extends State<TourTriggerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _escala = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controlador, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _escala,
      child: Material(
        color: esquema.secondaryContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          key: const Key('tour-trigger-button'),
          onTap: widget.onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: espacioSm, vertical: espacioXs),
            child: Icon(Icons.tips_and_updates_outlined, color: esquema.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr los tests y confirmar que pasan**

Run: `flutter test test/ui/features/tour/views/tour_trigger_button_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/tour/views/tour_trigger_button.dart test/ui/features/tour/views/tour_trigger_button_test.dart
git commit -m "feat(tour): agrega TourTriggerButton con pulso animado"
```

---

### Task 3: Conectar el tour a `MapView`

**Files:**
- Modify: `lib/ui/features/map/views/map_view.dart`
- Test: `test/ui/features/map/views/map_view_test.dart`

**Interfaces:**
- Consumes: `TourStep`, `TourOverlay` (Task 1), `TourTriggerButton` (Task 2).
- Produces: nada nuevo hacia afuera — este task es el punto de integración final.

- [ ] **Step 1: Leer el estado actual del archivo a modificar**

Confirmar que las líneas relevantes de `lib/ui/features/map/views/map_view.dart` siguen así antes
de tocar nada (si difieren, ajustar el resto de los steps a lo que realmente hay):

```dart
class _MapViewState extends State<MapView> {
  @override
  void initState() {
    super.initState();
    if (widget.iniciarAlMontar) widget.viewModel.iniciar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 64,
        title: Image.asset(
          'assets/branding/logo_horizontal.png',
          height: 44,
          fit: BoxFit.contain,
        ),
      ),
```

y, más abajo:

```dart
                      child: GlassBar(
                          children: [
                            ComunaSelector(
                              comunas: widget.viewModel.comunas,
                              comunaSeleccionadaId: widget.viewModel.comunaSeleccionadaId,
                              onElegirComuna: widget.viewModel.seleccionarComuna,
                              onLimpiarComuna: widget.viewModel.limpiarComuna,
                            ),
                            MaterialFilterButton(viewModel: widget.viewModel),
                          ],
                        ),
```

y, en `_MapaConPuntos`:

```dart
class _MapaConPuntos extends StatefulWidget {
  const _MapaConPuntos({
    required this.puntos,
    required this.centroComuna,
    required this.miUbicacion,
    required this.onTocarPunto,
    required this.mostrarMiUbicacion,
    required this.posicionEnVivo,
  });
```

y el bloque del FAB:

```dart
        if (widget.mostrarMiUbicacion && _miUbicacionEnVivo != null)
          Positioned(
            top: espacioMd,
            right: espacioMd,
            child: FloatingActionButton.small(
              key: const Key('boton-mi-ubicacion'),
              heroTag: 'boton-mi-ubicacion',
              onPressed: _centrarEnMiUbicacion,
              child: const Icon(Icons.my_location),
            ),
          ),
```

- [ ] **Step 2: Escribir los tests de integración que fallan**

Agregar al final de `test/ui/features/map/views/map_view_test.dart` (antes del cierre del
archivo), reusando `_laFlorida`, `_punto()`, `ApiClientFalso`, `LocationServiceFalsa` y
`_elegirComunaEnElSelector` ya definidos en ese mismo archivo:

```dart
  testWidgets('el boton del tour aparece en la AppBar', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tour-trigger-button')), findsOneWidget);
  });

  testWidgets('tocar el boton del tour abre el primer paso', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tour-trigger-button')));
    await tester.pump();

    expect(find.text('El mapa'), findsOneWidget);
  });

  testWidgets(
    'sin permiso de ubicacion, Siguiente salta el paso del boton de ubicacion',
    (tester) async {
      final viewModel = MapViewModel(
        apiClient: ApiClientFalso(comunas: [_laFlorida], puntosPorComuna: [_punto()]),
        locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
      );

      await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
      await tester.pumpAndSettle();
      await _elegirComunaEnElSelector(tester, 'La Florida');

      await tester.tap(find.byKey(const Key('tour-trigger-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tour-siguiente')));
      await tester.pump();

      expect(find.text('Elige tu comuna'), findsOneWidget);
    },
  );

  testWidgets('Saltar cierra el tour y el boton se puede volver a tocar despues', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tour-trigger-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tour-saltar')));
    await tester.pump();

    expect(find.text('El mapa'), findsNothing);

    await tester.tap(find.byKey(const Key('tour-trigger-button')));
    await tester.pump();

    expect(find.text('El mapa'), findsOneWidget);
  });
```

Añadir el import que falte al principio del archivo:

```dart
import 'package:reciclai_mobile/ui/features/map/views/material_filter_button.dart';
```

(usar solo si `MaterialFilterButton` no está ya importado en ese archivo de test; no lo estaba
antes de este task porque ningún test anterior lo referenciaba directamente por tipo).

- [ ] **Step 3: Correr los tests y confirmar que fallan**

Run: `flutter test test/ui/features/map/views/map_view_test.dart`
Expected: FAIL en los 4 tests nuevos — el botón todavía no existe en la AppBar.

- [ ] **Step 4: Modificar `map_view.dart`**

Agregar los imports nuevos junto a los existentes:

```dart
import '../../tour/tour_step.dart';
import '../../tour/views/tour_overlay.dart';
import '../../tour/views/tour_trigger_button.dart';
```

Agregar las 3 `GlobalKey` y los métodos del tour dentro de `_MapViewState`, antes de `build`:

```dart
class _MapViewState extends State<MapView> {
  final _keyMiUbicacion = GlobalKey();
  final _keyComunaSelector = GlobalKey();
  final _keyFiltroMateriales = GlobalKey();
  OverlayEntry? _entradaDelTour;

  @override
  void initState() {
    super.initState();
    if (widget.iniciarAlMontar) widget.viewModel.iniciar();
  }

  @override
  void dispose() {
    _entradaDelTour?.remove();
    super.dispose();
  }

  void _iniciarTour() {
    final entrada = OverlayEntry(
      builder: (context) => TourOverlay(
        pasos: [
          const TourStep(
            titulo: 'El mapa',
            cuerpo: 'Los pines verdes son puntos de reciclaje cerca de ti.',
          ),
          TourStep(
            titulo: 'Tu ubicación',
            cuerpo: 'Toca aquí para centrar el mapa en tu ubicación.',
            anchorKey: _keyMiUbicacion,
          ),
          TourStep(
            titulo: 'Elige tu comuna',
            cuerpo: 'O elige tu comuna aquí si prefieres buscar así.',
            anchorKey: _keyComunaSelector,
          ),
          TourStep(
            titulo: 'Filtra por material',
            cuerpo: 'Filtra por el tipo de material que quieres reciclar.',
            anchorKey: _keyFiltroMateriales,
          ),
          const TourStep(
            titulo: 'Detalle de un punto',
            cuerpo: 'Toca cualquier pin para ver su dirección, materiales y trazar una ruta.',
          ),
        ],
        onCerrar: _cerrarTour,
      ),
    );
    _entradaDelTour = entrada;
    Overlay.of(context).insert(entrada);
  }

  void _cerrarTour() {
    _entradaDelTour?.remove();
    _entradaDelTour = null;
  }
```

Modificar el `AppBar` para agregar el botón:

```dart
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 64,
        title: Image.asset(
          'assets/branding/logo_horizontal.png',
          height: 44,
          fit: BoxFit.contain,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: espacioMd),
            child: TourTriggerButton(onTap: _iniciarTour),
          ),
        ],
      ),
```

Pasar las `GlobalKey` a `ComunaSelector` y `MaterialFilterButton`:

```dart
                      child: GlassBar(
                          children: [
                            ComunaSelector(
                              key: _keyComunaSelector,
                              comunas: widget.viewModel.comunas,
                              comunaSeleccionadaId: widget.viewModel.comunaSeleccionadaId,
                              onElegirComuna: widget.viewModel.seleccionarComuna,
                              onLimpiarComuna: widget.viewModel.limpiarComuna,
                            ),
                            MaterialFilterButton(
                              key: _keyFiltroMateriales,
                              viewModel: widget.viewModel,
                            ),
                          ],
                        ),
```

Pasar `_keyMiUbicacion` a **ambas** construcciones de `_MapaConPuntos` que ya existen dentro del
`switch (widget.viewModel.cuerpo)`:

```dart
                    ConDatos(:final puntos) => _MapaConPuntos(
                        puntos: filtrarPorMateriales(puntos, widget.viewModel.materialesSeleccionados),
                        centroComuna: widget.viewModel.centroComunaSeleccionada,
                        miUbicacion: widget.viewModel.miUbicacion,
                        onTocarPunto: _mostrarDetalle,
                        mostrarMiUbicacion: widget.viewModel.tienePermisoDeUbicacion,
                        posicionEnVivo: widget.viewModel.posicionEnVivo,
                        miUbicacionKey: _keyMiUbicacion,
                      ),
```

```dart
                    FueraDeRango() => _MapaConPuntos(
                        puntos: const [],
                        centroComuna: null,
                        miUbicacion: widget.viewModel.miUbicacion,
                        onTocarPunto: _mostrarDetalle,
                        mostrarMiUbicacion: widget.viewModel.tienePermisoDeUbicacion,
                        posicionEnVivo: widget.viewModel.posicionEnVivo,
                        miUbicacionKey: _keyMiUbicacion,
                      ),
```

(Las demás ramas del `switch` — `Cargando()`, `SinSeleccion(...)`, `ErrorAlCargar(...)` — no
construyen `_MapaConPuntos` y quedan intactas.)

Modificar `_MapaConPuntos` para recibir la key:

```dart
class _MapaConPuntos extends StatefulWidget {
  const _MapaConPuntos({
    required this.puntos,
    required this.centroComuna,
    required this.miUbicacion,
    required this.onTocarPunto,
    required this.mostrarMiUbicacion,
    required this.posicionEnVivo,
    required this.miUbicacionKey,
  });

  final List<RecyclingPoint> puntos;
  final LatLng? centroComuna;
  final LatLng? miUbicacion;
  final void Function(RecyclingPoint punto, LatLng? miUbicacion) onTocarPunto;
  final bool mostrarMiUbicacion;
  final Stream<Position> posicionEnVivo;
  final GlobalKey miUbicacionKey;
```

Modificar el FAB dentro de `_MapaConPuntosState.build` para envolverlo con `KeyedSubtree`:

```dart
        if (widget.mostrarMiUbicacion && _miUbicacionEnVivo != null)
          Positioned(
            top: espacioMd,
            right: espacioMd,
            child: KeyedSubtree(
              key: widget.miUbicacionKey,
              child: FloatingActionButton.small(
                key: const Key('boton-mi-ubicacion'),
                heroTag: 'boton-mi-ubicacion',
                onPressed: _centrarEnMiUbicacion,
                child: const Icon(Icons.my_location),
              ),
            ),
          ),
```

- [ ] **Step 5: Correr los tests y confirmar que pasan**

Run: `flutter test test/ui/features/map/views/map_view_test.dart`
Expected: PASS — incluyendo los 4 nuevos y todos los que ya existían (los que usan
`find.byKey(const Key('boton-mi-ubicacion'))` siguen encontrando el `FloatingActionButton`, ahora
envuelto en un `KeyedSubtree` que no cambia su identidad de key propia).

- [ ] **Step 6: Correr la suite completa del proyecto**

Run: `flutter test`
Expected: PASS en todos los archivos (confirma que nada de `comuna_selector_test.dart`,
`material_filter_button_test.dart`, ni `my_location_layer_test.dart` se vio afectado).

- [ ] **Step 7: Commit**

```bash
git add lib/ui/features/map/views/map_view.dart test/ui/features/map/views/map_view_test.dart
git commit -m "feat(tour): conecta el boton del tour con los widgets reales de MapView"
```
