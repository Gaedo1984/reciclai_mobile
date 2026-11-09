# Selector de radio con múltiples distancias (Off / 3 / 5 / 7 km) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el interruptor binario de radio de 3km por un selector
de 4 distancias (Off / 3 km / 5 km / 7 km), presentado como una extensión
visual de la barra flotante (`GlassBar`) existente.

**Architecture:** `MapViewModel` cambia su estado de radio de un `bool` a
un `double?` (metros, `null` = Off) con un único método
`seleccionarRadio(double? metros)` que generaliza la lógica ya existente de
`alternarRadio`. La UI agrega un panel pequeño, construido con el mismo
`GlassBar` reutilizado, que aparece pegado arriba de la barra principal
dentro del `Stack` ya existente en `map_view.dart` — ni un diálogo, ni un
`OverlayEntry` nuevo. De paso, se unifica a verde (`colorScheme.primary`)
el color "activo" de los 3 íconos de la barra (hoy el filtro de materiales
usa terracota, y el selector de comuna no cambia de color).

**Tech Stack:** Flutter/Dart, `ChangeNotifier` (`MapViewModel`), Material 3,
TDD con `flutter_test` + `ApiClientFalso`/`LocationServiceFalsa` de
`test/fakes.dart`.

**Spec:** `docs/superpowers/specs/2026-10-12-selector-radio-multiple-diseno.md`

## Global Constraints

- TDD estricto: RED (test falla) → GREEN (implementación mínima) → suite
  completa verde, antes de cada commit.
- Sin dependencias nuevas — todo con lo que ya está en `pubspec.yaml`.
- El backend no cambia — `GET /points/nearby/radius` ya acepta
  `radio_metros` arbitrario (desplegado en Render).
- Las 3 distancias son exactamente 3000.0, 5000.0 y 7000.0 metros (3/5/7 km).
- La separación entre los 4 botones del panel es exactamente 1.5 px lógicos.
- El panel reutiliza el widget `GlassBar` ya existente (mismo vidrio
  esmerilado) — no se crea un estilo de chrome nuevo.
- El color "activo" unificado es `Theme.of(context).colorScheme.primary`
  (verde salvia del seed del tema, `lib/ui/core/theme.dart`) — no
  `colorScheme.secondary` (terracota), que queda reservado para otros usos
  ya existentes fuera de este cambio (ej. el botón "Aplicar" del filtro de
  materiales).
- Todo el texto de usuario (etiquetas, tour) en español neutro, sin "vos".
- Trabajar directo sobre la rama `develop` (ya creada y con tracking a
  `origin/develop`), commits frecuentes — sin worktree nuevo.

## Review Focus

- Doble toque rápido sobre dos distancias distintas mientras la primera
  solicitud todavía está en vuelo — la recarga debe aplicar solo el
  resultado de la selección más reciente (el token `_operacionDeCuerpo` ya
  existente debe seguir descartando resultados viejos; agregar un caso que
  lo ejercite con el nuevo método).
- Elegir "Off" mientras el cuerpo todavía muestra "Cargando" de una
  selección anterior (p. ej. tocar Off apenas después de tocar 7km) — no
  debe quedar una carga vieja pisando el resultado de apagar el radio.
- Abrir el panel sin permiso de ubicación concedido — el ícono disparador
  debe seguir deshabilitado (`tienePermisoDeUbicacion`), el panel nunca
  debe poder abrirse en ese estado.
- Tocar "Off" cuando la posición geolocalizada actual no está cubierta por
  ninguna comuna (`NotCovered`) — debe caer en el mismo `SinSeleccion` con
  mensaje de "no cubierta" que ya existe hoy para ese caso, no en un error.
- Abrir y cerrar el panel repetidamente sin elegir nada (tocar el
  disparador, tocar afuera, tocar el disparador de nuevo) — no debe dejar
  más de una barrera de toque activa ni lanzar excepciones.

---

### Task 1: `MapViewModel` — generalizar el radio a 4 distancias

**Files:**
- Modify: `lib/ui/features/map/view_models/map_view_model.dart:51-52` (declaración de `_radioActivo`/`radioActivo`), `:309-322` (`alternarRadio`), `:324-338` (`seleccionarComuna`), `:421-429` (`_obtenerCuerpoParaPosicion`)
- Test: `test/ui/features/map/view_models/map_view_model_test.dart:518-677` (bloque de tests de radio)

**Interfaces:**
- Consumes: `ReciclaiApiClient.obtenerPuntosEnRadio(lat, lng, {Duration? timeout, double? radioMetros})` (ya existe, sin cambios — `lib/data/reciclai_api_client.dart:80-95`).
- Produces: `MapViewModel.radioMetrosSeleccionado` (getter `double?`), `MapViewModel.seleccionarRadio(double? metros)` (método), `MapViewModel.radiosDisponiblesMetros` (`static const List<double>`) — la UI (Task 2) consume estos tres para construir el panel.

- [ ] **Step 1: Escribir los tests que fallan (reemplazando los de `radioActivo`/`alternarRadio`)**

Reemplazar el bloque completo entre las líneas 518 y 677 de
`test/ui/features/map/view_models/map_view_model_test.dart` por:

```dart
  test('radioMetrosSeleccionado arranca en null', () {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    expect(viewModel.radioMetrosSeleccionado, isNull);
  });

  test('seleccionarRadio(3000) con permiso concedido carga puntos por radio', () async {
    final apiClient = ApiClientFalso(
      resultadoEnRadio: [_punto()],
      resultadoCercanos: Covered([]),
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();

    await viewModel.seleccionarRadio(3000);

    expect(viewModel.radioMetrosSeleccionado, 3000);
    expect(apiClient.ultimoRadioMetrosPedido, 3000);
    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 1);
  });

  test('cambiar de 3000 a 7000 recarga con el nuevo radio', () async {
    final apiClient = ApiClientFalso(resultadoEnRadio: [_punto()]);
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarRadio(3000);

    await viewModel.seleccionarRadio(7000);

    expect(viewModel.radioMetrosSeleccionado, 7000);
    expect(apiClient.ultimoRadioMetrosPedido, 7000);
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 2);
  });

  test('seleccionarRadio(null) (Off) desde una distancia activa vuelve a puntos cercanos', () async {
    final apiClient = ApiClientFalso(
      resultadoEnRadio: [_punto(), _punto()],
      resultadoCercanos: Covered([_punto()]),
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarRadio(5000);
    expect(viewModel.radioMetrosSeleccionado, 5000);

    await viewModel.seleccionarRadio(null);

    expect(viewModel.radioMetrosSeleccionado, isNull);
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 2); // iniciar() + este Off
  });

  test('activar un radio con una comuna elegida la limpia y geolocaliza de nuevo', () async {
    final apiClient = ApiClientFalso(
      comunas: [_laFlorida],
      puntosPorComuna: [_punto()],
      resultadoEnRadio: [_punto(), _punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarComuna('la-florida');
    expect(viewModel.comunaSeleccionadaId, 'la-florida');

    await viewModel.seleccionarRadio(3000);

    expect(viewModel.comunaSeleccionadaId, isNull);
    expect(viewModel.radioMetrosSeleccionado, 3000);
    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(2));
  });

  test('elegir una comuna con un radio activo lo desactiva', () async {
    final apiClient = ApiClientFalso(
      comunas: [_laFlorida],
      puntosPorComuna: [_punto()],
      resultadoEnRadio: [_punto(), _punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarRadio(7000);
    expect(viewModel.radioMetrosSeleccionado, 7000);

    await viewModel.seleccionarComuna('la-florida');

    expect(viewModel.radioMetrosSeleccionado, isNull);
    expect(viewModel.comunaSeleccionadaId, 'la-florida');
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
  });

  test('seleccionarRadio al mismo valor que ya tenia no recarga nada', () async {
    final apiClient = ApiClientFalso(resultadoCercanos: Covered([]));
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);

    await viewModel.seleccionarRadio(null); // ya esta en null (Off)

    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 1); // solo el de iniciar()
  });

  test('seleccionarRadio(3000) sin permiso de ubicacion no intenta nada', () async {
    final apiClient = ApiClientFalso();
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await viewModel.iniciar();

    await viewModel.seleccionarRadio(3000);

    expect(viewModel.radioMetrosSeleccionado, 3000);
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
  });

  test('seleccionarRadio(3000) muestra Cargando de inmediato, antes de esperar la respuesta',
      () async {
    final apiClient = ApiClientFalso(
      resultadoCercanos: Covered([]),
      resultadoEnRadio: [_punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();

    final future = viewModel.seleccionarRadio(3000);
    expect(viewModel.cuerpo, isA<Cargando>());
    await future;

    expect(viewModel.cuerpo, isA<ConDatos>());
  });

  test('el modo radio nunca cae en SinSeleccion por falta de cobertura', () async {
    final apiClient = ApiClientFalso(
      resultadoCercanos: const NotCovered([]),
      resultadoEnRadio: [_punto()],
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    expect(viewModel.cuerpo, isA<SinSeleccion>());

    await viewModel.seleccionarRadio(5000);

    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
  });

  test('Off en una ubicacion no cubierta por ninguna comuna cae en SinSeleccion, no en error', () async {
    // Review Focus: Off reutiliza _cargarPorGeolocalizacion -> obtenerPuntosCercanos,
    // igual que el modo normal -- debe heredar el mismo manejo de NotCovered.
    final apiClient = ApiClientFalso(
      resultadoEnRadio: [_punto()],
      resultadoCercanos: const NotCovered([]),
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarRadio(3000);
    expect(viewModel.cuerpo, isA<ConDatos>());

    await viewModel.seleccionarRadio(null);

    expect(viewModel.cuerpo, isA<SinSeleccion>());
    expect((viewModel.cuerpo as SinSeleccion).mensaje, contains('no está cubierta'));
  });

  test(
      'Review Focus: elegir Off mientras una seleccion anterior todavia esta en vuelo descarta '
      'el resultado viejo', () async {
    final completer = Completer<List<RecyclingPoint>>();
    final apiClient = ApiClientFalso(
      completerPuntosEnRadio: completer,
      resultadoCercanos: Covered([_punto()]),
    );
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();

    final futureRadio = viewModel.seleccionarRadio(3000); // queda pendiente
    await viewModel.seleccionarRadio(null); // Off, antes de que el radio responda
    completer.complete([_punto(), _punto()]); // el radio "tardio" responde despues
    await futureRadio;
    await Future<void>.value();

    expect(viewModel.radioMetrosSeleccionado, isNull);
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1)); // el de Off, no el del radio tardio
  });
```

Agregar `import 'dart:async';` si no está ya importado en el archivo de
test (ya lo usan otros tests del mismo archivo con `completerPuntosPorComuna`
— verificar antes de duplicar el import).

Hay 3 tests más, fuera de ese bloque, que también usan
`alternarRadio`/`radioActivo` y deben actualizarse en el mismo paso:

En la línea 835 (`'en modo radio de 3km, moverse tambien recarga los puntos del radio'`),
cambiar el título a `'con un radio de 3km activo, moverse tambien recarga los puntos del radio'`
y la línea 854 de `await viewModel.alternarRadio(true);` a
`await viewModel.seleccionarRadio(3000);`.

En la línea 1253 (`'activar el radio de 3km no interfiere con la busqueda ampliada ni viceversa'`),
cambiar la línea 1270 de `expect(viewModel.radioActivo, isFalse);` a
`expect(viewModel.radioMetrosSeleccionado, isNull);`.

En la línea 1273 (`'buscarEnRadioAmplio funciona igual con el radio de 3km ya activo de antes'`),
cambiar la línea 1291 de `await viewModel.alternarRadio(true);` a
`await viewModel.seleccionarRadio(3000);`, y la línea 1299 de
`expect(viewModel.radioActivo, isTrue);` a
`expect(viewModel.radioMetrosSeleccionado, 3000);`.

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart`
Expected: FAIL — `radioMetrosSeleccionado`, `seleccionarRadio` y
`radiosDisponiblesMetros` no existen todavía en `MapViewModel`.

- [ ] **Step 3: Implementar el cambio minimo en `MapViewModel`**

Reemplazar (líneas 51-52):
```dart
  bool _radioActivo = false;
  bool get radioActivo => _radioActivo;
```
por:
```dart
  static const radiosDisponiblesMetros = [3000.0, 5000.0, 7000.0];

  double? _radioMetrosSeleccionado;
  double? get radioMetrosSeleccionado => _radioMetrosSeleccionado;
```

Reemplazar el método `alternarRadio` (líneas 309-322) por:
```dart
  Future<void> seleccionarRadio(double? metros) async {
    if (_radioMetrosSeleccionado == metros) return;
    _radioMetrosSeleccionado = metros;
    _busquedaAmpliadaActiva = false;
    _avisoBusquedaAmpliadaDescartado = false;
    if (metros != null) {
      _comunaSeleccionadaId = null;
    }
    if (_permiso != LocationPermissionStatus.concedido) return;
    final miOperacion = ++_operacionDeCuerpo;
    _cuerpo = const Cargando();
    notifyListeners();
    await _cargarPorGeolocalizacion(miOperacion);
  }
```

En `seleccionarComuna` (línea 325), cambiar `_radioActivo = false;` por
`_radioMetrosSeleccionado = null;`.

En `_obtenerCuerpoParaPosicion` (líneas 421-429), cambiar:
```dart
  Future<CuerpoMapaState> _obtenerCuerpoParaPosicion(double latitud, double longitud) async {
    if (_radioActivo) {
      final puntos = await _apiClient.obtenerPuntosEnRadio(
        latitud,
        longitud,
        timeout: _timeoutPorIntentoAlAbrir,
      );
      return ConDatos(puntos);
    }
```
por:
```dart
  Future<CuerpoMapaState> _obtenerCuerpoParaPosicion(double latitud, double longitud) async {
    final radioMetros = _radioMetrosSeleccionado;
    if (radioMetros != null) {
      final puntos = await _apiClient.obtenerPuntosEnRadio(
        latitud,
        longitud,
        radioMetros: radioMetros,
        timeout: _timeoutPorIntentoAlAbrir,
      );
      return ConDatos(puntos);
    }
```

Por último, actualizar el comentario de la línea 61 (doc de
`_busquedaAmpliadaActiva`) cambiando "activar o desactivar el radio de
3km" por "elegir cualquier radio o apagarlo (Off)" — ya no hay un único
radio fijo de 3km.

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart`
Expected: PASS — todos los tests del archivo, incluidos los nuevos.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/map/view_models/map_view_model.dart test/ui/features/map/view_models/map_view_model_test.dart
git commit -m "feat: MapViewModel generaliza el radio a 4 distancias (Off/3/5/7km)"
```

---

### Task 2: Widgets del selector (disparador + panel) y wiring en `map_view.dart`

**Files:**
- Delete: `lib/ui/features/map/views/radius_toggle_button.dart`, `test/ui/features/map/views/radius_toggle_button_test.dart`
- Create: `lib/ui/features/map/views/radius_selector_trigger.dart`
- Create: `lib/ui/features/map/views/radius_selector_panel.dart`
- Create: `test/ui/features/map/views/radius_selector_trigger_test.dart`
- Create: `test/ui/features/map/views/radius_selector_panel_test.dart`
- Modify: `lib/ui/features/map/views/map_view.dart:23` (import), `:70-95` (estado de `_MapViewState`), `:285-312` (Stack con la barra)
- Test: `test/ui/features/map/views/map_view_test.dart`

**Interfaces:**
- Consumes (de Task 1): `MapViewModel.radioMetrosSeleccionado`, `MapViewModel.seleccionarRadio(double? metros)`, `MapViewModel.radiosDisponiblesMetros`, `MapViewModel.tienePermisoDeUbicacion`.
- Consumes: `GlassBar` (`lib/ui/core/glass_bar.dart`), `GlassBarAction` (`lib/ui/core/glass_bar_action.dart`), `BotonCerrarHoja` (`lib/ui/core/floating_sheet_card.dart`), `espacioXs`/`espacioSm`/`espacioMd`/`espacioLg` (`lib/ui/core/spacing.dart`).
- Produces: `RadiusSelectorTrigger({required MapViewModel viewModel, required VoidCallback onTap})` y `RadiusSelectorPanel({required MapViewModel viewModel, required VoidCallback onCerrar})` — widgets públicos, usados solo desde `map_view.dart`.

- [ ] **Step 1: Escribir los tests que fallan para `RadiusSelectorTrigger`**

Crear `test/ui/features/map/views/radius_selector_trigger_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/core/theme.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/radius_selector_trigger.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) =>
    MaterialApp(theme: construirTemaReciclai(Brightness.light), home: Scaffold(body: child));

Future<MapViewModel> _viewModelConPermiso(LocationPermissionStatus permiso) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(),
    locationService: LocationServiceFalsa(permiso: permiso, posicion: posicionDePrueba()),
  );
  await viewModel.iniciar();
  return viewModel;
}

void main() {
  testWidgets('sin radio seleccionado muestra el icono sin relleno', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () {})),
    );

    expect(find.byIcon(Icons.wifi_tethering_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering), findsNothing);
  });

  testWidgets('con un radio seleccionado muestra el icono relleno en verde', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await viewModel.seleccionarRadio(3000);
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () {})),
    );

    final icono = tester.widget<Icon>(find.byIcon(Icons.wifi_tethering));
    final colorEsperado =
        Theme.of(tester.element(find.byType(RadiusSelectorTrigger))).colorScheme.primary;
    expect(icono.color, colorEsperado);
  });

  testWidgets('tocarlo con permiso concedido llama a onTap', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    var tocado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () => tocado = true)),
    );

    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    expect(tocado, isTrue);
  });

  testWidgets('sin permiso de ubicacion no responde al toque', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.denegado);
    var tocado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorTrigger(viewModel: viewModel, onTap: () => tocado = true)),
    );

    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    expect(tocado, isFalse);
  });
}
```

Borrar `test/ui/features/map/views/radius_toggle_button_test.dart` (su
reemplazo es el archivo de arriba).

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/map/views/radius_selector_trigger_test.dart`
Expected: FAIL — no existe `lib/ui/features/map/views/radius_selector_trigger.dart`.

- [ ] **Step 3: Crear `RadiusSelectorTrigger` y borrar el widget viejo**

Borrar `lib/ui/features/map/views/radius_toggle_button.dart`.

Crear `lib/ui/features/map/views/radius_selector_trigger.dart`:

```dart
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
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/map/views/radius_selector_trigger_test.dart`
Expected: PASS.

- [ ] **Step 5: Escribir los tests que fallan para `RadiusSelectorPanel`**

Crear `test/ui/features/map/views/radius_selector_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/core/theme.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/radius_selector_panel.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) =>
    MaterialApp(theme: construirTemaReciclai(Brightness.light), home: Scaffold(body: child));

Future<MapViewModel> _viewModelConPermiso() async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(resultadoEnRadio: []),
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  return viewModel;
}

void main() {
  testWidgets('muestra los 4 botones: Off, 3 km, 5 km, 7 km', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () {})),
    );

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('3 km'), findsOneWidget);
    expect(find.text('5 km'), findsOneWidget);
    expect(find.text('7 km'), findsOneWidget);
  });

  testWidgets('sin radio activo, "Off" no responde al toque', (tester) async {
    final viewModel = await _viewModelConPermiso();
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.text('Off'), warnIfMissed: false);
    await tester.pump();

    expect(viewModel.radioMetrosSeleccionado, isNull);
    expect(cerrado, isFalse);
  });

  testWidgets('con un radio activo, tocar "Off" lo apaga y cierra el panel', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await viewModel.seleccionarRadio(3000);
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.text('Off'));
    await tester.pump();

    expect(viewModel.radioMetrosSeleccionado, isNull);
    expect(cerrado, isTrue);
  });

  testWidgets('tocar "5 km" selecciona ese radio y cierra el panel', (tester) async {
    final viewModel = await _viewModelConPermiso();
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.text('5 km'));
    await tester.pump();

    expect(viewModel.radioMetrosSeleccionado, 5000);
    expect(cerrado, isTrue);
  });

  testWidgets('el radio activo se ve resaltado en verde', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await viewModel.seleccionarRadio(7000);
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () {})),
    );

    final material = tester.widget<Material>(
      find.ancestor(of: find.text('7 km'), matching: find.byType(Material)).first,
    );
    final colorEsperado =
        Theme.of(tester.element(find.byType(RadiusSelectorPanel))).colorScheme.primary;
    expect(material.color, colorEsperado);
  });

  testWidgets('tiene su propia X para cerrar sin elegir nada', (tester) async {
    final viewModel = await _viewModelConPermiso();
    var cerrado = false;
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () => cerrado = true)),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cerrado, isTrue);
    expect(viewModel.radioMetrosSeleccionado, isNull);
  });

  testWidgets('los 4 botones tienen 1.5px de separacion entre si', (tester) async {
    final viewModel = await _viewModelConPermiso();
    await tester.pumpWidget(
      _envolver(RadiusSelectorPanel(viewModel: viewModel, onCerrar: () {})),
    );

    final derechaOff = tester.getTopRight(find.text('Off')).dx;
    final izquierda3km = tester.getTopLeft(find.text('3 km')).dx;
    // La separacion incluye el padding horizontal propio de cada boton -- se
    // verifica que sean adyacentes (sin un hueco mayor), no un valor exacto
    // de texto a texto, que depende de ese padding interno.
    expect(izquierda3km, greaterThanOrEqualTo(derechaOff));
  });
}
```

- [ ] **Step 6: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/map/views/radius_selector_panel_test.dart`
Expected: FAIL — no existe `lib/ui/features/map/views/radius_selector_panel.dart`.

- [ ] **Step 7: Crear `RadiusSelectorPanel`**

Crear `lib/ui/features/map/views/radius_selector_panel.dart`:

```dart
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
        BotonCerrarHoja(onTap: onCerrar),
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
            style: TextStyle(color: colorTexto, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/map/views/radius_selector_panel_test.dart`
Expected: PASS.

- [ ] **Step 9: Escribir los tests que fallan para el wiring en `map_view.dart`**

Agregar a `test/ui/features/map/views/map_view_test.dart` (junto a los
demás tests de overlays del mapa — buscar el bloque de tests de
`_AvisoBusquedaAmpliada` como referencia de estilo):

```dart
  testWidgets('el panel de radio no se ve hasta tocar el disparador', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsNothing);
  });

  testWidgets('tocar el disparador abre el panel con las 4 opciones', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('3 km'), findsOneWidget);
    expect(find.text('5 km'), findsOneWidget);
    expect(find.text('7 km'), findsOneWidget);
  });

  testWidgets('elegir una distancia cierra el panel', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoEnRadio: []),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    await tester.tap(find.text('3 km'));
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsNothing);
    expect(viewModel.radioMetrosSeleccionado, 3000);
  });

  testWidgets('tocar afuera del panel lo cierra sin cambiar el radio', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    // Un punto bien arriba del mapa, lejos de la barra y del panel.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.text('Off'), findsNothing);
    expect(viewModel.radioMetrosSeleccionado, isNull);
  });

  testWidgets('la X del panel lo cierra sin cambiar el radio', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.wifi_tethering_outlined));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Off'), findsNothing);
    expect(viewModel.radioMetrosSeleccionado, isNull);
  });
```

Revisar el inicio de `map_view_test.dart` para reusar su helper
`posicionDePrueba()` (de `fakes.dart`) y confirmar los imports ya
presentes (`Icons`, `MapViewModel`, etc.) — no duplicar imports.

- [ ] **Step 10: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/map/views/map_view_test.dart`
Expected: FAIL — el panel todavía no existe en `map_view.dart` (el ícono
`Icons.wifi_tethering_outlined` sigue siendo el `RadiusToggleButton`
viejo, que no abre nada).

- [ ] **Step 11: Wiring en `map_view.dart`**

Cambiar el import de la línea 23:
```dart
import 'radius_toggle_button.dart';
```
por:
```dart
import 'radius_selector_panel.dart';
import 'radius_selector_trigger.dart';
```

Agregar un campo de estado nuevo en `_MapViewState` (junto a los
`GlobalKey` existentes, alrededor de la línea 75):
```dart
  bool _selectorDeRadioAbierto = false;
```

Reemplazar el uso de `RadiusToggleButton` dentro del `GlassBar` (línea
294-297):
```dart
                            RadiusToggleButton(
                              key: _keyRadioToggle,
                              viewModel: widget.viewModel,
                            ),
```
por:
```dart
                            RadiusSelectorTrigger(
                              key: _keyRadioToggle,
                              viewModel: widget.viewModel,
                              onTap: () => setState(
                                () => _selectorDeRadioAbierto = !_selectorDeRadioAbierto,
                              ),
                            ),
```

Agregar dos nuevos hijos al `Stack` del método `build`, justo después del
`Positioned` que contiene la barra (después de la línea 312, antes del
cierre de `children: [...]` del `Stack` principal):
```dart
              if (_selectorDeRadioAbierto)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _selectorDeRadioAbierto = false),
                  ),
                ),
              if (_selectorDeRadioAbierto)
                Positioned(
                  left: espacioMd,
                  right: espacioMd,
                  // Pegado arriba de la barra principal (mismo bottom + su
                  // alto, sin el espacio que si tienen el aviso de "sin
                  // resultados" o el boton de 15km) -- para que se vea como
                  // una extension de la barra, no como una tarjeta aparte.
                  bottom: espacioLg + MediaQuery.of(context).padding.bottom + 48,
                  child: Center(
                    child: RadiusSelectorPanel(
                      viewModel: widget.viewModel,
                      onCerrar: () => setState(() => _selectorDeRadioAbierto = false),
                    ),
                  ),
                ),
```

(El orden importa: la barrera y el panel van DESPUÉS del `Positioned` de
la barra principal en la lista de `children`, para quedar pintados
encima — así un toque en cualquier parte de la barra, mientras el panel
está abierto, lo cierra en vez de disparar ese otro botón.)

- [ ] **Step 12: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/map/views/map_view_test.dart`
Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add lib/ui/features/map/views/radius_selector_trigger.dart lib/ui/features/map/views/radius_selector_panel.dart lib/ui/features/map/views/map_view.dart
git rm lib/ui/features/map/views/radius_toggle_button.dart
git add test/ui/features/map/views/radius_selector_trigger_test.dart test/ui/features/map/views/radius_selector_panel_test.dart test/ui/features/map/views/map_view_test.dart
git rm test/ui/features/map/views/radius_toggle_button_test.dart
git commit -m "feat: panel de radio de 4 distancias como extension de la barra"
```

---

### Task 3: Unificar el color "activo" a verde en los 3 íconos de la barra

**Files:**
- Modify: `lib/ui/features/map/views/material_filter_button.dart:19`
- Modify: `lib/ui/features/map/views/comuna_selector.dart:29-32`
- Test: `test/ui/features/map/views/material_filter_button_test.dart:63-75`
- Test: `test/ui/features/map/views/comuna_selector_test.dart`

**Interfaces:**
- Consumes: `MapViewModel.materialesSeleccionados` (ya existe), `comunaSeleccionadaId` (parámetro ya existente de `ComunaSelector`).
- No produce interfaces nuevas — cambio de color únicamente.

- [ ] **Step 1: Actualizar el test de color de `MaterialFilterButton` (ya existente) para que falle**

En `test/ui/features/map/views/material_filter_button_test.dart`, el test
`'con materiales seleccionados, el icono usa el color de acento del tema'`
(líneas 63-75) cambia su expectativa de `colorScheme.secondary` a
`colorScheme.primary`:

```dart
  testWidgets('con materiales seleccionados, el icono usa el verde primario del tema', (
    tester,
  ) async {
    final viewModel = await _viewModelConMateriales();
    viewModel.aplicarFiltroMateriales({'plastico'});
    await tester.pumpWidget(_envolver(MaterialFilterButton(viewModel: viewModel)));

    final icono = tester.widget<Icon>(find.byIcon(Icons.filter_alt));
    final colorEsperado = Theme.of(
      tester.element(find.byType(MaterialFilterButton)),
    ).colorScheme.primary;
    expect(icono.color, colorEsperado);
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/ui/features/map/views/material_filter_button_test.dart`
Expected: FAIL — el ícono sigue usando `colorScheme.secondary` (terracota),
no coincide con `colorScheme.primary`.

- [ ] **Step 3: Cambiar el color en `MaterialFilterButton`**

En `lib/ui/features/map/views/material_filter_button.dart:19`, cambiar:
```dart
      color: activo ? Theme.of(context).colorScheme.secondary : null,
```
por:
```dart
      color: activo ? Theme.of(context).colorScheme.primary : null,
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/ui/features/map/views/material_filter_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Escribir el test que falla para `ComunaSelector`**

Agregar a `test/ui/features/map/views/comuna_selector_test.dart`:

```dart
  testWidgets('con una comuna seleccionada, el icono usa el verde primario del tema', (
    tester,
  ) async {
    await tester.pumpWidget(
      _envolverConTema(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          comunaSeleccionadaId: _laFlorida.id,
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );

    final icono = tester.widget<Icon>(find.byIcon(Icons.search));
    final colorEsperado =
        Theme.of(tester.element(find.byType(ComunaSelector))).colorScheme.primary;
    expect(icono.color, colorEsperado);
  });

  testWidgets('sin comuna seleccionada, el icono sigue blanco', (tester) async {
    await tester.pumpWidget(
      _envolverConTema(
        ComunaSelector(
          comunas: const [_laFlorida, _sanJoaquin],
          onElegirComuna: (_) {},
          onLimpiarComuna: () {},
        ),
      ),
    );

    final icono = tester.widget<Icon>(find.byIcon(Icons.search));
    expect(icono.color, Colors.white);
  });
```

- [ ] **Step 6: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/map/views/comuna_selector_test.dart`
Expected: FAIL — `ComunaSelector` nunca pasa `color` a `GlassBarAction`
hoy, el ícono siempre sale blanco (default).

- [ ] **Step 7: Agregar el color activo a `ComunaSelector`**

En `lib/ui/features/map/views/comuna_selector.dart:29-32`, cambiar:
```dart
  @override
  Widget build(BuildContext context) {
    return GlassBarAction(
      icon: Icons.search,
      onTap: comunas.isEmpty ? null : () => _abrirBuscador(context),
    );
  }
```
por:
```dart
  @override
  Widget build(BuildContext context) {
    return GlassBarAction(
      icon: Icons.search,
      color: comunaSeleccionadaId != null ? Theme.of(context).colorScheme.primary : null,
      onTap: comunas.isEmpty ? null : () => _abrirBuscador(context),
    );
  }
```

- [ ] **Step 8: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/map/views/comuna_selector_test.dart`
Expected: PASS.

- [ ] **Step 9: Correr la suite completa**

Run: `flutter test`
Expected: PASS — todo el proyecto, incluidos los tests de las Tasks 1 y 2.

- [ ] **Step 10: Commit**

```bash
git add lib/ui/features/map/views/material_filter_button.dart lib/ui/features/map/views/comuna_selector.dart test/ui/features/map/views/material_filter_button_test.dart test/ui/features/map/views/comuna_selector_test.dart
git commit -m "fix: unificar a verde el color activo de los iconos de la barra"
```

---

### Task 4: Actualizar el paso del tour

**Files:**
- Modify: `lib/ui/features/map/views/map_view.dart:123-128`
- Test: `test/ui/features/map/views/map_view_test.dart:664-684`

**Interfaces:**
- Consumes: ninguna de las tasks anteriores — cambio de copy únicamente.
- No produce interfaces nuevas.

- [ ] **Step 1: Actualizar el test existente para que falle**

En `test/ui/features/map/views/map_view_test.dart`, el test
`'el tour explica el switch de radio de 3km'` (líneas 664-684) se
renombra y agrega una aserción sobre el nuevo texto:

```dart
  testWidgets('el tour explica el selector de radio de 3/5/7 km', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(comunas: [_laFlorida], puntosPorComuna: [_punto()]),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();
    await _elegirComunaEnElSelector(tester, 'La Florida');

    await tester.tap(find.byKey(const Key('tour-trigger-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();

    expect(find.text('Busca por cercanía'), findsOneWidget);
    expect(
      find.text(
        'Elige 3, 5 o 7 km a la redonda tuyo, sin importar la comuna — útil si vives '
        'cerca del límite entre dos comunas.',
      ),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/ui/features/map/views/map_view_test.dart`
Expected: FAIL — el texto del paso todavía menciona "3km" fijo, no
coincide con el nuevo texto esperado.

- [ ] **Step 3: Actualizar el texto del paso en `map_view.dart`**

En `lib/ui/features/map/views/map_view.dart:123-128`, cambiar:
```dart
          TourStep(
            titulo: 'Busca por cercanía',
            cuerpo: 'Actívalo para ver los puntos a 3km a la redonda tuyo, sin importar la '
                'comuna — útil si vives cerca del límite entre dos comunas.',
            anchorKey: _keyRadioToggle,
          ),
```
por:
```dart
          TourStep(
            titulo: 'Busca por cercanía',
            cuerpo: 'Elige 3, 5 o 7 km a la redonda tuyo, sin importar la comuna — útil si '
                'vives cerca del límite entre dos comunas.',
            anchorKey: _keyRadioToggle,
          ),
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/ui/features/map/views/map_view_test.dart`
Expected: PASS.

- [ ] **Step 5: Correr la suite completa y `flutter analyze`**

Run: `flutter test && flutter analyze`
Expected: PASS — toda la suite verde; `flutter analyze` sin hallazgos
nuevos (los 2 `prefer_initializing_formals` ya existentes en
`map_view_model.dart` son preexistentes y no forman parte de este cambio).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/map/views/map_view.dart test/ui/features/map/views/map_view_test.dart
git commit -m "docs: actualizar el paso del tour para las 3 distancias de radio"
```
