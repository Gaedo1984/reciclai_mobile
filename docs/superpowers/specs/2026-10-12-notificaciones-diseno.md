# Módulo de notificaciones — Diseño

## Contexto

Se quiere poder avisar a los usuarios de la app (ej. una nueva versión
disponible, un aviso puntual) sin pasar por una actualización de la store.
El origen de estos avisos es un workflow de GitHub Actions, que escribe la
notificación contra el backend; la app mobile las muestra en una campana en
la barra superior.

No hay cuentas de usuario en la app — todo el estado de "leído" es local al
dispositivo, no del lado del servidor.

## Alcance

**Incluye:** la tabla y los endpoints nuevos del backend (protegidos,
con circuit breaker), y toda la UI del mobile (campana, hoja, modal,
persistencia local de lo leído).

**No incluye:** el archivo `.yml` del workflow de GitHub Actions que va a
llamar al endpoint de escritura — eso se conecta por separado, después de
este trabajo. Este spec sí deja el endpoint listo, seguro, y documentado
con un ejemplo de `curl` para que esa conexión sea directa.

## Backend (`service-reciclai`)

### Tabla nueva

Migración Alembic nueva, tabla `notificacion`:

| Columna      | Tipo                         | Notas                          |
|--------------|-------------------------------|---------------------------------|
| `id`         | `UUID`                        | PK, `server_default=gen_random_uuid()`, mismo patrón que `recycling_point`/`ingestion_run` |
| `titulo`     | `Text`, `nullable=False`      |                                 |
| `texto`      | `Text`, `nullable=False`      |                                 |
| `creada_en`  | `TIMESTAMP(timezone=True)`, `nullable=False`, `server_default=func.now()` | |

Sin columna de "leído" — ese estado es 100% local al dispositivo (ver
sección Mobile).

### Dominio, puerto y adaptador

- `domain/entities.py`: nueva entidad `Notificacion` (`id: str`,
  `titulo: str`, `texto: str`, `creada_en: datetime`), `@dataclass(frozen=True)`
  como el resto de las entidades de este módulo.
- `application/ports/outbound.py`: nuevo `NotificacionPort(Protocol)`:
  - `async def crear(self, titulo: str, texto: str) -> Notificacion`
  - `async def listar(self, limite: int) -> tuple[Notificacion, ...]` —
    ordenadas por `creada_en` descendente (más reciente primero).
- `infrastructure/outbound/postgis/notificacion_catalog.py`:
  `PostgisNotificacionCatalog`, implementa el puerto contra
  `NotificacionModel` (nuevo, en `models.py`, `__tablename__ = "notificacion"`,
  mismas columnas que la tabla de arriba).

### Circuit breaker

Dos instancias de `CircuitBreaker` (`application/circuit_breaker.py`, ya
existente — reusado, no se crea una variante nueva), creadas una sola vez
en `create_app()` y guardadas en `app.state` (mismo lugar que ya vive
`app.state.sessionmaker`):

- `app.state.breaker_notificaciones_lectura` — envuelve
  `NotificacionPort.listar(...)`.
- `app.state.breaker_notificaciones_escritura` — envuelve
  `NotificacionPort.crear(...)`.

Independientes entre sí (mismo criterio que ya separa los breakers de
geocoder/corroboración/extractor en la ingesta — un dominio de falla no
debe bloquear al otro). Valores por defecto de `CircuitBreaker` sin
cambios (`umbral=3`, `segundos_recuperacion=60.0`).

Dos dependencias nuevas en `dependencies.py`:
```python
async def get_breaker_notificaciones_lectura(request: Request) -> CircuitBreaker:
    return request.app.state.breaker_notificaciones_lectura

async def get_breaker_notificaciones_escritura(request: Request) -> CircuitBreaker:
    return request.app.state.breaker_notificaciones_escritura
```

Si el circuito está abierto (`CircuitoAbiertoError`), el router responde
`503 Service Unavailable` en vez de colgarse reintentando contra una base
de datos que ya mostró fallar — relevante porque Render (plan free) puede
dormirse, y así ni el mobile ni el workflow de GitHub Actions quedan
esperando indefinidamente.

### Seguridad — dos llaves distintas

Hoy toda la API usa una sola `X-API-Key` (env `RECICLAI_API_KEY`),
embebida en el APK del mobile — cualquiera puede extraerla decompilando la
app. Es aceptable para los endpoints de **lectura** (datos públicos de
puntos de reciclaje), pero no para **escribir** notificaciones que el
usuario va a ver en pantalla: si se reusara la misma key para escribir,
cualquiera que decompile la app podría spamear notificaciones falsas.

- `GET /notificaciones` — protegido con la `X-API-Key` de siempre
  (`require_api_key`, sin cambios), la misma que ya usa el mobile.
- `POST /notificaciones` — protegido con una dependencia **nueva**,
  `require_notificaciones_write_key`, que valida un header distinto
  (`X-Notificaciones-Write-Key`) contra una variable de entorno nueva
  (`RECICLAI_NOTIFICACIONES_WRITE_KEY`), mismo patrón de comparación
  segura (`hmac.compare_digest`) que ya usa `require_api_key`. Esta key
  **nunca** se empaqueta en el mobile — solo vive como secret del
  workflow de GitHub Actions que la va a usar (fuera de este spec, ver
  "Alcance").

### Router y schemas

`infrastructure/inbound/http/routers/notificaciones.py`:

```python
router = APIRouter(prefix="/notificaciones", tags=["notificaciones"])

@router.get("", response_model=list[NotificacionSchema], dependencies=[Depends(require_api_key)])
async def listar_notificaciones(
    limite: int = 50,
    catalogo: NotificacionPort = Depends(get_notificacion_catalog),
    breaker: CircuitBreaker = Depends(get_breaker_notificaciones_lectura),
) -> list[NotificacionSchema]:
    try:
        notificaciones = await breaker.call(catalogo.listar, limite)
    except CircuitoAbiertoError:
        raise HTTPException(status_code=503, detail="servicio temporalmente no disponible")
    return [notificacion_schema(n) for n in notificaciones]

@router.post(
    "", response_model=NotificacionSchema, status_code=201,
    dependencies=[Depends(require_notificaciones_write_key)],
)
async def crear_notificacion(
    payload: CrearNotificacionSchema,
    catalogo: NotificacionPort = Depends(get_notificacion_catalog),
    breaker: CircuitBreaker = Depends(get_breaker_notificaciones_escritura),
) -> NotificacionSchema:
    try:
        notificacion = await breaker.call(catalogo.crear, payload.titulo, payload.texto)
    except CircuitoAbiertoError:
        raise HTTPException(status_code=503, detail="servicio temporalmente no disponible")
    return notificacion_schema(notificacion)
```

`infrastructure/inbound/http/schemas.py`, agregar:
```python
class NotificacionSchema(BaseModel):
    id: str
    titulo: str
    texto: str
    creada_en: datetime

class CrearNotificacionSchema(BaseModel):
    titulo: str
    texto: str
```

`creada_en` es el primer campo `datetime` que expone esta API — Pydantic
lo serializa como ISO 8601 por defecto (sin configuración adicional), que
`DateTime.parse(...)` del lado Dart ya interpreta nativamente.

Registrar el router nuevo en `app.py` (`app.include_router(notificaciones.router)`),
y crear ahí mismo las dos instancias de `CircuitBreaker` descritas arriba.

### Ejemplo de llamada desde GitHub Actions (documentación, no código de este repo)

```bash
curl -X POST "$RECICLAI_API_BASE_URL/notificaciones" \
  -H "X-Notificaciones-Write-Key: $RECICLAI_NOTIFICACIONES_WRITE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"titulo": "Nueva versión disponible", "texto": "Ya podés buscar por 3, 5 o 7 km."}'
```

## Mobile (`reciclai_mobile`)

### Dependencia nueva

`shared_preferences` en `pubspec.yaml` — única forma de persistir "qué
notificaciones ya se leyeron" en un dispositivo sin cuentas de usuario.

### Datos

- `lib/data/models/notificacion.dart`: `Notificacion` (`id: String`,
  `titulo: String`, `texto: String`, `creadaEn: DateTime`), con
  `fromJson`, mismo patrón que `lib/data/models/recycling_point.dart`.
- `ReciclaiApiClient.obtenerNotificaciones({int limite = 50})` → `GET
  /notificaciones?limite=$limite`, mismo patrón de `_get` + manejo de
  errores que el resto del cliente.

### `NotificacionesViewModel` (nuevo, `lib/ui/features/notificaciones/view_models/notificaciones_view_model.dart`)

Separado de `MapViewModel` — responsabilidad propia, no relacionada con el
mapa.

- `List<Notificacion> notificaciones` (getter, vacía hasta que `cargar()`
  resuelva).
- `Set<String> _idsLeidas` — cargado de `SharedPreferences` (clave
  `notificaciones_leidas`, lista de ids codificada como JSON) al construir
  el ViewModel.
- `bool get hayNoLeidas` — `notificaciones.any((n) => !_idsLeidas.contains(n.id))`.
- `bool estaLeida(String id) => _idsLeidas.contains(id)`.
- `Future<void> cargar()` — pide `obtenerNotificaciones()` al backend;
  fallo silencioso (igual que comunas/materiales — no bloquea nada más de
  la app, la campana simplemente no muestra el punto hasta que una carga
  posterior tenga éxito).
- `Future<void> marcarLeida(String id)` — agrega `id` a `_idsLeidas`,
  persiste en `SharedPreferences`, `notifyListeners()`.

Sin ningún `Timer` ni polling — `cargar()` se llama una vez al abrir la
app (ver Wiring) y de nuevo cada vez que se toca la campana (ver UI). Se
decidió explícitamente no pedir al backend en segundo plano mientras la
app está abierta: estas notificaciones son avisos puntuales (releases,
incidentes), no algo que cambie minuto a minuto, así que el costo de un
timer recurrente (batería, datos, carga al backend) no se justifica frente
al beneficio. Si en el futuro se necesitan notificaciones que lleguen sin
que el usuario abra la app, eso requiere una arquitectura distinta (push
real, ej. Firebase Cloud Messaging) — fuera de este spec.

### Wiring

- `main.dart`: se construye `NotificacionesViewModel(apiClient: ...)`
  junto al `MapViewModel` ya existente, y se pasa a `SplashView` como
  nuevo parámetro `notificacionesViewModel`.
- `SplashView`: solo reenvía el parámetro a `MapView` (no espera a que
  `cargar()` termine para navegar — mismo criterio que comunas/materiales,
  no es parte de la condición de "splash listo").
- `MapView.initState`: dispara `notificacionesViewModel.cargar()` en
  paralelo (sin bloquear), igual que ya hace con `viewModel.iniciar()`.

## UI (mobile)

### Campana (`lib/ui/features/notificaciones/views/campana_notificaciones.dart`)

- `IconButton` dentro de un `Badge` (widget nativo de Material, no uno
  hecho a mano) en el `AppBar` de `map_view.dart`, a la izquierda del
  `TourTriggerButton` ya existente en `actions`.
- Ícono `Icons.notifications_outlined`. `Badge(isLabelVisible:
  viewModel.hayNoLeidas, smallSize: 8, child: Icon(...))` — punto rojo
  pequeño sin número, visible solo si `hayNoLeidas`.
- Al tocarla: llama a `viewModel.cargar()` (refresca contra el backend) y
  abre la hoja.

### Hoja (`lib/ui/features/notificaciones/views/hoja_notificaciones.dart`)

- `showModalBottomSheet(isScrollControlled: true, isDismissible: false,
  enableDrag: false, backgroundColor: Colors.transparent, builder: ...)`
  con `FloatingSheetCard` (reusado, mismo patrón que las otras hojas de la
  app) envuelto en un `PopScope(canPop: false)` — el botón atrás del
  sistema no la cierra; solo la X de la esquina superior derecha
  (`BotonCerrarHoja`, reusado).
- Encabezado: "Notificaciones" + `BotonCerrarHoja`.
- Estado local `_mostrarTodas = false`. Lista a mostrar:
  `_mostrarTodas ? viewModel.notificaciones : viewModel.notificaciones.take(5)`.
- Cada fila (`ListTile` o similar):
  - No leída (`!viewModel.estaLeida(n.id)`): título en
    `FontWeight.bold`, con un punto pequeño (`colorScheme.primary`, el
    verde de la app) antes del título.
  - Leída: título en peso normal, sin punto.
  - `onTap`: `viewModel.marcarLeida(n.id)` + abre el modal de detalle
    (ver abajo) con esa notificación. Como la hoja sigue montada,
    `ListenableBuilder`/`AnimatedBuilder` sobre el ViewModel hace que la
    fila se repinte como leída de inmediato, sin cerrar la hoja.
  - Si `viewModel.notificaciones.length > 5` y `!_mostrarTodas`: al final
    de la lista, un `TextButton` con el texto **"Mostrar todas"** que
    hace `setState(() => _mostrarTodas = true)`.
- La lista completa va envuelta en un `Scrollbar(thumbVisibility: true,
  child: ListView(...))` — el widget nativo de Flutter para indicar "hay
  más contenido para abajo", no uno hecho a mano.
- Tope de carga: `obtenerNotificaciones(limite: 50)` — ver sección
  Backend. Si algún día se necesita más, se agrega paginación; no se
  construye ahora (YAGNI) para un volumen esperado de avisos puntuales.

### Modal de detalle (`lib/ui/features/notificaciones/views/detalle_notificacion_modal.dart`)

- `showDialog(barrierDismissible: false, builder: ...)` envuelto en
  `PopScope(canPop: false)` — mismo criterio que la hoja: solo la X
  cierra, ni el botón atrás ni tocar afuera.
- Contenido: título (`textTheme.titleLarge`) arriba, texto del cuerpo
  abajo (ver "Links en el cuerpo"), `BotonCerrarHoja` en la esquina
  superior derecha.

### Links en el cuerpo de la notificación

El texto puede incluir links en formato Markdown: `[texto visible](url)`
— ej. `"Para más detalles, pinchá aquí: [aquí](https://reciclai.cl/aviso)"`.
Así quien escribe la notificación (vía el POST desde GitHub Actions) no
necesita pegar el URL completo en el cuerpo, que muchas veces es largo.

- `lib/ui/features/notificaciones/views/texto_con_links.dart`: nuevo
  widget `TextoConLinks extends StatelessWidget` (`required this.texto`),
  reusable — lo usa el modal de detalle, no la hoja (que solo muestra
  títulos).
- Parseo con una expresión regular simple:
  `RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)')`. Recorre el texto y
  separa en segmentos: texto plano (`TextSpan` normal) y links
  (`TextSpan` subrayado, color `colorScheme.primary` — el mismo verde de
  acento ya usado en el resto de la app — con un
  `TapGestureRecognizer.onTap` que llama a
  `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`,
  mismo patrón ya usado en `point_details_sheet.dart`).
- Soporta más de un link en el mismo texto (el regex se aplica con
  `allMatches`, no solo al primero).
- Si el texto no tiene ningún link, se muestra tal cual, sin cambios de
  estilo — el camino sin links de hoy no se modifica.
- Un link con URL inválida (no empieza con `http://`/`https://`, ya
  filtrado por el propio regex) nunca llega a intentar abrirse — ese
  `[texto](algo-que-no-es-url)` queda, a propósito, sin matchear el
  regex, y se muestra como texto plano literal (con los corchetes), sin
  romper el resto del parseo. No hace falta un manejo de error aparte:
  el regex en sí ya es la validación.

## Testing — casos a cubrir

### Backend (`tests/`)

- `NotificacionPort.crear` guarda y devuelve la notificación con `id` y
  `creada_en` generados.
- `NotificacionPort.listar` devuelve ordenado por `creada_en` descendente,
  respeta el `limite`.
- `GET /notificaciones` sin `X-API-Key` (o con una incorrecta) devuelve
  401.
- `GET /notificaciones` con la key correcta devuelve 200 y la lista.
- `POST /notificaciones` sin `X-Notificaciones-Write-Key` (o con la
  `X-API-Key` de lectura en su lugar) devuelve 401 — confirma que las dos
  keys son independientes, una no sirve para la otra.
- `POST /notificaciones` con la write key correcta devuelve 201 y la
  notificación creada.
- Con el circuito de lectura ya abierto (3 fallas seguidas simuladas),
  `GET /notificaciones` devuelve 503 sin intentar la llamada real.
- Mismo caso para el circuito de escritura con `POST /notificaciones`.
- Los dos circuitos son independientes: forzar la apertura del de lectura
  no bloquea una escritura exitosa, y viceversa.

### Mobile (`test/`)

ViewModel (`notificaciones_view_model_test.dart`):
- `hayNoLeidas` es `false` antes de `cargar()` (lista vacía).
- Tras `cargar()` con notificaciones nuevas y sin nada leído guardado,
  `hayNoLeidas` es `true`.
- `marcarLeida(id)` saca esa notificación de "no leídas" y persiste (un
  `ViewModel` nuevo, re-creado con el mismo `SharedPreferences` falso,
  la sigue viendo como leída).
- Con todas las notificaciones ya leídas, `hayNoLeidas` es `false`.
- Un fallo de `obtenerNotificaciones()` no lanza excepción ni deja
  `hayNoLeidas` en un estado incorrecto (se mantiene lo que ya había).

UI:
- La campana no muestra el punto rojo sin notificaciones no leídas; lo
  muestra cuando hay al menos una.
- Tocar la campana abre la hoja con hasta 5 notificaciones.
- Con más de 5, aparece "Mostrar todas"; al tocarlo, se ven todas.
- Con 5 o menos, no aparece "Mostrar todas".
- Una notificación no leída se ve en negrita con el punto; una leída, sin
  negrita ni punto.
- Tocar una notificación abre el modal con su título y texto, y la fila
  pasa a verse como leída sin cerrar la hoja.
- La hoja no se cierra al tocar afuera ni con el botón atrás — solo con
  su X.
- El modal no se cierra al tocar afuera ni con el botón atrás — solo con
  su X.
- Tras leer todas las notificaciones visibles, el punto rojo de la
  campana desaparece.

`TextoConLinks` (`texto_con_links_test.dart`):
- Texto sin ningún link se muestra igual que antes (un solo `TextSpan`
  plano).
- Texto con un link (`"hola [aquí](https://reciclai.cl) mundo"`) muestra
  "aquí" como el único texto subrayado/tocable; "hola" y "mundo" quedan
  en texto plano.
- Texto con dos links separa correctamente los tres segmentos de texto
  plano y los dos links.
- Tocar el texto del link llama a `launchUrl` con el URL correcto
  (`UrlLauncherPlatformFalso`, mismo patrón que
  `point_details_sheet_test.dart`).
- Un patrón `[texto](no-es-url)` (sin `http://`/`https://`) se muestra
  literal, con los corchetes, sin intentar abrir nada.
