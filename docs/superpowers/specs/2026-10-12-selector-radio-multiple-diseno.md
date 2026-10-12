# Selector de radio con múltiples distancias (Off / 3 / 5 / 7 km) — Diseño

## Contexto

Hoy el radio de búsqueda es un interruptor binario (`radioActivo`): activado,
busca en 3km a la redonda de la ubicación geolocalizada; desactivado, vuelve
al comportamiento normal por comuna/cercanía. El backend
(`GET /points/nearby/radius`) ya acepta un parámetro opcional `radio_metros`
— esto se agregó para la búsqueda ampliada de 15km
(`docs/superpowers/specs/2026-10-09-busqueda-ampliada-sin-resultados-diseno.md`)
y no está limitado a ningún valor fijo. Se quiere ofrecer al usuario más de
una distancia para elegir (3 / 5 / 7 km), en vez del único valor fijo de hoy.

## Objetivo

Reemplazar el interruptor binario de radio por un selector de 4 opciones
(Off, 3 km, 5 km, 7 km), presentado como una extensión visual de la barra
flotante (`GlassBar`) que ya contiene el selector de comuna y el filtro de
materiales — no como una tarjeta/aviso separada.

## Comportamiento

- Tocar el ícono de radio en la barra abre el selector; tocar de nuevo (o
  elegir una opción, o tocar afuera, o su propia X) lo cierra.
- Elegir 3 km, 5 km o 7 km:
  - Si está en modo comuna elegida a mano, la limpia y vuelve de inmediato a
    la ubicación geolocalizada — mismo comportamiento que ya existe hoy al
    activar el radio de 3km (`alternarRadio`).
  - Pide al backend los puntos dentro de ese radio (`radio_metros` en la
    query), reemplazando los puntos mostrados.
  - Mientras carga, se ve el mismo spinner superpuesto que ya se usa para
    cualquier recarga (comuna, radio, "mi ubicación").
  - El filtro de materiales sigue aplicándose sobre el resultado — sin
    cambios en esa lógica. Si el filtro deja la vista en cero, se sigue
    mostrando el aviso temporal de "sin resultados" y, si corresponde, el
    botón de búsqueda ampliada de 15km — ambos ya son genéricos sobre el
    origen de los puntos, no hace falta tocarlos.
- Elegir "Off" vuelve al comportamiento normal (comuna/cercanía sin radio) —
  mismo flujo de recarga que elegir una distancia, pero sin `radio_metros`.
- "Off" se ve siempre dentro del selector, pero atenuado y sin poder tocarse
  mientras no haya ninguna distancia activa (no tiene sentido "apagar" lo que
  ya está apagado).
- Elegir la misma distancia que ya está activa no hace nada (idempotente,
  igual que el interruptor binario de hoy).
- El ícono disparador en la barra queda en el color "activo" de la app
  (ver sección Colores) solo cuando hay una distancia seleccionada (no en
  Off), igual que ya indican los otros íconos de la barra cuando tienen un
  filtro aplicado.

## UI — extensión de la barra, no una tarjeta separada

El selector abierto debe leerse como parte de la misma barra, no como un
aviso o tarjeta flotante distinta:

- Se construye con el mismo widget `GlassBar` (mismo vidrio esmerilado,
  tinte y borde) que ya envuelve al selector de comuna y al filtro de
  materiales — reutilizado, no un estilo nuevo.
- Se ubica pegado directamente arriba de la barra principal (sin la
  separación que sí tienen el aviso de "sin resultados" o el botón de 15km
  respecto de la barra), para que visualmente parezca que la barra "crece"
  hacia arriba al abrirse.
- Contiene los 4 botones (Off / 3 km / 5 km / 7 km) en fila, **pequeños**
  (más compactos que los íconos de 48px de la barra — son etiquetas de
  texto corto, no íconos), separados entre sí por **1.5px**.
- Cada botón muestra su propio estado: el seleccionado en el color "activo"
  de la app: los demás (incluido "Off" cuando sí se puede tocar) en el tono
  neutro de la barra.
- Se cierra sin aplicar ningún cambio si: se toca su propia X, o se toca en
  cualquier otro lugar de la pantalla (el mapa, otro botón de la barra,
  etc.) — un barrera transparente de pantalla completa detrás del selector
  (pero dentro del mismo `Stack` del mapa) detecta ese toque "afuera"; el
  propio panel, al estar encima en el `Stack`, sigue recibiendo sus propios
  toques con normalidad.
- Convive con el bloque ya existente de aviso de "sin resultados" /
  búsqueda ampliada (que se ubica más arriba, sobre la barra) sin
  superponerse: como el selector reemplaza/se pega a la posición de la
  barra misma, ambos bloques quedan en posiciones distintas de la pantalla
  en todo momento.

## ViewModel — `MapViewModel`

- `bool radioActivo` y `Future<void> alternarRadio(bool activo)` se
  reemplazan por:
  - `double? radioMetrosSeleccionado` (getter) — `null` significa Off.
  - `Future<void> seleccionarRadio(double? metros)` — mismo cuerpo que hoy
    tiene `alternarRadio`, generalizado: si `metros` coincide con el valor
    ya activo, no hace nada; si no, limpia la comuna elegida a mano cuando
    corresponde, limpia el estado de búsqueda ampliada (igual que hoy), y
    recarga por geolocalización.
- `_obtenerCuerpoParaPosicion` deja de mirar un `bool` y pasa
  `radioMetros: _radioMetrosSeleccionado` a `_apiClient.obtenerPuntosEnRadio`
  solo cuando no es null; si es null, sigue llamando a
  `obtenerPuntosCercanos` como hoy (equivalente al "Off" actual).
- Las 3 distancias son constantes del ViewModel (3000.0, 5000.0, 7000.0),
  igual que ya existe `_radioMetrosAmpliado = 15000.0` para la búsqueda
  ampliada — mismo patrón, no un valor mágico repetido en la UI.
- Nada cambia en `buscarEnRadioAmplio()` ni en el aviso de "sin resultados"
  — siguen siendo independientes del radio de 3/5/7km, como ya lo son hoy
  del radio de 3km fijo.

## Colores — unificación a verde

Hoy los íconos "activos" de la barra (filtro de materiales) usan el
terracota de la app (`colorScheme.secondary`). Se cambia a el verde
primario de la app (`colorScheme.primary`, el verde salvia base del tema,
sin tocar el seed) para los 3 íconos de la barra:

- Selector de radio (nuevo): verde cuando `radioMetrosSeleccionado != null`.
- Filtro de materiales: cambia de terracota a verde cuando hay materiales
  seleccionados (mismo comportamiento, solo cambia el color).
- Selector de comuna: hoy su lupa nunca cambia de color. Gana el mismo
  comportamiento — verde cuando `comunaSeleccionadaId != null`.

El terracota (`colorScheme.secondary`) deja de usarse como indicador de
"filtro activo" en estos 3 íconos; no se elimina del tema (puede seguir
usándose en otras partes, como el botón "Aplicar" de la hoja de filtro de
materiales, que no es parte de este cambio).

## Tour

El paso "Busca por cercanía" (`_iniciarTour` en `map_view.dart`, anclado a
`_keyRadioToggle`) actualiza su texto para mencionar las 3 distancias en
vez de un único valor fijo de 3km.

## Testing — casos a cubrir

ViewModel (`map_view_model_test.dart`):
- `seleccionarRadio(3000)` desde Off: limpia comuna elegida a mano (si
  había), muestra "Cargando", y pide `obtenerPuntosEnRadio` con
  `radioMetros: 3000`.
- `seleccionarRadio(null)` desde una distancia activa: vuelve a pedir
  `obtenerPuntosCercanos` (sin radio).
- `seleccionarRadio` con el mismo valor ya activo: no dispara ninguna
  recarga.
- Cambiar de una distancia a otra (ej. 3000 → 7000): recarga con el nuevo
  valor.
- El aviso de "sin resultados" y `mostrarBusquedaAmpliada` siguen
  funcionando igual sobre el resultado de cualquiera de las 3 distancias
  (reusar los casos ya existentes para el radio de 3km fijo, parametrizados).

UI (`map_view_test.dart` + nuevo archivo de test para el widget del
selector):
- El selector no se ve por defecto; aparece al tocar el ícono de radio.
- Los 4 botones se ven con una separación de 1.5px entre ellos.
- "Off" se ve atenuado y no responde al toque mientras no hay ninguna
  distancia activa; se habilita apenas hay una.
- Tocar una distancia cierra el selector y llama a
  `viewModel.seleccionarRadio` con el valor correspondiente.
- Tocar la X del selector lo cierra sin llamar a `seleccionarRadio`.
- Tocar afuera del selector (en el mapa) lo cierra sin llamar a
  `seleccionarRadio`.
- El ícono disparador se ve en verde solo cuando hay una distancia activa.
- El selector de comuna y el filtro de materiales se ven en verde (no
  terracota) cuando tienen una selección activa.

Tour (`test/ui/features/tour/` si aplica): el texto del paso "Busca por
cercanía" se actualiza, sin romper el mecanismo existente de anclaje.
