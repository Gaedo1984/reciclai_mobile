# Búsqueda Ampliada Cuando el Filtro de Materiales No Encuentra Nada — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** cuando el filtro de materiales deja la vista sin ningún punto visible (en modo geolocalización, sin comuna elegida a mano), mostrar un botón sobre el mapa que busca en un radio de 15km alrededor de la posición actual, manteniendo el filtro de materiales aplicado.

**Architecture:** el backend ya expone `GET /points/nearby/radius?radio_metros=` (implementado, probado, desplegado — ver `docs/superpowers/plans/2026-10-09-radio-parametrizable.md` en `service-reciclai`). Este plan cablea ese endpoint desde mobile: `ReciclaiApiClient` gana el parámetro, `MapViewModel` gana un getter derivado (`mostrarBusquedaAmpliada`, recalculado en cada lectura — sin campo propio que sincronizar a mano) y un método de acción (`buscarEnRadioAmplio()`), y `map_view.dart` gana un widget overlay condicional más un paso de tour, siguiendo el mismo patrón ya usado para `_AvisoFueraDeRango` y para el botón "mi ubicación" (que ya se salta solo en el tour cuando no está montado).

**Tech Stack:** Flutter/Dart, `flutter_test`, patrones de testing ya establecidos en el proyecto (`ApiClientFalso`, `LocationServiceFalsa`, `_ClienteFalso` con `http.BaseClient`).

**Spec:** `docs/superpowers/specs/2026-10-09-busqueda-ampliada-sin-resultados-diseno.md`. El backend (sección "Backend — cambio mínimo") ya está hecho; este plan cubre "Alcance — cuándo aparece el botón", "Comportamiento al activarlo" y "Mobile — cambios".

## Global Constraints

- El botón aparece solo si las tres condiciones del spec se cumplen simultáneamente: `comunaSeleccionadaId == null`, `materialesSeleccionados.isNotEmpty`, y `filtrarPorMateriales(puntos, materialesSeleccionados)` vacío con `cuerpo` siendo `ConDatos`.
- El radio de búsqueda ampliada es **15000.0** metros, independiente del `radioActivo` de 3km ya existente (no comparten estado).
- Sin `radioMetros`, `ReciclaiApiClient.obtenerPuntosEnRadio` debe seguir comportándose exactamente igual que hoy (el radio de 3km ya existente no puede romperse).
- El filtro de materiales se sigue aplicando client-side (`filtrarPorMateriales`) sobre cualquier conjunto de puntos, incluido el resultado de la búsqueda ampliada — no se toca esa función.

## Review Focus

- Un fallo de red en `buscarEnRadioAmplio()` (backend caído/dormido) no debe tapar el mapa con una pantalla de error ni perder los puntos ya mostrados — debe degradar igual de silencioso que `_recargarPorMovimiento` ya hace para el mismo tipo de fallo.
- El botón debe desaparecer solo (sin que el usuario lo cierre a mano) en los tres casos del spec: se borra el filtro de materiales, se elige una comuna a mano, o la búsqueda ampliada ya trajo resultados — los tres son consecuencia natural de que `mostrarBusquedaAmpliada` es un getter derivado, pero cada uno necesita su propio test porque son tres condiciones distintas que podrían romperse por separado.
- Si `buscarEnRadioAmplio()` se llama sin ninguna posición conocida (ni `ultimaPosicionEnVivo` ni `miUbicacion` — caso de borde, ya que `mostrarBusquedaAmpliada` solo es `true` en modo geolocalización, que normalmente ya tiene una posición) no debe lanzar una excepción no capturada ni llamar al API con coordenadas nulas.
- Activar la búsqueda ampliada mientras el radio de 3km (`radioActivo`) ya está activo — el spec dice que son independientes; confirmar que no se pisan entre sí (activar una no cambia el estado de la otra).
- El botón del tour debe saltarse solo cuando no está montado (caso normal, ya que solo aparece condicionalmente) — igual que ya pasa con el botón "mi ubicación" sin permiso.

---

### Task 1: `ReciclaiApiClient.obtenerPuntosEnRadio` acepta `radioMetros` opcional

**Files:**
- Modify: `lib/data/reciclai_api_client.dart:80-97` (método `obtenerPuntosEnRadio`)
- Modify: `test/fakes.dart` (clase `ApiClientFalso`, método `obtenerPuntosEnRadio`)
- Test: `test/data/reciclai_api_client_test.dart`

**Interfaces:**
- Produces: `ReciclaiApiClient.obtenerPuntosEnRadio(double lat, double lng, {Duration? timeout, double? radioMetros})` — mismo tipo de retorno `Future<List<RecyclingPoint>>`. Si `radioMetros` es `null` (default), no se manda ningún query param `radio_metros` (el backend aplica su propio default de 3000m). `ApiClientFalso.obtenerPuntosEnRadio` gana el mismo parámetro y un campo nuevo `double? ultimoRadioMetrosPedido` (se actualiza en cada llamada con el valor recibido, `null` si no se pasó) — las Tasks 2 y 3 lo usan para verificar con qué radio se llamó.

El código actual del método (para referencia exacta):

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

El código actual del fake (`test/fakes.dart`, para referencia exacta):

```dart
@override
Future<List<RecyclingPoint>> obtenerPuntosEnRadio(
  double lat,
  double lng, {
  Duration? timeout,
}) async {
  vecesLlamadoObtenerPuntosEnRadio++;
  final porLlamada = resultadoEnRadioPorLlamada;
  if (porLlamada != null) return porLlamada(vecesLlamadoObtenerPuntosEnRadio);
  if (excepcion != null) throw excepcion!;
  return resultadoEnRadio;
}
```

- [ ] **Step 1: Escribir los tests que fallan**

Agregar a `test/data/reciclai_api_client_test.dart`, justo después del test existente `'obtenerPuntosEnRadio manda lat/lng como query y parsea la lista de puntos'` (línea ~177):

```dart
test('obtenerPuntosEnRadio sin radioMetros no manda el query param radio_metros', () async {
  final cliente = _ClienteFalso((request) {
    expect(request.url.queryParameters.containsKey('radio_metros'), isFalse);
    return _respuestaJson(200, <Object>[]);
  });
  final api = ReciclaiApiClient(client: cliente);

  await api.obtenerPuntosEnRadio(-33.50, -70.60);
});

test('obtenerPuntosEnRadio con radioMetros lo manda en la query', () async {
  final cliente = _ClienteFalso((request) {
    expect(request.url.queryParameters['radio_metros'], '15000.0');
    return _respuestaJson(200, <Object>[]);
  });
  final api = ReciclaiApiClient(client: cliente);

  await api.obtenerPuntosEnRadio(-33.50, -70.60, radioMetros: 15000);
});
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

Run: `flutter test test/data/reciclai_api_client_test.dart --plain-name "radioMetros"`

Expected: el primer test (`sin radioMetros...`) PASA (el comportamiento actual ya es ese). El segundo (`con radioMetros...`) FALLA porque `obtenerPuntosEnRadio` no acepta el parámetro `radioMetros` todavía — error de compilación (`no named parameter`), no una falla de aserción.

- [ ] **Step 3: Agregar el parámetro al método real**

En `lib/data/reciclai_api_client.dart`, reemplazar el método completo:

```dart
Future<List<RecyclingPoint>> obtenerPuntosEnRadio(
  double lat,
  double lng, {
  Duration? timeout,
  double? radioMetros,
}) async {
  final cuerpo = await _get(
    '/points/nearby/radius',
    queryParameters: {
      'lat': '$lat',
      'lng': '$lng',
      if (radioMetros != null) 'radio_metros': '$radioMetros',
    },
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

- [ ] **Step 4: Correr los tests y confirmar que pasan**

Run: `flutter test test/data/reciclai_api_client_test.dart --plain-name "radioMetros"`

Expected: ambos tests PASAN.

- [ ] **Step 5: Actualizar el fake para que compile y para trackear el radio pedido**

En `test/fakes.dart`, dentro de la clase `ApiClientFalso`, agregar el campo nuevo junto a los demás contadores (cerca de `vecesLlamadoObtenerPuntosEnRadio`):

```dart
/// Ultimo `radioMetros` recibido por `obtenerPuntosEnRadio` -- `null` si la
/// ultima llamada no lo paso. Usado para verificar con que radio se llamo
/// (ej. la busqueda ampliada de 15000m).
double? ultimoRadioMetrosPedido;
```

Y reemplazar el método:

```dart
@override
Future<List<RecyclingPoint>> obtenerPuntosEnRadio(
  double lat,
  double lng, {
  Duration? timeout,
  double? radioMetros,
}) async {
  vecesLlamadoObtenerPuntosEnRadio++;
  ultimoRadioMetrosPedido = radioMetros;
  final porLlamada = resultadoEnRadioPorLlamada;
  if (porLlamada != null) return porLlamada(vecesLlamadoObtenerPuntosEnRadio);
  if (excepcion != null) throw excepcion!;
  return resultadoEnRadio;
}
```

- [ ] **Step 6: Correr la suite completa y confirmar que nada se rompió**

Run: `flutter test`

Expected: todos los tests PASAN (el fake sigue implementando `ReciclaiApiClient` correctamente; ningún llamador existente pasa `radioMetros`, así que nada cambia para ellos).

- [ ] **Step 7: Commit**

```bash
git add lib/data/reciclai_api_client.dart test/fakes.dart test/data/reciclai_api_client_test.dart
git commit -m "feat: ReciclaiApiClient.obtenerPuntosEnRadio acepta radioMetros opcional

Sin el parametro, el comportamiento es identico al actual (el backend
aplica su default de 3000m). Prepara el terreno para la busqueda ampliada
de 15km cuando el filtro de materiales no encuentra nada cerca."
```

---

### Task 2: `MapViewModel` — detectar y actuar la búsqueda ampliada

**Files:**
- Modify: `lib/ui/features/map/view_models/map_view_model.dart`
- Test: `test/ui/features/map/view_models/map_view_model_test.dart`

**Interfaces:**
- Consumes: `ReciclaiApiClient.obtenerPuntosEnRadio(double, double, {Duration? timeout, double? radioMetros})` (Task 1). `filtrarPorMateriales(List<RecyclingPoint>, Set<String>)` de `lib/domain/filtro_material.dart` (ya existe, sin cambios — importar en `map_view_model.dart` si no está importado ya).
- Produces: `MapViewModel.mostrarBusquedaAmpliada` (getter, `bool`, derivado — no agrega ningún campo de estado nuevo que requiera sincronización manual) y `MapViewModel.buscarEnRadioAmplio()` (`Future<void>`, sin parámetros). La Task 3 consume ambos exactamente con estos nombres y firmas.

El `MapViewModel` actual ya tiene (sin cambios en esta tarea, solo para referencia de qué hay disponible): `_comunaSeleccionadaId` / `comunaSeleccionadaId` (getter), `_materialesSeleccionados` / `materialesSeleccionados` (getter), `_cuerpo` / `cuerpo` (getter, tipo `CuerpoMapaState`, con variante `ConDatos(List<RecyclingPoint> puntos)`), `_ultimaPosicionEnVivo` / `ultimaPosicionEnVivo` (getter, `LatLng?`), `_miUbicacion` (privado, sin getter público directo — `miUbicacion` getter devuelve `null` si hay comuna elegida, pero como `mostrarBusquedaAmpliada` ya exige `comunaSeleccionadaId == null`, usar el getter público `miUbicacion` es seguro y correcto acá), `_aplicarCuerpo(int, CuerpoMapaState)` (privado, descarta resultados tardíos de operaciones reemplazadas), `_operacionDeCuerpo` (contador de operaciones).

- [ ] **Step 1: Escribir los tests que fallan — getter `mostrarBusquedaAmpliada`**

Agregar un nuevo `group` al final de `test/ui/features/map/view_models/map_view_model_test.dart`, antes del `}` de cierre de `main()`:

```dart
group('busqueda ampliada cuando el filtro de materiales no encuentra nada', () {
  RecyclingPoint puntoConMaterial(String id, String material) {
    return RecyclingPoint(
      id: id,
      nombre: 'Punto $id',
      direccion: 'Direccion $id',
      ubicacion: const LatLng(-33.52, -70.60),
      tipo: 'punto_limpio',
      materiales: [material],
      horario: null,
      esEmpresa: false,
      sitioWeb: null,
      confianza: 'media',
    );
  }

  test('no aparece sin ningun material seleccionado', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();

    expect(viewModel.mostrarBusquedaAmpliada, isFalse);
  });

  test('no aparece si el filtro de materiales si encuentra puntos', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    viewModel.aplicarFiltroMateriales({'plastico'});

    expect(viewModel.mostrarBusquedaAmpliada, isFalse);
  });

  test('no aparece con una comuna elegida a mano, aunque el filtro de cero', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(
        comunas: [_laFlorida],
        puntosPorComuna: [puntoConMaterial('1', 'plastico')],
      ),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );
    await viewModel.iniciar();
    await viewModel.seleccionarComuna('la-florida');
    viewModel.aplicarFiltroMateriales({'vidrio'});

    expect(viewModel.mostrarBusquedaAmpliada, isFalse);
  });

  test('aparece en modo geolocalizacion con filtro activo y cero resultados', () async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')])),
      locationService: LocationServiceFalsa(
        permiso: LocationPermissionStatus.concedido,
        posicion: posicionDePrueba(),
      ),
    );
    await viewModel.iniciar();
    viewModel.aplicarFiltroMateriales({'vidrio'});

    expect(viewModel.mostrarBusquedaAmpliada, isTrue);
  });
});
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart --plain-name "busqueda ampliada"`

Expected: error de compilación — `mostrarBusquedaAmpliada` no existe en `MapViewModel`.

- [ ] **Step 3: Implementar el getter**

En `lib/ui/features/map/view_models/map_view_model.dart`, agregar el import de `filtrarPorMateriales` si no está (revisar los imports existentes al inicio del archivo — hoy no importa `filtro_material.dart`, agregar `import '../../../../domain/filtro_material.dart';`), y agregar el getter nuevo justo después de `aplicarFiltroMateriales` (línea ~78):

```dart
/// Radio de la busqueda ampliada cuando el filtro de materiales no
/// encuentra nada en modo geolocalizacion -- independiente del
/// `radioActivo` de 3km, que es un origen de datos distinto.
static const _radioMetrosAmpliado = 15000.0;

/// Derivado, no un campo propio -- se recalcula en cada lectura a partir
/// del estado ya existente, asi que no hay nada que sincronizar a mano ni
/// que se pueda desincronizar. Verdadero solo en modo geolocalizacion
/// (`comunaSeleccionadaId == null`), con al menos un material filtrado,
/// y cuando ese filtro deja la vista actual sin ningun punto.
bool get mostrarBusquedaAmpliada {
  if (_comunaSeleccionadaId != null) return false;
  if (_materialesSeleccionados.isEmpty) return false;
  final cuerpoActual = _cuerpo;
  if (cuerpoActual is! ConDatos) return false;
  return filtrarPorMateriales(cuerpoActual.puntos, _materialesSeleccionados).isEmpty;
}
```

- [ ] **Step 4: Correr los tests y confirmar que pasan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart --plain-name "busqueda ampliada"`

Expected: los 4 tests PASAN.

- [ ] **Step 5: Escribir los tests que fallan — `buscarEnRadioAmplio()`**

Agregar al mismo `group`, después del último test del Step 1:

```dart
test('buscarEnRadioAmplio pide el radio de 15km alrededor de la ultima posicion conocida',
    () async {
  final apiClient = ApiClientFalso(
    resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
    resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
  );
  final viewModel = MapViewModel(
    apiClient: apiClient,
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(latitude: -33.50, longitude: -70.60),
    ),
  );
  await viewModel.iniciar();
  viewModel.aplicarFiltroMateriales({'vidrio'});
  expect(viewModel.mostrarBusquedaAmpliada, isTrue);

  await viewModel.buscarEnRadioAmplio();

  expect(apiClient.ultimoRadioMetrosPedido, 15000.0);
  expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
});

test('despues de buscarEnRadioAmplio con resultados, mostrarBusquedaAmpliada pasa a falso',
    () async {
  final apiClient = ApiClientFalso(
    resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
    resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
  );
  final viewModel = MapViewModel(
    apiClient: apiClient,
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  viewModel.aplicarFiltroMateriales({'vidrio'});

  await viewModel.buscarEnRadioAmplio();

  expect(viewModel.mostrarBusquedaAmpliada, isFalse);
});

test('buscarEnRadioAmplio mantiene el filtro de materiales sobre el resultado ampliado',
    () async {
  final apiClient = ApiClientFalso(
    resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
    resultadoEnRadio: [puntoConMaterial('2', 'vidrio'), puntoConMaterial('3', 'plastico')],
  );
  final viewModel = MapViewModel(
    apiClient: apiClient,
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  viewModel.aplicarFiltroMateriales({'vidrio'});

  await viewModel.buscarEnRadioAmplio();

  final puntosFiltrados =
      filtrarPorMateriales((viewModel.cuerpo as ConDatos).puntos, viewModel.materialesSeleccionados);
  expect(puntosFiltrados.map((p) => p.id), ['2']);
});

test('si buscarEnRadioAmplio falla, se mantienen los puntos anteriores sin mostrar error',
    () async {
  final apiClient = ApiClientFalso(
    resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
    resultadoEnRadioPorLlamada: (_) => throw const ReciclaiApiException('sin señal'),
  );
  final viewModel = MapViewModel(
    apiClient: apiClient,
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  viewModel.aplicarFiltroMateriales({'vidrio'});

  await viewModel.buscarEnRadioAmplio();

  expect(viewModel.cuerpo, isA<ConDatos>());
  expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['1']);
  expect(viewModel.mostrarBusquedaAmpliada, isTrue);
});

test('activar el radio de 3km no interfiere con la busqueda ampliada ni viceversa', () async {
  final apiClient = ApiClientFalso(
    resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
    resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
  );
  final viewModel = MapViewModel(
    apiClient: apiClient,
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await viewModel.iniciar();
  viewModel.aplicarFiltroMateriales({'vidrio'});

  await viewModel.buscarEnRadioAmplio();

  expect(viewModel.radioActivo, isFalse);
});

test('buscarEnRadioAmplio funciona igual con el radio de 3km ya activo de antes', () async {
  final apiClient = ApiClientFalso(
    resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]),
    resultadoEnRadio: [puntoConMaterial('2', 'vidrio')],
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
  viewModel.aplicarFiltroMateriales({'vidrio'});
  expect(viewModel.mostrarBusquedaAmpliada, isTrue);

  await viewModel.buscarEnRadioAmplio();

  expect(apiClient.ultimoRadioMetrosPedido, 15000.0);
  expect((viewModel.cuerpo as ConDatos).puntos.map((p) => p.id), ['2']);
  expect(viewModel.radioActivo, isTrue);
});

test('buscarEnRadioAmplio sin ninguna posicion conocida no falla ni llama al API', () async {
  final apiClient = ApiClientFalso(resultadoCercanos: Covered([puntoConMaterial('1', 'plastico')]));
  final viewModel = MapViewModel(
    apiClient: apiClient,
    // Permiso denegado -- nunca se geolocaliza, asi que ni `miUbicacion` ni
    // `ultimaPosicionEnVivo` llegan a tener un valor. Caso de borde: en la
    // practica `mostrarBusquedaAmpliada` nunca es verdadero sin posicion
    // conocida (ver doc del metodo), pero el guard debe sostenerse igual si
    // algo mas adelante llama a este metodo directamente.
    locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
  );
  await viewModel.iniciar();

  await viewModel.buscarEnRadioAmplio();

  expect(apiClient.vecesLlamadoObtenerPuntosEnRadio, 0);
});
```

- [ ] **Step 6: Correr los tests y confirmar que fallan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart --plain-name "busqueda ampliada"`

Expected: error de compilación — `buscarEnRadioAmplio` no existe en `MapViewModel`.

- [ ] **Step 7: Implementar `buscarEnRadioAmplio()`**

Agregar el método justo después de `_obtenerCuerpoParaPosicion` (línea ~281, antes de `_alMoverse`):

```dart
/// Busca puntos en un radio amplio (15km) alrededor de la ultima posicion
/// conocida, para cuando el filtro de materiales no encuentra nada en el
/// modo normal (comuna geolocalizada o radio de 3km). Independiente de
/// `radioActivo` -- no lo lee ni lo modifica. Igual que
/// `_recargarPorMovimiento`, un fallo de red se ignora en silencio: se
/// mantienen los puntos que ya habia (y por lo tanto `mostrarBusquedaAmpliada`
/// sigue en true, el usuario puede volver a intentar tocando el boton de
/// nuevo).
Future<void> buscarEnRadioAmplio() async {
  final posicion = _ultimaPosicionEnVivo ?? miUbicacion;
  if (posicion == null) return;
  final miOperacion = ++_operacionDeCuerpo;
  try {
    final puntos = await _apiClient.obtenerPuntosEnRadio(
      posicion.latitude,
      posicion.longitude,
      radioMetros: _radioMetrosAmpliado,
    );
    _aplicarCuerpo(miOperacion, ConDatos(puntos));
  } on ReciclaiApiException {
    // Fallo silencioso -- ver doc del metodo.
  }
}
```

- [ ] **Step 8: Correr los tests y confirmar que pasan**

Run: `flutter test test/ui/features/map/view_models/map_view_model_test.dart --plain-name "busqueda ampliada"`

Expected: los 11 tests del grupo (4 del getter + 7 de `buscarEnRadioAmplio`) PASAN.

- [ ] **Step 9: Correr la suite completa**

Run: `flutter test`

Expected: todos los tests PASAN.

- [ ] **Step 10: Commit**

```bash
git add lib/ui/features/map/view_models/map_view_model.dart test/ui/features/map/view_models/map_view_model_test.dart
git commit -m "feat: MapViewModel detecta y actua la busqueda ampliada de 15km

mostrarBusquedaAmpliada es un getter derivado (sin campo propio) que es
verdadero solo en modo geolocalizacion, con filtro de materiales activo, y
cuando ese filtro deja la vista sin ningun punto. buscarEnRadioAmplio()
pide el radio de 15km alrededor de la ultima posicion conocida y reemplaza
los puntos mostrados -- el filtro de materiales se sigue aplicando sobre
el resultado. Un fallo de red se ignora en silencio, igual que la recarga
en segundo plano al moverse."
```

---

### Task 3: Botón en el mapa + paso del tour

**Files:**
- Modify: `lib/ui/features/map/views/map_view.dart`
- Test: `test/ui/features/map/views/map_view_test.dart`

**Interfaces:**
- Consumes: `MapViewModel.mostrarBusquedaAmpliada` (getter, Task 2) y `MapViewModel.buscarEnRadioAmplio()` (método, Task 2).
- Produces: nada que otra tarea de este plan consuma (es la última tarea).

Contexto necesario de `map_view.dart` (no copiar de nuevo, son las líneas ya existentes que esta tarea toca o referencia):

- El `Stack` del `body` (línea ~223) ya tiene como hijos: `Positioned.fill` con el contenido principal, el spinner de "Cargando" superpuesto condicional, y un `Positioned` (línea ~238, `left/right: espacioMd`, `bottom: espacioLg + MediaQuery.of(context).padding.bottom`) que muestra `_AvisoFueraDeRango` o la `GlassBar` con los botones existentes.
- `_AvisoFueraDeRango` (línea ~533) es el patrón visual de referencia: `ClipRRect` + `BackdropFilter` con blur + `Container` con `color: colores.surface.withValues(alpha: 0.55)`, `borderRadius: BorderRadius.circular(radioDeHojaFlotante)`, `border: Border.all(color: Colors.white.withValues(alpha: 0.3))`, conteniendo un `Row`.
- `_iniciarTour()` (línea ~96) arma la lista de `TourStep` que recibe `TourOverlay`. Un paso con `anchorKey` que no está montado (`key.currentContext == null`) se salta solo al tocar "Siguiente" — mecanismo ya usado por el paso "Tu ubicación" (`anchorKey: _keyMiUbicacion`), que se salta cuando no hay permiso de ubicación (ver test `'sin permiso de ubicacion, Siguiente salta el paso del boton de ubicacion'` en `test/ui/features/map/views/map_view_test.dart`).
- Las keys existentes (`_keyMiUbicacion`, `_keyComunaSelector`, `_keyFiltroMateriales`, `_keyRadioToggle`) están declaradas como campos de `_MapViewState` (línea ~71-74).
- `espacioMd = 16.0`, `espacioSm = 8.0`, `espacioLg = 24.0` (`lib/ui/core/spacing.dart`). `radioDeHojaFlotante = 20.0` (`lib/ui/core/floating_sheet_card.dart`, ya importado en `map_view.dart`).

- [ ] **Step 1: Escribir los tests que fallan**

Agregar a `test/ui/features/map/views/map_view_test.dart`, cerca de los demás tests de `_AvisoFueraDeRango`/overlays condicionales (buscar un lugar cerca de tests similares, o al final de los tests de geolocalización):

```dart
testWidgets('con filtro de materiales sin resultados, aparece el boton de busqueda ampliada',
    (tester) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
  );
  await tester.pumpAndSettle();

  viewModel.aplicarFiltroMateriales({'material-sin-puntos'});
  await tester.pump();

  expect(find.text('Buscar en 15 km'), findsOneWidget);
});

testWidgets('sin filtro de materiales, no aparece el boton de busqueda ampliada', (tester) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
  );
  await tester.pumpAndSettle();

  expect(find.text('Buscar en 15 km'), findsNothing);
});

testWidgets('tocar el boton de busqueda ampliada pide el radio de 15km y lo hace desaparecer',
    (tester) async {
  final apiClient = ApiClientFalso(
    resultadoCercanos: Covered([_punto()]),
    resultadoEnRadio: [_punto()],
  );
  final viewModel = MapViewModel(
    apiClient: apiClient,
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
  );
  await tester.pumpAndSettle();
  viewModel.aplicarFiltroMateriales({'material-sin-puntos'});
  await tester.pump();
  expect(find.text('Buscar en 15 km'), findsOneWidget);

  await tester.tap(find.text('Buscar en 15 km'));
  await tester.pumpAndSettle();

  expect(apiClient.ultimoRadioMetrosPedido, 15000.0);
  expect(find.text('Buscar en 15 km'), findsNothing);
});

testWidgets('el tour explica el boton de busqueda ampliada cuando esta visible', (tester) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
  );
  await tester.pumpAndSettle();
  viewModel.aplicarFiltroMateriales({'material-sin-puntos'});
  await tester.pump();

  await tester.tap(find.byKey(const Key('tour-trigger-button')));
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.tap(find.byKey(const Key('tour-siguiente')));
    await tester.pump();
  }

  expect(find.text('Busca más lejos'), findsOneWidget);
});

testWidgets(
    'el tour se salta el paso de busqueda ampliada cuando no esta visible (caso normal)',
    (tester) async {
  final viewModel = MapViewModel(
    apiClient: ApiClientFalso(resultadoCercanos: Covered([_punto()])),
    locationService: LocationServiceFalsa(
      permiso: LocationPermissionStatus.concedido,
      posicion: posicionDePrueba(),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('tour-trigger-button')));
  await tester.pump();

  expect(find.text('Busca más lejos'), findsNothing);
});
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

Run: `flutter test test/ui/features/map/views/map_view_test.dart --plain-name "busqueda ampliada"`

Expected: FALLA — `find.text('Buscar en 15 km')` no encuentra nada en ningún escenario, porque el widget todavía no existe.

- [ ] **Step 3: Agregar la key y el widget nuevo**

En `lib/ui/features/map/views/map_view.dart`, agregar la key nueva junto a las demás (cerca de la línea 71-74, dentro de `_MapViewState`):

```dart
final _keyBusquedaAmpliada = GlobalKey();
```

Agregar el widget nuevo al final del archivo, después de la clase `_AvisoFueraDeRango` (después de la línea ~562):

```dart
class _AvisoBusquedaAmpliada extends StatefulWidget {
  const _AvisoBusquedaAmpliada({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  State<_AvisoBusquedaAmpliada> createState() => _AvisoBusquedaAmpliadaState();
}

class _AvisoBusquedaAmpliadaState extends State<_AvisoBusquedaAmpliada> {
  bool _buscando = false;

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    await widget.viewModel.buscarEnRadioAmplio();
    if (mounted) setState(() => _buscando = false);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radioDeHojaFlotante),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: espacioMd, vertical: 10),
          decoration: BoxDecoration(
            color: colores.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radioDeHojaFlotante),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(child: Text('Sin puntos con este filtro cerca de ti.')),
              const SizedBox(width: espacioSm),
              _buscando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(onPressed: _buscar, child: const Text('Buscar en 15 km')),
            ],
          ),
        ),
      ),
    );
  }
}
```

(`ImageFilter` ya está importado en este archivo porque `_AvisoFueraDeRango` ya lo usa — no hace falta agregar ningún import nuevo.)

- [ ] **Step 4: Cablear el widget al Stack**

En el `Stack` del `body` (dentro del `builder` de `ListenableBuilder`, después del `Positioned` del spinner de "Cargando" y antes del `Positioned` de la `GlassBar`/`_AvisoFueraDeRango`, alrededor de la línea 237), agregar:

```dart
if (widget.viewModel.mostrarBusquedaAmpliada)
  Positioned(
    left: espacioMd,
    right: espacioMd,
    bottom: espacioLg + MediaQuery.of(context).padding.bottom + 72,
    child: Center(
      child: _AvisoBusquedaAmpliada(
        key: _keyBusquedaAmpliada,
        viewModel: widget.viewModel,
      ),
    ),
  ),
```

(El offset `+ 72` lo separa verticalmente de la `GlassBar`, que ocupa esa misma franja inferior — revisar visualmente en un dispositivo real una vez implementado y ajustar ese número si se superponen o queda muy separado; no es un valor que un test pueda verificar de forma significativa.)

- [ ] **Step 5: Correr los tests de presencia/ausencia/tap y confirmar que pasan**

Run: `flutter test test/ui/features/map/views/map_view_test.dart --plain-name "busqueda ampliada"`

Expected: los primeros 3 tests (aparece con filtro sin resultados / no aparece sin filtro / tocar pide 15km y desaparece) PASAN. Los 2 tests de tour todavía FALLAN (el paso nuevo no existe en `_iniciarTour` todavía).

- [ ] **Step 6: Agregar el paso al tour**

En `_iniciarTour()` (línea ~96), agregar un `TourStep` nuevo a la lista `pasos`, después del paso `'Filtra por material'` (línea ~128-132) y antes del paso final `'Detalle de un punto'`:

```dart
TourStep(
  titulo: 'Busca más lejos',
  cuerpo: 'Si el filtro de materiales no encuentra nada cerca, aparece este botón para '
      'buscar en un radio de 15 km.',
  anchorKey: _keyBusquedaAmpliada,
),
```

- [ ] **Step 7: Correr los tests del tour y confirmar que pasan**

Run: `flutter test test/ui/features/map/views/map_view_test.dart --plain-name "busqueda ampliada"`

Expected: los 5 tests PASAN.

- [ ] **Step 8: Correr la suite completa**

Run: `flutter test`

Expected: todos los tests PASAN. Revisar en particular que los tests de tour ya existentes (los que cuentan la cantidad de pasos o navegan "Siguiente" varias veces, ej. `'tocar el boton del tour abre el primer paso'`) sigan pasando — si alguno cuenta pasos de forma fija y se rompe por el paso nuevo, ajustarlo (es un test ya existente que asume una cantidad de pasos, no una regla nueva de este plan).

- [ ] **Step 9: `flutter analyze` limpio**

Run: `flutter analyze`

Expected: sin issues nuevos (los 2 `info` de `prefer_initializing_formals` ya existentes en `map_view_model.dart` son preexistentes y no se tocan en este plan).

- [ ] **Step 10: Commit**

```bash
git add lib/ui/features/map/views/map_view.dart test/ui/features/map/views/map_view_test.dart
git commit -m "feat: boton de busqueda ampliada de 15km sobre el mapa + paso del tour

Aparece como overlay condicional (mismo patron que _AvisoFueraDeRango)
cuando el filtro de materiales no encuentra nada en modo geolocalizacion.
El paso nuevo del tour se salta solo cuando el boton no esta montado,
igual que ya pasa con el paso del boton 'mi ubicacion' sin permiso."
```

## Completion

Tras las 3 tareas, la funcionalidad completa del spec está implementada: el botón aparece/desaparece según las condiciones exactas, busca en 15km manteniendo el filtro de materiales, y el tour lo explica. El build de verificación en un dispositivo real (APK/AAB) y el push a `origin/main` se coordinan con el usuario al final, como el resto de features de esta sesión — no son parte de las tareas de este plan.
