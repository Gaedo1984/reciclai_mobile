# Cliente Flutter de ReciclAI — MVP (mapa + puntos de reciclaje) — Diseño

**Contexto:** primer trabajo real sobre `reciclai_mobile` (recién renombrado desde el esqueleto
placeholder `hola_mundo_app`). El backend (`service-reciclai`) ya está completo end-to-end para
las comunas piloto — los 4 endpoints de lectura funcionan, probados con 137 tests en verde. Este
spec cubre la app móvil completa del MVP tal como la describe el spec general
(`service-reciclai/docs/superpowers/specs/2026-08-24-app-reciclaje-design.md`, secciones 1 y 8):
mapa con auto-geolocalización, selector manual de comuna como respaldo, detalle de punto al
tocarlo — sin cuentas de usuario, sin filtros interactivos, todo en una sola pasada.

**Backend consumido (ya construido, sin cambios en este spec):**
- `GET /comunas` — comunas piloto disponibles.
- `GET /materiales` — catálogo de materiales (labels/íconos).
- `GET /points?comuna_id=` — puntos de una comuna.
- `GET /points/nearby?lat=&lng=` — resuelve la comuna server-side; responde `{covered: false,
  comunas_disponibles: [...]}` si la coordenada no cae en ninguna comuna piloto (no es un error).
- Todos requieren header `X-API-Key`.

**Fuera de alcance de este spec (documentado, no construido):**
- Despliegue del backend a un servicio real (Railway/Fly/Render/etc.) — el backend corre local
  (`uv run uvicorn`) durante todo este desarrollo. Es un tema aparte, para más adelante.
- Filtro interactivo por material en la UI — el dato ya está modelado en el backend, falta la
  interacción (post-MVP, spec general sección 11).
- Cualquier forma de cuenta de usuario, login, o captura de email — no existen en este MVP ni se
  construyen acá.

## 1. Pantallas y flujo

Una sola pantalla principal (`MapScreen`), sin navegación entre rutas separadas — el selector de
comuna y el detalle de un punto son overlays (bottom sheets) sobre el mapa, no pantallas nuevas.

```
Al entrar a MapScreen:
  1. Se solicita permiso de GPS (whenInUse).
  2. Permiso CONCEDIDO:
       obtener posición actual
       → GET /points/nearby?lat=&lng=
       → covered=true:  centrar mapa ahí, mostrar los puntos de esa comuna
       → covered=false: estado "tu ubicación no está cubierta todavía"
                         + selector manual de comuna (usa comunas_disponibles
                           de esa misma respuesta, sin otra llamada)
  3. Permiso DENEGADO (temporal):
       cae directo al selector manual de comuna, sin bloquear la app
  4. Permiso DENEGADO PERMANENTE:
       mensaje explicando cómo habilitarlo en Ajustes
       + selector manual de comuna sigue disponible mientras tanto
  5. Selector manual de comuna (bottom sheet, lista de GET /comunas):
       al elegir una comuna → GET /points?comuna_id=
       → se REEMPLAZA por completo el estado de puntos actual (nunca se
         acumulan puntos de comunas distintas en pantalla — evita saturar
         la pantalla de información)
       → el mapa se recentra automáticamente en la comuna elegida
  6. Tocar un punto en el mapa:
       bottom sheet con nombre, dirección, tipo, materiales, horario,
       y botón "Visitar sitio web" si sitio_web no es null
  7. Error de red en cualquier llamada:
       estado de error simple con botón "Reintentar" (reintenta la última
       acción: geolocalizar, o volver a pedir la comuna seleccionada)
```

**Decisión explícita (confirmada por el usuario):** cambiar de comuna — ya sea detectada por GPS
o elegida a mano — siempre reemplaza el conjunto de puntos mostrado, nunca lo agrega al anterior.
La pantalla muestra los puntos de una única comuna a la vez.

## 2. Arquitectura y capas

Se mantiene el patrón MVVM ya iniciado en el esqueleto del proyecto (`lib/ui/features/`,
`ChangeNotifier` + `ListenableBuilder`, sin paquete externo de manejo de estado — alcanza de
sobra para una sola pantalla con un puñado de estados). No se replica la arquitectura hexagonal
del backend acá: no hay lógica de negocio que aislar, solo consumo de una API de lectura ya
validada — una capa de datos delgada es suficiente y evita sobre-ingeniería.

```
lib/
├── data/
│   ├── models/
│   │   ├── comuna.dart              -- Comuna(id, nombre, region)
│   │   ├── material.dart            -- Material(codigo, nombre)
│   │   ├── recycling_point.dart     -- RecyclingPoint(id, nombre, direccion, lat, lng, tipo,
│   │   │                               materiales[], horario, esEmpresa, sitioWeb, confianza)
│   │   └── points_nearby_result.dart -- sealed class: Covered(puntos) | NotCovered(comunasDisponibles)
│   └── reciclai_api_client.dart     -- usa el paquete `http`, agrega X-API-Key, expone los 4
│                                        endpoints, parsea JSON a los modelos de arriba
├── domain/
│   └── location_service.dart        -- wrapper sobre `geolocator`: pide permiso, expone los 3
│                                        estados (concedido/denegado/denegado permanente) y la
│                                        posición actual
└── ui/features/map/
    ├── views/
    │   ├── map_view.dart             -- pantalla principal, arma el widget de mapa + overlays
    │   ├── point_details_sheet.dart  -- bottom sheet del punto 6
    │   └── comuna_picker_sheet.dart  -- bottom sheet del punto 5
    └── view_models/
        └── map_view_model.dart       -- ChangeNotifier, único que conoce tanto
                                          ReciclaiApiClient como LocationService; coordina
                                          el flujo completo de la sección 1 y expone un
                                          estado (Cargando | SinCobertura | Error | ConDatos)
                                          que la vista solo renderiza
```

**Aislamiento del widget de mapa:** el mapa en sí (`flutter_map`, ver sección 3) se encapsula en
un widget propio dentro de `map_view.dart` que solo recibe la lista de puntos a dibujar y el
centro/zoom — no conoce `ReciclaiApiClient` ni `LocationService`. Esto deja la puerta abierta a
cambiar de librería de mapa más adelante (ej. a `google_maps_flutter`) sin tocar el resto de la
pantalla, si el resultado visual de OpenStreetMap no convence.

**Nuevas dependencias a agregar en `pubspec.yaml`:** `flutter_map`, `latlong2` (tipo de
coordenada que usa `flutter_map`), `http`, `geolocator`.

## 3. Mapa — flutter_map + OpenStreetMap

Se usa `flutter_map` con tiles de OpenStreetMap: gratis, sin API key, sin facturación ni cuota de
uso — coherente con el enfoque de costo-cero ya seguido en todo el backend (a diferencia de
`google_maps_flutter`, que requeriría una API key nueva de Google Cloud con facturación
habilitada, separada de las que ya usa el backend para Geocoding/Places).

Cada `RecyclingPoint` se dibuja como un marcador; tocar un marcador abre el bottom sheet de
detalle (sección 1, punto 6). El centro y zoom inicial del mapa los determina `MapViewModel`
según el flujo activo (posición del usuario si vino por GPS, o un centro/zoom razonable para la
comuna si vino por selección manual — el backend no devuelve un centroide de comuna, así que se
calcula client-side como el promedio de las coordenadas de los puntos recibidos; si la comuna no
tiene puntos todavía, se usa un zoom por defecto centrado en el primer punto de
`comunas_disponibles` o, en su defecto, un centro fijo de Santiago).

## 4. Configuración (API key y URL del backend)

Ambos se inyectan en tiempo de build con `--dart-define`, nunca hardcodeados en el código fuente
ni commiteados:

```dart
const _apiKey = String.fromEnvironment('RECICLAI_API_KEY');
const _baseUrl = String.fromEnvironment(
  'RECICLAI_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000', // emulador Android; iOS/desktop usan localhost
);
```

Comando de desarrollo local:

```bash
flutter run \
  --dart-define=RECICLAI_API_KEY=<la-misma-clave-configurada-en-el-backend> \
  --dart-define=RECICLAI_API_BASE_URL=http://localhost:8000
```

(la URL exacta depende del target: `10.0.2.2` para el emulador Android, `localhost` para
simulador iOS/desktop — el backend hoy solo corre local, desplegarlo es un tema aparte, fuera de
alcance de este spec). Se documenta en el README de `reciclai_mobile`, igual que el backend
documenta sus propias variables de entorno.

## 5. Manejo de errores

- **Permiso de GPS:** los 3 estados de la sección 1 (concedido / denegado / denegado permanente)
  — ninguno bloquea la app, siempre cae al selector manual de comuna.
- **`covered: false`:** no es un error de UI — es un estado normal (mensaje + selector con
  `comunas_disponibles`, que ya viene en esa misma respuesta).
- **Error de red / `401` / `429` / `500`:** un único estado de error genérico con botón
  "Reintentar" que reintenta la última acción (geolocalizar, o volver a pedir la comuna
  seleccionada). No se diferencia el mensaje por código HTTP en el MVP — el usuario no puede
  hacer nada distinto en ningún caso salvo reintentar.
- **Timeout:** `ReciclaiApiClient` usa un timeout explícito de 10 segundos en cada llamada (mismo
  criterio ya usado en los adaptadores HTTP del backend) para que el estado de carga nunca quede
  colgado indefinidamente — un timeout se trata igual que cualquier otro error de red.

## 6. Testing

- **`MapViewModel`:** unit tests con fakes de `ReciclaiApiClient` y `LocationService` (mismo
  patrón de fakes ya usado en todo el backend) — cubre los 3 estados de permiso de GPS, el
  reemplazo completo del estado de puntos al cambiar de comuna (sección 1), y los estados de
  error/reintento.
- **`ReciclaiApiClient`:** tests con un `http.Client` fake — verifica que arma la URL y el header
  `X-API-Key` correctamente, y que parsea bien las 4 respuestas, incluyendo el shape-switch de
  `/points/nearby` (`Covered` vs `NotCovered`).
- **Vista:** widget tests livianos (reemplazan el `widget_test.dart` placeholder actual) que
  verifican que cada estado de `MapViewModel` (cargando / sin cobertura / error / con datos)
  renderiza lo esperado — sin llamadas de red reales, inyectando el ViewModel ya en el estado a
  probar.
- Nunca se llama al backend real (ni local ni desplegado) desde un test — mismo principio ya
  establecido en todo el proyecto backend.

## 7. Fuera de alcance (post-MVP, sin diseñar todavía)

- Despliegue del backend a un hosting real.
- Filtro interactivo por material.
- Notificaciones / captura opcional de email (spec general, sección 11).
- Cualquier ajuste visual del mapa más allá de elegir un estilo de tiles OSM — si el look de
  OpenStreetMap no convence del todo, cambiar de librería de mapa es un cambio acotado gracias al
  aislamiento del widget de mapa (sección 2), pero no se diseña ni se decide en este spec.
