# Búsqueda por radio de 3km — Diseño

**Contexto:** hoy la app solo busca puntos de reciclaje "por comuna": ya sea automáticamente (la
geolocalización cae dentro de una comuna y se listan sus puntos) o eligiendo una comuna a mano.
Quien vive cerca del límite entre dos comunas puede tener puntos más cercanos en la comuna vecina
que nunca ve, porque la búsqueda está atada a límites administrativos, no a distancia real. Este
spec agrega un modo alternativo — "3km a la redonda de mi ubicación" — como un switch en la barra
inferior, que reemplaza la búsqueda por comuna sin tocar el resto de la app.

**Repos afectados:** este spec cruza los dos repos del proyecto:
- `service-reciclai` (backend FastAPI + PostGIS) — un endpoint nuevo.
- `reciclai_mobile` (Flutter) — el switch, el estado en `MapViewModel`, y un paso nuevo del tour.

Como `writing-plans`/`executing-plans` operan sobre un repo a la vez, este spec se implementa en
**dos planes separados** (backend primero, mobile después) — ver sección 5.

**Fuera de alcance de este spec:**
- Radio configurable por el usuario (ej. elegir 1km/3km/5km) — se pidió explícitamente 3km fijo,
  no una preferencia. Si más adelante se quiere configurable, es un spec aparte.
- Que el switch se acuerde entre aperturas de la app (persistencia en disco) — arranca desactivado
  cada vez, igual que el resto del estado de `MapViewModel` hoy.
- Aplicar radio de 3km a la selección manual de comuna — el switch solo tiene sentido combinado
  con "mi ubicación actual", igual que hoy `miUbicacion` deja de aplicar en cuanto se elige una
  comuna a mano (`MapViewModel.miUbicacion`, `map_view_model.dart:66-67`).
- Cualquier cambio a los filtros de material — ya se aplican del lado de la app
  (`filtrarPorMateriales`) sobre lo que sea que haya en `cuerpo`, sin importar cómo se obtuvo.
  Funcionan igual sin tocarlos.

## 1. Backend — nuevo endpoint `/points/nearby/radius`

**Motivación de diseño:** la infraestructura PostGIS para esta consulta ya existe y está probada
en producción — `PostgisRepository._buscar_similar` (`repository.py:179-192`) ya hace exactamente
este tipo de consulta (`ST_DWithin` sobre `cast(ubicacion, Geography)`) para el dedup de
ingesta, usando el índice geográfico dedicado (`ix_recycling_point_ubicacion_geog`, definido en
la migración `0001_tablas_iniciales.py`). No hace falta ninguna migración ni índice nuevo.

### 1.1 Puerto (`src/reciclai/application/ports/outbound.py`)

`RecyclingPointQueryPort` gana un método nuevo, junto al `por_comuna` existente (línea 109-112):

```python
class RecyclingPointQueryPort(Protocol):
    async def por_comuna(self, comuna_id: str) -> tuple[RecyclingPoint, ...]:
        """Puntos activos de una comuna. Tupla vacía si la comuna existe pero no tiene puntos."""
        ...

    async def por_radio(
        self, centro: Coordenada, radio_metros: float
    ) -> tuple[RecyclingPoint, ...]:
        """Puntos activos a `radio_metros` o menos de `centro`, sin importar su comuna. Tupla
        vacía si no hay ninguno — resultado de negocio válido, no un error."""
        ...
```

### 1.2 Implementación (`src/reciclai/infrastructure/outbound/postgis/recycling_point_query.py`)

Nuevo método en `PostgisRecyclingPointQuery`, mismo patrón de `por_comuna` (reusa
`_a_dominio`), pero sin filtrar por `comuna_id` y con la condición `ST_DWithin` en vez de
`comuna_id == comuna_id`:

```python
async def por_radio(
    self, centro: Coordenada, radio_metros: float
) -> tuple[RecyclingPoint, ...]:
    centro_wkt = f"POINT({centro.longitud} {centro.latitud})"
    stmt = (
        select(
            RecyclingPointModel,
            ST_X(RecyclingPointModel.ubicacion),
            ST_Y(RecyclingPointModel.ubicacion),
        )
        .where(
            RecyclingPointModel.activo.is_(True),
            ST_DWithin(
                cast(RecyclingPointModel.ubicacion, Geography),
                cast(ST_GeomFromText(centro_wkt, 4326), Geography),
                radio_metros,
            ),
        )
        .options(selectinload(RecyclingPointModel.materiales))
        .order_by(RecyclingPointModel.nombre)
    )
    resultado = await self._session.execute(stmt)
    puntos = []
    for modelo, lng, lat in resultado.all():
        coordenada = Coordenada(latitud=lat, longitud=lng)
        puntos.append(self._a_dominio(modelo, coordenada))
    return tuple(puntos)
```

Requiere agregar los imports que `repository.py` ya usa para este mismo patrón: `ST_DWithin`,
`ST_GeomFromText` de `geoalchemy2.functions`, `Geography` de `geoalchemy2`, y `cast` de
`sqlalchemy`.

### 1.3 Endpoint (`src/reciclai/infrastructure/inbound/http/routers/points.py`)

```python
RADIO_CERCANIA_METROS = 3000

@router.get("/nearby/radius", response_model=list[RecyclingPointSchema])
async def puntos_en_radio(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    consulta_puntos: RecyclingPointQueryPort = Depends(get_recycling_point_query),
) -> list[RecyclingPointSchema]:
    coordenada = Coordenada(latitud=lat, longitud=lng)
    puntos = await consulta_puntos.por_radio(coordenada, RADIO_CERCANIA_METROS)
    return [recycling_point_schema(p) for p in puntos]
```

Nótese la diferencia de forma con `/points/nearby`: ese endpoint devuelve
`list[RecyclingPointSchema] | NoCoberturaSchema` porque existe el concepto de "coordenada fuera de
cualquier comuna cubierta". Acá no — cualquier coordenada es válida para buscar alrededor, así que
la respuesta es siempre una lista (posiblemente vacía). No se reutiliza `NoCoberturaSchema`.

`RADIO_CERCANIA_METROS` es una constante del módulo, no un parámetro de query — igual que
`DEDUP_RADIO_METROS` en `repository.py`, no se expone como configurable porque nadie lo pidió así
(ver "Fuera de alcance").

El endpoint hereda el `require_api_key` del router (`points.py:19`), igual que los otros dos.

### 1.4 Tests

`tests/infrastructure/outbound/postgis/test_recycling_point_query.py` (si no existe, crear junto a
los tests existentes de este archivo — revisar convención real al implementar): casos con puntos
dentro del radio, puntos justo fuera del radio (no deben volver), puntos de comunas distintas
dentro del radio (deben volver — es el caso que resuelve el borde entre comunas), y radio sin
ningún punto (tupla vacía, no error).

`tests/infrastructure/inbound/http/test_points_router.py` (o donde vivan los tests de este
router): caso feliz con puntos, caso sin puntos (lista vacía, no 404), y que requiere API key.

## 2. Mobile — modelo de datos y cliente API

### 2.1 Cliente (`lib/data/reciclai_api_client.dart`)

Nuevo método, análogo a `obtenerPuntosPorComuna` — no reutiliza `PointsNearbyResult` (que existe
para el caso `Covered`/`NotCovered`, que no aplica acá) sino que devuelve `List<RecyclingPoint>`
directo, igual que `obtenerPuntosPorComuna`:

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

El parámetro `timeout` opcional ya existe en `_get` (agregado esta sesión para los reintentos de
apertura) — se reutiliza tal cual, sin cambios a `_get`.

### 2.2 Fake de test (`test/fakes.dart`)

`ApiClientFalso` gana los campos y el método equivalentes a los que ya tiene para
`obtenerPuntosCercanos` (`resultadoRadio`, `excepcion` compartida, contador
`vecesLlamadoObtenerPuntosEnRadio`), mismo patrón que el resto de la clase.

## 3. Mobile — estado en `MapViewModel`

### 3.1 Campo nuevo

```dart
bool _radioActivo = false;
bool get radioActivo => _radioActivo;
```

Arranca en `false` (comportamiento actual, sin cambios, cada vez que se abre la app — ver "Fuera
de alcance").

### 3.2 `alternarRadio()` — el método que dispara el switch

Simétrico con `seleccionarComuna` (3.4): activar el radio limpia cualquier comuna elegida a mano y
vuelve a buscar desde la ubicación actual real (no la última conocida — `_cargarPorGeolocalizacion`
pide una posición fresca vía `_locationService.obtenerPosicionActual()`). Este es el caso que
preguntaste: comuna elegida → activas el switch → se limpia la comuna, se geolocaliza de nuevo, se
busca en 3km alrededor de dónde estás parado ahora.

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

Reutiliza el método existente `_cargarPorGeolocalizacion` (líneas 148-179 hoy) — ver 3.3 para el
cambio ahí.

### 3.3 `_cargarPorGeolocalizacion` elige el endpoint según `_radioActivo`

El método hoy siempre llama `_apiClient.obtenerPuntosCercanos(...)`. Pasa a bifurcar:

```dart
Future<void> _cargarPorGeolocalizacion(int miOperacion) async {
  // ... (igual hasta obtener `posicion` y chequear `estaEnChile`, sin cambios)

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

Los 3 reintentos automáticos de 20s (agregados esta sesión para el despertar de Render) aplican
igual a ambos modos — mismo motivo: es la apertura del mapa por geolocalización, sin importar qué
endpoint use.

`NotCovered` no tiene equivalente en modo radio (la sección 1.3 del backend explica por qué) — el
branch de radio nunca puede caer en "sin cobertura".

### 3.4 Elegir una comuna a mano desactiva el radio

`seleccionarComuna` (hoy en `map_view_model.dart:104-111`) gana una línea al principio:

```dart
Future<void> seleccionarComuna(String comunaId) async {
  _radioActivo = false; // línea nueva
  final miOperacion = ++_operacionDeCuerpo;
  // ... resto sin cambios
}
```

### 3.5 `limpiarComuna` y el radio

`limpiarComuna` (línea 119-124 hoy) vuelve a `_cargarSegunPermiso`, que llama
`_cargarPorGeolocalizacion` si hay permiso — como `_radioActivo` no se tocó al elegir la comuna (ya
estaba en `false` por 3.4), no hace falta ningún cambio ahí: se recarga en modo comuna, que es lo
correcto (limpiar comuna no "reactiva" un radio que el usuario no pidió).

## 4. Mobile — UI y tour

### 4.1 El switch en la `GlassBar`

Nuevo widget `lib/ui/features/map/views/radius_toggle_button.dart`, mismo patrón que
`MaterialFilterButton` (icono que cambia de color activo/inactivo dentro de `GlassBarAction`):

```dart
class RadiusToggleButton extends StatelessWidget {
  const RadiusToggleButton({super.key, required this.viewModel});

  final MapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final activo = viewModel.radioActivo;
    return GlassBarAction(
      icon: activo ? Icons.social_distance : Icons.social_distance_outlined,
      color: activo ? Theme.of(context).colorScheme.secondary : null,
      onTap: () => viewModel.alternarRadio(!activo),
    );
  }
}
```

(el ícono exacto de Material Icons se confirma al implementar si `social_distance` no transmite
bien "radio de cercanía" — no es una decisión que valga la pena bloquear la spec).

En `map_view.dart`, dentro del `GlassBar` que hoy tiene `[ComunaSelector, MaterialFilterButton]`
(línea ~204-214), se agrega `RadiusToggleButton` entre medio — antes del selector de comuna, ya
que conceptualmente es "cómo buscar", igual jerarquía que elegir la comuna:

```dart
GlassBar(
  children: [
    RadiusToggleButton(viewModel: widget.viewModel), // nuevo
    ComunaSelector(...),
    MaterialFilterButton(...),
  ],
),
```

**Visibilidad condicional**, siguiendo el mismo criterio que hoy oculta todo el `GlassBar` en
`FueraDeRango` (línea 200-201: `widget.viewModel.cuerpo is FueraDeRango ? _AvisoFueraDeRango() :
GlassBar(...)`) — sin cambios ahí, el `RadiusToggleButton` ya queda oculto en ese caso al ir
adentro del mismo `GlassBar`.

**Deshabilitado sin permiso de ubicación**: si `!viewModel.tienePermisoDeUbicacion`, el botón debe
verse pero no responder al toque (`onTap: null`), igual criterio que
`MaterialFilterButton` cuando `nombresDeMateriales` está vacío (línea 18 de ese archivo) — activar
el radio sin ubicación no tiene con qué centrarse.

**Siempre tocable si hay ubicación, tenga o no una comuna elegida**: a diferencia del caso
anterior, el botón NO se deshabilita cuando hay una comuna seleccionada — tocarlo en ese estado es
justamente el flujo de 3.2 (limpia la comuna, geolocaliza de nuevo, busca en 3km). No hace falta
ninguna condición extra en el widget para esto — el propio `alternarRadio` ya lo resuelve.

### 4.2 Paso nuevo del tour

En `map_view.dart`, el `_MapViewState` gana una key más (junto a `_keyMiUbicacion`,
`_keyComunaSelector`, `_keyFiltroMateriales`, líneas 62-64):

```dart
final _keyRadioToggle = GlobalKey();
```

Pasada a `RadiusToggleButton` como `key: _keyRadioToggle`, y un paso nuevo en la lista de
`TourStep` (hoy 5 pasos, líneas 91-114), insertado después del paso "Elige tu comuna" (coherente
con el orden "cómo buscar" antes que "filtra por material"):

```dart
TourStep(
  titulo: 'Busca por cercanía',
  cuerpo: 'Actívalo para ver los puntos a 3km a la redonda tuyo, sin importar la comuna — '
      'útil si vives cerca del límite entre dos comunas.',
  anchorKey: _keyRadioToggle,
),
```

## 5. Plan de implementación — dos planes, backend primero

Este spec se ejecuta como **dos planes separados** vía `writing-plans`, uno por repo:

1. **Backend** (`service-reciclai`): secciones 1.1 a 1.4. Se implementa y mergea primero — el
   endpoint no rompe nada existente (es aditivo, `/points/nearby` no cambia) y la app mobile lo
   necesita para poder probar su propio plan contra un backend real.
2. **Mobile** (`reciclai_mobile`): secciones 2 a 4, una vez el endpoint de backend esté
   desplegado en Render.

Cada plan sigue el flujo normal de este proyecto (TDD estricto, `writing-plans` →
`executing-plans`, commit solo tras suite verde y confirmación explícita).
