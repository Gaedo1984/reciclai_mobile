# Búsqueda por radio de 3km — Mobile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** agregar un switch en el mapa que, activado, busca puntos de reciclaje a 3km a la
redonda de la ubicación actual del usuario (cruzando límites de comuna) en vez de limitarse a la
comuna que contiene su coordenada — y explicarlo como un paso nuevo del tour interactivo.

**Architecture:** un método nuevo en `ReciclaiApiClient` llama al endpoint de backend ya
desplegado (`GET /points/nearby/radius`). `MapViewModel` gana un booleano `radioActivo` que
bifurca `_cargarPorGeolocalizacion` entre ese endpoint nuevo y el de comuna existente, y queda
mutuamente excluyente con la comuna elegida a mano (elegir una desactiva la otra, en ambos
sentidos). Un ícono nuevo en la `GlassBar` (mismo patrón visual que el filtro de materiales)
dispara el switch, y el tour gana un sexto paso apuntando a él.

**Tech Stack:** Flutter, `provider`-less `ChangeNotifier` (`MapViewModel`), `flutter_test` con
fakes propios del proyecto (`test/fakes.dart`).

**Spec:** `docs/superpowers/specs/2026-09-30-busqueda-por-radio-diseno.md` (secciones 2, 3 y 4 —
la sección 1, backend, ya está implementada, revisada y desplegada en Render:
`GET /points/nearby/radius` responde `200` en producción, verificado con `curl` antes de
escribir este plan).

## Global Constraints

- El radio es fijo (3000m, decidido por el backend) — la app nunca envía ni decide un radio, solo
  llama al endpoint.
- `radioActivo` **no se persiste** entre aperturas de la app — arranca siempre en `false`, igual
  que el resto del estado de `MapViewModel` hoy (spec, "Fuera de alcance").
- Activar el radio limpia la comuna elegida a mano, y viceversa — son mutuamente excluyentes,
  nunca ambos a la vez (spec, sección 3.2, corregida tras revisión del usuario).
- Los filtros de material (`filtrarPorMateriales`) no se tocan — ya se aplican del lado de la app
  sobre lo que sea que haya en `cuerpo`, sin importar cómo se cargó.
- Los 3 reintentos automáticos de 20s (`_maxIntentosAlAbrir`, `_timeoutPorIntentoAlAbrir`, ya
  existentes) aplican igual en modo radio — es el mismo flujo de apertura por geolocalización,
  solo cambia qué endpoint llama.

## Review Focus

- **Activar el radio con una comuna ya elegida**: debe limpiar la comuna y geolocalizar de nuevo
  desde la posición actual real (no una guardada) — es el caso que el usuario pidió confirmar
  explícitamente antes de aprobar la spec. Task 2 lo cubre con un test dedicado.
- **Elegir una comuna con el radio ya activo**: debe desactivar el radio — simétrico al caso
  anterior, fácil de implementar solo en un sentido y olvidar el otro. Task 2 lo cubre.
- **Tocar el switch sin permiso de ubicación**: no debe intentar nada (no tiene con qué
  centrarse) — el botón se ve pero `onTap` es `null`, mismo criterio que
  `MaterialFilterButton` sin materiales cargados. Task 3 lo cubre.
- **Alternar el switch dos veces seguidas al mismo valor** (ej. `alternarRadio(true)` cuando ya
  está `true`): no debe disparar una recarga innecesaria — Task 2 lo cubre con un test de
  no-op.
- **El endpoint de radio nunca devuelve "sin cobertura"** (a diferencia del de comuna): un olvido
  fácil sería reusar el manejo de `NotCovered` del camino de comuna. Task 2 lo cubre asegurando
  que la rama de radio nunca produce `SinSeleccion` por falta de cobertura.

---

## Task 1: `ReciclaiApiClient.obtenerPuntosEnRadio`

**Files:**
- Modify: `lib/data/reciclai_api_client.dart`
- Modify: `test/fakes.dart`
- Test: `test/data/reciclai_api_client_test.dart`

**Interfaces:**
- Consumes: `_get(String path, {Map<String,String>? queryParameters, Duration? timeout})` (ya
  existente en el mismo archivo, sin cambios), `RecyclingPoint.fromJson` (ya existente).
- Produces: `ReciclaiApiClient.obtenerPuntosEnRadio(double lat, double lng, {Duration? timeout})
  -> Future<List<RecyclingPoint>>` — Task 2 lo consume desde `MapViewModel`.
  `ApiClientFalso.obtenerPuntosEnRadio` (misma firma) y
  `ApiClientFalso.vecesLlamadoObtenerPuntosEnRadio` (contador) — Task 2 los consume en sus tests.

- [ ] **Step 1: Escribir el test que falla**

Agregar a `test/data/reciclai_api_client_test.dart`, después del test
`obtenerPuntosCercanos con covered=false devuelve NotCovered con las comunas` (busca ese texto
para ubicar el punto de inserción):

```dart
  test('obtenerPuntosEnRadio manda lat/lng como query y parsea la lista de puntos', () async {
    final cliente = _ClienteFalso((request) {
      expect(request.url.path, endsWith('/points/nearby/radius'));
      expect(request.url.queryParameters['lat'], '-33.5');
      expect(request.url.queryParameters['lng'], '-70.6');
      return _respuestaJson(200, [
        {
          'id': '1',
          'nombre': 'Punto Vecino',
          'direccion': 'Av. Siempre Viva 123',
          'ubicacion': {'lat': -33.52, 'lng': -70.60},
          'tipo': 'punto_limpio',
          'materiales': ['plastico'],
          'horario': null,
          'es_empresa': false,
          'sitio_web': null,
          'confianza': 'media',
        },
      ]);
    });
    final api = ReciclaiApiClient(client: cliente);

    final puntos = await api.obtenerPuntosEnRadio(-33.50, -70.60);

    expect(puntos, hasLength(1));
    expect(puntos.first.nombre, 'Punto Vecino');
  });

  test('obtenerPuntosEnRadio con respuesta con forma inesperada lanza ReciclaiApiException',
      () async {
    final cliente = _ClienteFalso((request) {
      return _respuestaJson(200, {'esto': 'no es una lista de puntos'});
    });
    final api = ReciclaiApiClient(client: cliente);

    expect(() => api.obtenerPuntosEnRadio(-33.50, -70.60), throwsA(isA<ReciclaiApiException>()));
  });
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/data/reciclai_api_client_test.dart -N obtenerPuntosEnRadio`
Expected: FAIL — `The method 'obtenerPuntosEnRadio' isn't defined for the type 'ReciclaiApiClient'`
(error de compilación, no de aserción — el método no existe todavía)

- [ ] **Step 3: Implementar `obtenerPuntosEnRadio`**

En `lib/data/reciclai_api_client.dart`, agregar después de `obtenerPuntosCercanos` (antes del
método privado `_get`):

```dart
  Future<List<RecyclingPoint>> obtenerPuntosEnRadio(
    double lat,
    double lng, {
    Duration? timeout,
  }) async {
    final cuerpo = await _get(
      '/points/nearby/radius',
      queryParameters: {'lat': '$lat', 'lng': '$lng'},
      timeout: timeout,
    );
    try {
      return (cuerpo as List<dynamic>)
          .map((e) => RecyclingPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }
```

- [ ] **Step 4: Correr el test para verificar que pasa**

Run: `flutter test test/data/reciclai_api_client_test.dart`
Expected: PASS — todos los tests del archivo (los existentes más los 2 nuevos)

- [ ] **Step 5: Extender `ApiClientFalso` en `test/fakes.dart`**

`ApiClientFalso implements ReciclaiApiClient` — al agregar el método real al cliente, el fake deja
de compilar hasta que lo implemente también (Dart exige implementar todos los miembros de la
interfaz). Agregar, siguiendo el mismo patrón que `obtenerPuntosCercanos`:

En el constructor (después de `fallosDeObtenerPuntosCercanosAntesDeExito`):

```dart
    this.resultadoEnRadio = const [],
```

Como campo (después de `resultadoCercanos`):

```dart
  final List<RecyclingPoint> resultadoEnRadio;
```

Como contador (después de `vecesLlamadoObtenerPuntosCercanos`):

```dart
  int vecesLlamadoObtenerPuntosEnRadio = 0;
```

Y el método (después de `obtenerPuntosCercanos`):

```dart
  @override
  Future<List<RecyclingPoint>> obtenerPuntosEnRadio(
    double lat,
    double lng, {
    Duration? timeout,
  }) async {
    vecesLlamadoObtenerPuntosEnRadio++;
    if (excepcion != null) throw excepcion!;
    return resultadoEnRadio;
  }
```

(a diferencia de `obtenerPuntosCercanos`, este no necesita el mecanismo de "fallar N veces antes
de éxito" — ese reintento ya se probó a fondo con el endpoint de comuna en el plan anterior, y
Task 2 de este plan reutiliza `_cargarPorGeolocalizacion` tal cual, sin duplicar esa cobertura).

- [ ] **Step 6: Correr toda la suite para verificar que compila y pasa**

Run: `flutter test`
Expected: PASS — toda la suite (no debe haber quedado ningún archivo que use `ApiClientFalso` sin
compilar)

- [ ] **Step 7: Commit**

```bash
git add lib/data/reciclai_api_client.dart test/fakes.dart test/data/reciclai_api_client_test.dart
git commit -m "feat: agregar ReciclaiApiClient.obtenerPuntosEnRadio"
```

---

## Task 2: Estado del radio en `MapViewModel`

**Files:**
- Modify: `lib/ui/features/map/view_models/map_view_model.dart`
- Test: `test/ui/features/map/view_models/map_view_model_test.dart`

**Interfaces:**
- Consumes: `ApiClientFalso.resultadoEnRadio`/`vecesLlamadoObtenerPuntosEnRadio` (Task 1),
  `ReciclaiApiClient.obtenerPuntosEnRadio` (Task 1).
- Produces: `MapViewModel.radioActivo` (getter `bool`), `MapViewModel.alternarRadio(bool activo)
  -> Future<void>` — Task 3 los consume desde `RadiusToggleButton`.

- [ ] **Step 1: Escribir los tests que fallan**

Agregar a `test/ui/features/map/view_models/map_view_model_test.dart`, después del último test
existente del archivo (busca el final del `void main() { ... }`, antes del cierre):

```dart
  test('radioActivo arranca en false', () {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    expect(viewModel.radioActivo, isFalse);
  });

  test('alternarRadio(true) con permiso concedido carga puntos por radio', () async {
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

    await viewModel.alternarRadio(true);

    expect(viewModel.radioActivo, isTrue);
    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 1);
  });

  test('activar el radio con una comuna elegida la limpia y geolocaliza de nuevo', () async {
    final apiClient = ApiClientFalso(
      comunas: [_laFlorida],
      puntosPorComuna: [_punto()],
      // resultadoCercanos lo consume la carga inicial de iniciar() (modo comuna,
      // antes de elegir nada a mano) — sin esto, ApiClientFalso.obtenerPuntosCercanos
      // revienta con un null-check error (no un ReciclaiApiException) al no tener
      // nada que devolver, antes de llegar a lo que este test realmente prueba.
      resultadoCercanos: const Covered([]),
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

    await viewModel.alternarRadio(true);

    expect(viewModel.comunaSeleccionadaId, isNull);
    expect(viewModel.radioActivo, isTrue);
    expect(viewModel.cuerpo, isA<ConDatos>());
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(2));
  });

  test('elegir una comuna con el radio activo lo desactiva', () async {
    final apiClient = ApiClientFalso(
      comunas: [_laFlorida],
      puntosPorComuna: [_punto()],
      // Igual que en el test anterior: la carga inicial de iniciar() (modo comuna)
      // necesita esto seteado para no reventar con un null-check error.
      resultadoCercanos: const Covered([]),
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
    await viewModel.alternarRadio(true);
    expect(viewModel.radioActivo, isTrue);

    await viewModel.seleccionarComuna('la-florida');

    expect(viewModel.radioActivo, isFalse);
    expect(viewModel.comunaSeleccionadaId, 'la-florida');
    expect((viewModel.cuerpo as ConDatos).puntos, hasLength(1));
  });

  test('alternarRadio al mismo valor que ya tenia no recarga nada', () async {
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

    await viewModel.alternarRadio(false); // ya esta en false

    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
    expect(apiClient.vecesLlamadoObtenerPuntosCercanos, 1); // solo el de iniciar()
  });

  test('alternarRadio(true) sin permiso de ubicacion no intenta nada', () async {
    final apiClient = ApiClientFalso();
    final viewModel = MapViewModel(
      apiClient: apiClient,
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await viewModel.iniciar();

    await viewModel.alternarRadio(true);

    expect(viewModel.radioActivo, isTrue);
    expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
  });
```

(`_laFlorida` y `_punto()` ya están definidos arriba en este archivo — reutilizarlos tal cual, no
redefinirlos).

- [ ] **Step 2: Correr los tests para verificar que fallan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart`
Expected: FAIL — error de compilación (`radioActivo`/`alternarRadio` no existen en `MapViewModel`,
`resultadoEnRadio` no existe en `ApiClientFalso`... espera, `resultadoEnRadio` ya lo agregó Task 1 —
si Task 1 ya está commiteada, el único error de compilación acá debería ser
`radioActivo`/`alternarRadio` no definidos en `MapViewModel`)

- [ ] **Step 3: Implementar el estado en `MapViewModel`**

En `lib/ui/features/map/view_models/map_view_model.dart`, agregar el campo y el getter después de
`_comunaSeleccionadaId`/`comunaSeleccionadaId` (línea 33-34 hoy):

```dart
  bool _radioActivo = false;
  bool get radioActivo => _radioActivo;
```

Agregar el método `alternarRadio` después de `seleccionarComuna` (línea 109-120 hoy):

```dart
  Future<void> alternarRadio(bool activo) async {
    if (_radioActivo == activo) return;
    _radioActivo = activo;
    if (activo) {
      _comunaSeleccionadaId = null;
    }
    if (_permiso != LocationPermissionStatus.concedido) return;
    await _cargarPorGeolocalizacion(++_operacionDeCuerpo);
  }
```

Modificar `seleccionarComuna` (línea 109-120 hoy) para que limpie el radio al principio:

```dart
  Future<void> seleccionarComuna(String comunaId) async {
    _radioActivo = false;
    final miOperacion = ++_operacionDeCuerpo;
    _comunaSeleccionadaId = comunaId;
    _cuerpo = const Cargando();
    notifyListeners();
    try {
      final puntos = await _apiClient.obtenerPuntosPorComuna(comunaId);
      _aplicarCuerpo(miOperacion, ConDatos(puntos));
    } on ReciclaiApiException catch (e) {
      _aplicarCuerpo(miOperacion, ErrorAlCargar(e.message));
    }
  }
```

(único cambio: la línea `_radioActivo = false;` agregada al principio — el resto del método queda
igual).

Modificar `_cargarPorGeolocalizacion` (línea 156-208 hoy) para que bifurque según `_radioActivo`
dentro del bucle de reintentos:

```dart
  Future<void> _cargarPorGeolocalizacion(int miOperacion) async {
    final Position posicion;
    try {
      posicion = await _locationService.obtenerPosicionActual();
    } catch (_) {
      _aplicarCuerpo(
        miOperacion,
        const SinSeleccion(
          mensaje: 'No se pudo obtener tu ubicación (¿el GPS está activado?). '
              'Elige tu comuna manualmente.',
        ),
      );
      return;
    }
    _miUbicacion = LatLng(posicion.latitude, posicion.longitude);

    if (!estaEnChile(posicion.latitude, posicion.longitude)) {
      _aplicarCuerpo(miOperacion, const FueraDeRango());
      return;
    }

    // Al abrir la app, el backend puede estar "dormido" (plan free de Render) y
    // el primer request tras despertar demora bastante — en vez de una sola
    // espera larga y silenciosa que se siente pegada, se reintenta unas pocas
    // veces con un timeout mas corto por intento: si Render despierta en
    // cualquiera de esos intentos, la app abre sola sin que el usuario tenga
    // que tocar nada. Si los 3 fallan, cae al mismo ErrorAlCargar de siempre
    // (con su boton "Reintentar" manual, sin cambios ahi). Aplica igual en
    // modo radio — es el mismo flujo de apertura por geolocalizacion, solo
    // cambia que endpoint llama.
    ReciclaiApiException? ultimoError;
    for (var intento = 1; intento <= _maxIntentosAlAbrir; intento++) {
      if (miOperacion != _operacionDeCuerpo) return;
      try {
        if (_radioActivo) {
          final puntos = await _apiClient.obtenerPuntosEnRadio(
            posicion.latitude,
            posicion.longitude,
            timeout: _timeoutPorIntentoAlAbrir,
          );
          _aplicarCuerpo(miOperacion, ConDatos(puntos));
        } else {
          final resultado = await _apiClient.obtenerPuntosCercanos(
            posicion.latitude,
            posicion.longitude,
            timeout: _timeoutPorIntentoAlAbrir,
          );
          _aplicarCuerpo(
            miOperacion,
            switch (resultado) {
              Covered(:final puntos) => ConDatos(puntos),
              NotCovered() => const SinSeleccion(
                  mensaje: 'Tu ubicación no está cubierta todavía. Elige tu comuna manualmente.',
                ),
            },
          );
        }
        return;
      } on ReciclaiApiException catch (e) {
        ultimoError = e;
      }
    }
    _aplicarCuerpo(miOperacion, ErrorAlCargar(ultimoError!.message));
  }
```

- [ ] **Step 4: Correr los tests para verificar que pasan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart`
Expected: PASS — todos los tests del archivo (los existentes más los 6 nuevos)

- [ ] **Step 5: Correr toda la suite**

Run: `flutter test`
Expected: PASS — toda la suite

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/map/view_models/map_view_model.dart \
        test/ui/features/map/view_models/map_view_model_test.dart
git commit -m "feat: agregar MapViewModel.radioActivo/alternarRadio (busqueda por 3km)"
```

---

## Task 3: `RadiusToggleButton` y wiring en la `GlassBar`

**Files:**
- Create: `lib/ui/features/map/views/radius_toggle_button.dart`
- Test: `test/ui/features/map/views/radius_toggle_button_test.dart`
- Modify: `lib/ui/features/map/views/map_view.dart`

**Interfaces:**
- Consumes: `MapViewModel.radioActivo`, `MapViewModel.alternarRadio` (Task 2),
  `MapViewModel.tienePermisoDeUbicacion` (ya existente), `GlassBarAction` (ya existente,
  `lib/ui/core/glass_bar_action.dart`).
- Produces: `RadiusToggleButton({required MapViewModel viewModel})` — Task 4 lo ancla con una
  `GlobalKey` nueva para el paso del tour.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/ui/features/map/views/radius_toggle_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/domain/location_permission_status.dart';
import 'package:reciclai_mobile/ui/features/map/view_models/map_view_model.dart';
import 'package:reciclai_mobile/ui/features/map/views/radius_toggle_button.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<MapViewModel> _viewModelConPermiso(LocationPermissionStatus permiso) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(),
    locationService: LocationServiceFalsa(
      permiso: permiso,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  return viewModel;
}

void main() {
  testWidgets('con el radio inactivo muestra el icono sin relleno', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    expect(find.byIcon(Icons.social_distance_outlined), findsOneWidget);
    expect(find.byIcon(Icons.social_distance), findsNothing);
  });

  testWidgets('con el radio activo muestra el icono relleno', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await viewModel.alternarRadio(true);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    expect(find.byIcon(Icons.social_distance), findsOneWidget);
    expect(find.byIcon(Icons.social_distance_outlined), findsNothing);
  });

  testWidgets('tocarlo con permiso concedido activa el radio', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.concedido);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.social_distance_outlined));
    await tester.pumpAndSettle();

    expect(viewModel.radioActivo, isTrue);
  });

  testWidgets('sin permiso de ubicacion no responde al toque', (tester) async {
    final viewModel = await _viewModelConPermiso(LocationPermissionStatus.denegado);
    await tester.pumpWidget(_envolver(RadiusToggleButton(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.social_distance_outlined));
    await tester.pumpAndSettle();

    expect(viewModel.radioActivo, isFalse);
  });
}
```

- [ ] **Step 2: Correr los tests para verificar que fallan**

Run: `flutter test test/ui/features/map/views/radius_toggle_button_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/ui/features/map/views/radius_toggle_button.dart':
No such file or directory` (el archivo no existe todavía)

- [ ] **Step 3: Crear `RadiusToggleButton`**

Crear `lib/ui/features/map/views/radius_toggle_button.dart`:

```dart
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
      icon: activo ? Icons.social_distance : Icons.social_distance_outlined,
      color: activo ? Theme.of(context).colorScheme.secondary : null,
      onTap: viewModel.tienePermisoDeUbicacion ? () => viewModel.alternarRadio(!activo) : null,
    );
  }
}
```

- [ ] **Step 4: Correr los tests para verificar que pasan**

Run: `flutter test test/ui/features/map/views/radius_toggle_button_test.dart`
Expected: PASS — los 4 tests del archivo

- [ ] **Step 5: Conectarlo en `map_view.dart`**

En `lib/ui/features/map/views/map_view.dart`, agregar el import (junto a los de
`comuna_selector.dart`/`material_filter_button.dart`):

```dart
import 'radius_toggle_button.dart';
```

Agregar la `GlobalKey` nueva en `_MapViewState` (junto a `_keyComunaSelector`,
`_keyFiltroMateriales`, línea 63-65 hoy):

```dart
  final _keyRadioToggle = GlobalKey();
```

Agregar el widget dentro del `GlassBar` (línea 202-216 hoy), **antes** de `ComunaSelector` —
"cómo buscar" antes que "elige dónde", misma jerarquía que el propio switch le da a la comuna:

```dart
                      : GlassBar(
                          children: [
                            RadiusToggleButton(
                              key: _keyRadioToggle,
                              viewModel: widget.viewModel,
                            ),
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

- [ ] **Step 6: Correr toda la suite**

Run: `flutter test`
Expected: PASS — toda la suite (confirma que `map_view_test.dart` sigue pasando con el widget
nuevo en el árbol)

- [ ] **Step 7: Commit**

```bash
git add lib/ui/features/map/views/radius_toggle_button.dart \
        test/ui/features/map/views/radius_toggle_button_test.dart \
        lib/ui/features/map/views/map_view.dart
git commit -m "feat: agregar RadiusToggleButton a la barra del mapa"
```

---

## Task 4: Paso nuevo del tour

**Files:**
- Modify: `lib/ui/features/map/views/map_view.dart`
- Test: `test/ui/features/map/views/map_view_test.dart`

**Interfaces:**
- Consumes: `_keyRadioToggle` (Task 3), `TourStep` (ya existente, `lib/ui/features/tour/tour_step.dart`).
- Produces: nada que otra tarea consuma — es la última tarea del plan.

- [ ] **Step 1: Escribir el test que falla**

Agregar a `test/ui/features/map/views/map_view_test.dart`, junto a los demás tests del tour (busca
`'tocar el boton del tour abre el primer paso'` para ubicar el bloque).

El paso nuevo se inserta **después** de "Elige tu comuna" (ver Step 3). Sin permiso de ubicación,
el paso "Tu ubicación" se salta solo (comportamiento ya existente, ver el test
`'sin permiso de ubicacion, Siguiente salta el paso del boton de ubicacion'` en este mismo
archivo) — así que la secuencia real sin permiso es: "El mapa" → (salta "Tu ubicación") → "Elige
tu comuna" → "Busca por cercanía". Desde el primer paso hacen falta **dos** toques de "Siguiente"
para llegar al paso nuevo:

```dart
  testWidgets('el tour explica el switch de radio de 3km', (tester) async {
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
  });
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/ui/features/map/views/map_view_test.dart -N "explica el switch"`
Expected: FAIL — `find.text('Busca por cercanía')` no encuentra nada (`findsOneWidget` falla con
`findsNothing`), porque el paso todavía no existe en la lista

- [ ] **Step 3: Agregar el paso al tour**

En `lib/ui/features/map/views/map_view.dart`, insertar un `TourStep` nuevo en la lista `pasos`
(línea 91-114 hoy), **después** del paso `'Elige tu comuna'` y **antes** de `'Filtra por
material'`:

```dart
          TourStep(
            titulo: 'Elige tu comuna',
            cuerpo: 'O elige tu comuna aquí si prefieres buscar así.',
            anchorKey: _keyComunaSelector,
          ),
          TourStep(
            titulo: 'Busca por cercanía',
            cuerpo: 'Actívalo para ver los puntos a 3km a la redonda tuyo, sin importar la '
                'comuna — útil si vives cerca del límite entre dos comunas.',
            anchorKey: _keyRadioToggle,
          ),
          TourStep(
            titulo: 'Filtra por material',
            cuerpo: 'Filtra por el tipo de material que quieres reciclar.',
            anchorKey: _keyFiltroMateriales,
          ),
```

(el `TourStep` de "Elige tu comuna" y el de "Filtra por material" no cambian de contenido, solo se
agrega el nuevo entre ambos).

- [ ] **Step 4: Correr el test para verificar que pasa**

Run: `flutter test test/ui/features/map/views/map_view_test.dart -N "explica el switch"`
Expected: PASS

- [ ] **Step 5: Correr toda la suite**

Run: `flutter test`
Expected: PASS — toda la suite. Prestar atención especial a los tests existentes del tour que
navegan por índice/orden de pasos (ej. los que verifican qué texto aparece tras N toques de
"Siguiente" desde otro punto de partida) — si alguno asumía la posición exacta de "Filtra por
material" o de cualquier paso posterior al nuevo, su conteo de toques corre uno más ahora. Leer
la salida con atención antes de asumir que todo lo demás sigue igual.

- [ ] **Step 6: `flutter analyze`**

Run: `flutter analyze`
Expected: sin issues nuevos (los 2 `info` preexistentes en `map_view_model.dart` sobre
`prefer_initializing_formals` no son de esta tarea, no hace falta tocarlos)

- [ ] **Step 7: Commit**

```bash
git add lib/ui/features/map/views/map_view.dart test/ui/features/map/views/map_view_test.dart
git commit -m "feat: agregar paso del tour para el switch de radio de 3km"
```

## Verificación final

1. Suite completa en verde: `flutter test`
2. `flutter analyze` sin issues nuevos
3. Commit solo tras suite verde y confirmación explícita del usuario — mismo patrón de siempre en
   este proyecto.
4. Verificación visual en vivo (macOS o dispositivo real) del switch y del paso del tour antes de
   reportar la tarea como terminada — mismo patrón ya usado para el spinner y el video de intro
   esta sesión: correr la app, tocar el switch, confirmar que el mapa recarga con puntos
   distintos, y correr el tour hasta el paso nuevo para confirmar que el spotlight cae sobre el
   ícono correcto.
