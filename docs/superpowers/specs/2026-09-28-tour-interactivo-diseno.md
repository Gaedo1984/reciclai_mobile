# Tour interactivo de la app — Diseño

**Contexto:** la app (`reciclai_mobile`) ya tiene su pantalla principal (`MapView`) terminada y en
uso real contra el backend en Render. No es una app complicada, pero tiene varias piezas que no
son obvias a primera vista para alguien que la abre por primera vez: el selector de comuna y el
filtro de materiales viven en una barra inferior semitransparente, el botón de "mi ubicación"
solo aparece con permiso de GPS concedido, y no es evidente que tocar un pin del mapa abre un
detalle con botón de ruta. Este spec agrega un tour interactivo bajo demanda que resalta esas
piezas en su lugar real, disparado por un botón nuevo junto al logo de la AppBar.

**Fuera de alcance de este spec:**
- Mostrar el tour automáticamente en el primer uso — es **solo bajo demanda**, vía el botón. No
  se guarda ningún estado de "ya lo vio" en el dispositivo (no hace falta, no hay lógica de
  primera-vez).
- Cambios de copy/traducciones — el texto de los 5 pasos es el de este spec; ajustarlo después es
  un cambio de contenido, no de diseño.
- Cualquier dependencia externa de terceros (paquetes de "showcase"/"coach mark") — se construye
  con widgets estándar de Flutter, sin agregar dependencias nuevas a `pubspec.yaml`.

## 1. Qué explica el tour

Cinco pasos fijos, en este orden:

```
1. (tarjeta centrada, sin resaltar nada)
   "Este es el mapa — los pines verdes son puntos de reciclaje cerca de ti."

2. (resalta el botón flotante "mi ubicación"; se salta solo si no está en
   pantalla — ver sección 4)
   "Toca aquí para centrar el mapa en tu ubicación."

3. (resalta el selector de comuna, en la barra inferior)
   "O elige tu comuna aquí si prefieres buscar así."

4. (resalta el filtro de materiales, en la barra inferior)
   "Filtra por el tipo de material que quieres reciclar."

5. (tarjeta centrada, sin resaltar nada)
   "Toca cualquier pin para ver su dirección, materiales y trazar una ruta."
```

Los pasos 1 y 5 son tarjetas centradas porque no hay un pin específico ni una hoja de detalle
abierta en ese momento para señalar de verdad — se explican como concepto, no como spotlight.

## 2. Componentes nuevos

Carpeta nueva `lib/ui/features/tour/`, siguiendo el mismo patrón de organización que `map/` y
`splash/`:

```
lib/ui/features/tour/
  tour_step.dart          -- modelo de datos, sin lógica
  views/
    tour_overlay.dart     -- el overlay a pantalla completa
    tour_trigger_button.dart -- la pastilla en la AppBar
```

**`tour_step.dart`** — un modelo inmutable, sin comportamiento propio:

```dart
class TourStep {
  const TourStep({required this.titulo, required this.cuerpo, this.anchorKey});

  final String titulo;
  final String cuerpo;

  /// Widget real a resaltar. `null` = tarjeta centrada sin spotlight (pasos 1 y 5).
  final GlobalKey? anchorKey;
}
```

**`tour_overlay.dart`** — un `StatefulWidget` que recibe `List<TourStep> pasos` y se inserta en el
`Overlay` de la app (no es una ruta/pantalla nueva — así puede dibujarse encima de la AppBar y el
mapa sin perder el estado de `MapView` debajo). Responsabilidades:
- Mantiene el índice del paso actual.
- Si el paso actual tiene `anchorKey` y ese key no tiene un `currentContext` montado en pantalla
  (ej. el botón de ubicación no aparece sin permiso GPS), avanza automáticamente al siguiente paso
  sin mostrarlo — ver sección 4.
- Pinta el fondo oscurecido (`Colors.black54`) con un recorte ("hueco") alrededor del
  `RenderBox` del `anchorKey` actual, usando un `CustomPainter` con
  `Path.combine(PathOperation.difference, pantallaCompleta, huecoDelAnchor)`. Si el paso no tiene
  `anchorKey`, no hay hueco — el oscurecido cubre toda la pantalla.
- Muestra una tarjeta (reutilizando el estilo visual de `FloatingSheetCard`, ya existente) con
  `titulo`, `cuerpo`, y tres controles: **Saltar** (cierra el tour entero), **Atrás** (deshabilitado
  en el paso 1), **Siguiente** (dice **Listo** en el último paso y cierra el tour al tocarlo).
  La tarjeta se posiciona arriba o abajo del hueco, según cuál lado tenga más espacio libre en la
  pantalla.
- Tocar el área oscurecida fuera de la tarjeta **no hace nada** — solo los tres botones controlan
  el flujo, para evitar cierres accidentales.

**`tour_trigger_button.dart`** — un `StatelessWidget` con animación propia (no necesita estado
externo): una pastilla con ícono `Icons.tips_and_updates_outlined`, fondo
`colorScheme.secondaryContainer`, ícono en `colorScheme.onSecondaryContainer` — el mismo acento
terracota que la app ya reserva para "la acción principal" (ver `theme.dart`). Un
`AnimationController` en loop hace un pulso sutil de escala (1.0 ↔ 1.08, ~1.5s, `Curves.easeInOut`)
para que invite a tocarlo. Recibe un `onTap` simple; no sabe nada de tours ni de pasos.

## 3. Cómo se conecta con `MapView`

`_MapViewState` (en `map_view.dart`) es quien arma todo:

1. Crea 3 `GlobalKey`: `_keyMiUbicacion`, `_keyComunaSelector`, `_keyFiltroMateriales`.
2. Le pasa `key: _keyComunaSelector` a `ComunaSelector` y `key: _keyFiltroMateriales` a
   `MaterialFilterButton` — ningún cambio de código en esos dos archivos, cualquier widget acepta
   un `key` desde afuera.
3. Le pasa `_keyMiUbicacion` a `_MapaConPuntos` como un parámetro nuevo del constructor
   (`miUbicacionKey`), que a su vez lo usa como el `key:` del `FloatingActionButton.small` que ya
   existe — hoy ese slot tiene un `Key('boton-mi-ubicacion')` fijo (para tests); un `GlobalKey`
   sirve para ambas cosas a la vez (identidad para tests y medición de posición), así que se
   reemplaza uno por el otro sin quitarle nada a los tests actuales.
4. Agrega el `TourTriggerButton` a `AppBar.actions`, junto al logo.
5. Al tocarlo, arma la `List<TourStep>` con los 5 pasos de la sección 1 (usando las 3 keys) e
   inserta un `TourOverlay` vía `Overlay.of(context).insert(...)`, quitándolo cuando el tour
   termina o se salta.

No se toca ninguna lógica de dominio, `MapViewModel`, ni nada del backend — es 100% presentación,
autocontenido en la capa de UI.

## 4. Manejo de casos donde un paso no aplica

El único paso con riesgo real de no estar disponible es el 2 (botón "mi ubicación"), que solo se
renderiza cuando `mostrarMiUbicacion` es `true` y ya llegó una posición en vivo (ver
`map_view.dart`, condición existente). Si el tour llega a ese paso y
`_keyMiUbicacion.currentContext` es `null`, el `TourOverlay` lo salta automáticamente y pasa
directo al paso 3 — sin mostrar una tarjeta vacía ni un hueco sobre nada. Este chequeo se hace de
nuevo cada vez que se entra a un paso (no una sola vez al abrir el tour), por si el estado cambia
mientras el usuario está en medio del tour.

## 5. Testing

Todo con `flutter_test` estándar, sin mocks de red (la feature no llama al backend):

- El `TourTriggerButton` dispara la inserción del overlay al tocarlo.
- Navegación completa: Siguiente avanza, Atrás retrocede, Atrás está deshabilitado en el paso 1,
  el botón dice "Listo" en el último paso y cierra el overlay al tocarlo.
- Saltar cierra el overlay inmediatamente sin importar en qué paso se esté.
- Tocar el área oscurecida (fuera de la tarjeta) no hace nada.
- Un paso cuyo `anchorKey.currentContext` es `null` se salta automáticamente, sin mostrarse.
- Los 3 `GlobalKey` quedan correctamente asignados a `ComunaSelector`, `MaterialFilterButton` y la
  FAB de ubicación (test de integración liviano sobre `MapView` completo).
