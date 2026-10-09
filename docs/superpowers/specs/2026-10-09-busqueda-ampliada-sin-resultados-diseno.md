# Búsqueda ampliada cuando el filtro de materiales no encuentra nada — Diseño

## Contexto

Testers de la prueba cerrada reportaron que, al filtrar por un material (por
ejemplo "aceite usado"), su comuna a veces no tiene ningún punto con ese
material — la app no les ofrece ninguna forma fácil de buscar más lejos sin
salir del filtro y adivinar otra comuna a mano.

## Objetivo

Cuando el filtro de materiales deja la vista sin ningún punto visible,
ofrecer un botón en el mapa (no en la hoja del filtro) que busca en un radio
de 15km alrededor de la ubicación actual del usuario, manteniendo el filtro
de materiales aplicado.

## Alcance — cuándo aparece el botón

El botón aparece **solo** cuando se cumplen TODAS estas condiciones:
1. El usuario está en modo geolocalización (`comunaSeleccionadaId == null`)
   — **no** aparece si eligió una comuna a mano.
2. Hay al menos un material seleccionado (`materialesSeleccionados.isNotEmpty`).
3. El filtro de materiales, aplicado sobre los puntos ya cargados, deja la
   lista visible en cero (`filtrarPorMateriales(puntos, materialesSeleccionados).isEmpty`),
   aunque la carga en sí haya funcionado (`cuerpo` es `ConDatos`, no un error).

El botón desaparece de inmediato si deja de cumplirse cualquiera de las tres
condiciones: se borra el filtro de materiales, se elige una comuna a mano, o
el filtro ya encuentra algo (por ejemplo, porque la búsqueda ampliada trajo
resultados).

## Comportamiento al activarlo

- Pide al backend los puntos dentro de un radio de **15.000 metros** (15km)
  alrededor de la posición geolocalizada actual del usuario — mismo
  mecanismo que el radio de 3km ya existente (`GET /points/nearby/radius`),
  parametrizando el radio en vez de usar el valor fijo de 3000m.
- Reemplaza los puntos mostrados en el mapa por este conjunto más amplio. El
  filtro de materiales se sigue aplicando sobre este nuevo conjunto (sigue
  siendo 100% client-side, sin cambios en esa lógica).
- Esto es independiente del switch de radio de 3km ya existente
  (`radioActivo`): activar la búsqueda ampliada no cambia `radioActivo`, ni
  viceversa — son dos orígenes de datos distintos, uno no es un caso
  particular del otro a nivel de estado (evita que desactivar el radio de
  3km belga apague accidentalmente la búsqueda ampliada o viceversa).
- No es necesario que el usuario pueda "desactivarlo" a mano con otro toque
  — el botón dejar de aparecer apenas la condición de "sin resultados" deja
  de cumplirse (ver arriba) ya resetea el estado; no hace falta un segundo
  control para apagarlo expresamente. Si igual se decide agregar una forma
  explícita de volver atrás, debe ser evaluado durante la implementación sin
  cambiar el criterio de aparición/desaparición automático de arriba.

## Backend — cambio mínimo

`GET /points/nearby/radius` acepta un parámetro opcional `radio_metros` en
la query string. Si no se envía, usa el default actual (3000m) — el radio de
3km ya existente en el cliente no cambia su llamada y sigue funcionando
igual. `PostgisRecyclingPointQuery.por_radio` ya acepta `radio_metros` como
parámetro (ver `src/reciclai/infrastructure/outbound/postgis/recycling_point_query.py`)
— el cambio es exponer ese valor ya existente a través del router en vez de
tener el 3000 fijo ahí, no tocar la capa de dominio/aplicación.

## Mobile — cambios

- `ReciclaiApiClient.obtenerPuntosEnRadio` gana un parámetro opcional
  `radioMetros` (default null → el backend aplica su propio default de
  3000m, preservando el comportamiento actual cuando no se especifica).
- `MapViewModel` gana un nuevo estado (ej. `bool mostrarBotonRadioAmplio` —
  getter derivado, no un campo independiente a sincronizar a mano — y un
  método para activarlo, ej. `Future<void> buscarEnRadioAmplio()`).
- El botón vive en `map_view.dart`, como un nuevo overlay condicional sobre
  el mapa (mismo patrón que `_AvisoFueraDeRango`), no dentro de
  `material_filter_button.dart`.
- Nuevo paso en el tour interactivo (`_iniciarTour` en `map_view.dart`)
  explicando el botón. Como el botón solo aparece condicionalmente (igual
  que el botón de "mi ubicación" sin permiso), el paso debe usar el mismo
  mecanismo ya existente de "saltar paso si el anchor no está montado" —
  revisar cómo lo resuelve el test `'sin permiso de ubicacion, Siguiente
  salta el paso del boton de ubicacion'` y replicarlo, o usar un paso sin
  anchor (`anchorKey: null`, tarjeta centrada) si no se justifica el
  spotlight.

## Testing — casos a cubrir

- El botón no aparece sin filtro de materiales.
- El botón no aparece con comuna elegida a mano, aunque el filtro de cero.
- El botón no aparece si el filtro ya encuentra algo.
- El botón aparece cuando se cumplen las tres condiciones.
- Activarlo pide el radio de 15km y reemplaza los puntos mostrados.
- El filtro de materiales se sigue aplicando sobre el resultado ampliado.
- El botón desaparece solo si se borra el filtro, se elige una comuna, o el
  resultado ampliado ya no está vacío.
- Backend: `GET /points/nearby/radius` sin `radio_metros` sigue usando 3000m
  (no rompe el radio de 3km existente); con `radio_metros=15000` devuelve
  puntos dentro de ese radio.
