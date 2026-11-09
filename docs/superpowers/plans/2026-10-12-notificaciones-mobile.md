# Módulo de notificaciones (mobile) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar la campana de notificaciones a la app mobile: ícono con
punto rojo en el `AppBar`, una hoja con las últimas notificaciones (o
todas, bajo demanda), un modal de detalle con soporte de links estilo
Markdown en el cuerpo, y persistencia local (no en el servidor) de qué
notificaciones ya se leyeron.

**Architecture:** Un `NotificacionesViewModel` (`ChangeNotifier`) propio,
separado de `MapViewModel` — trae la lista desde el backend (ya
implementado y en producción, ver spec) y guarda el set de ids leídos en
`SharedPreferences`. Tres widgets de presentación nuevos (`CampanaNotificaciones`,
`HojaNotificaciones`, `DetalleNotificacionModal`) más un widget reusable
(`TextoConLinks`) para los links del cuerpo. Reusa `FloatingSheetCard` y
`BotonCerrarHoja` ya existentes (mismo patrón visual que el resto de las
hojas de la app) y el `Badge`/`Scrollbar` nativos de Material — nada hecho
a mano para esos dos.

**Tech Stack:** Flutter/Dart, `http` (ya usado por `ReciclaiApiClient`),
`shared_preferences` (dependencia nueva de este plan), `url_launcher` (ya
instalado), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-12-notificaciones-diseno.md`
(este plan implementa solo la sección "Mobile" — la sección "Backend" ya
está implementada, revisada y en `origin/develop` del repo `service-reciclai`).

## Global Constraints

- Sin ningún `Timer` ni polling en segundo plano: `cargar()` se llama una
  sola vez al abrir la app (`MapView.initState`) y de nuevo cada vez que
  se toca la campana — nunca en un ciclo recurrente.
- El estado de "leído" es 100% local (`SharedPreferences`) — nunca se
  envía al backend, que no tiene ninguna columna para eso.
- La hoja y el modal se cierran **solo** con su propia X: `PopScope(canPop:
  false)` en ambos, más `isDismissible: false, enableDrag: false` en la
  hoja y `barrierDismissible: false` en el modal.
- Tope de carga fijo: `obtenerNotificaciones(limite: 50)` — sin
  paginación (YAGNI; si algún día se necesita más, se agrega después).
- Links en el cuerpo: solo el formato Markdown `[texto](url)`, vía el
  regex `\[([^\]]+)\]\((https?://[^\s)]+)\)` — reusa `url_launcher`, ya
  instalado, no agrega una dependencia nueva para esto.
- `notificacionesViewModel` es un parámetro **opcional** (nullable, sin
  `required`) en `SplashView` y `MapView`, no uno nuevo obligatorio. Hay
  ~52 construcciones de `MapView(...)` en `map_view_test.dart` que no
  tienen relación con esta feature — hacerlo `required` forzaría tocar
  las 52 sin necesidad. Con el parámetro en `null` (su default), la
  campana simplemente no se muestra — mismo comportamiento exacto que
  hoy, sin esta feature. `main.dart` (código de producción) siempre
  construye uno real.
- El endpoint del backend (`GET /notificaciones`) ya existe, ya tiene su
  propia `X-API-Key`, llave de lectura, circuit breaker y está en
  `origin/develop` de `service-reciclai` — este plan no lo toca.

## Review Focus

- `marcarLeida(id)` debe persistir de verdad entre instancias del
  `ViewModel` (no solo en memoria) — una instancia nueva, con el mismo
  `SharedPreferences`, debe seguir viendo esa notificación como leída.
- Tocar una notificación que ya está marcada como leída (otra vez) no
  debe fallar ni duplicar su id en lo persistido.
- Con **exactamente** 5 notificaciones, "Mostrar todas" no debe aparecer
  — el corte es estrictamente `> 5`, no `>= 5`.
- Un link malformado (`[texto](no-es-url)`, sin `http://`/`https://`)
  debe mostrarse literal, con los corchetes, sin intentar abrir nada — y
  sin romper el resto del parseo del texto.
- Un fallo de `obtenerNotificaciones()` no debe lanzar una excepción sin
  capturar, y debe dejar `hayNoLeidas`/`notificaciones` en el último
  estado válido que ya tenían (no vaciarlos ni dejarlos a medias).

---

### Task 1: Modelo `Notificacion`, `ReciclaiApiClient.obtenerNotificaciones` y el fake de pruebas

**Files:**
- Create: `lib/data/models/notificacion.dart`
- Modify: `lib/data/reciclai_api_client.dart`
- Modify: `test/fakes.dart`
- Test: `test/data/models/notificacion_test.dart`
- Test: `test/data/reciclai_api_client_test.dart` (agregar casos)

**Interfaces:**
- Produces: `Notificacion` (`id: String`, `titulo: String`, `texto:
  String`, `creadaEn: DateTime`), con `Notificacion.fromJson`;
  `ReciclaiApiClient.obtenerNotificaciones({int limite = 50}) ->
  Future<List<Notificacion>>`; en `ApiClientFalso`
  (`test/fakes.dart`): constructor params `notificaciones` (`List<Notificacion>`,
  default `const []`), `excepcionNotificaciones` (`ReciclaiApiException?`),
  `notificacionesPorLlamada` (`List<Notificacion> Function(int
  numeroDeLlamada)?`), y el contador público
  `vecesLlamadoObtenerNotificaciones` — todo consumido por la Task 2 (y
  las que siguen) para simular el backend en los tests del ViewModel y
  los widgets.

- [ ] **Step 1: Escribir el test que falla, del modelo**

Crear `test/data/models/notificacion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';

void main() {
  test('Notificacion.fromJson parsea los 4 campos del backend', () {
    final json = {
      'id': 'abc-123',
      'titulo': 'Nueva versión disponible',
      'texto': 'Ya podés buscar por 3, 5 o 7 km.',
      'creada_en': '2026-10-12T15:30:00+00:00',
    };

    final notificacion = Notificacion.fromJson(json);

    expect(notificacion.id, 'abc-123');
    expect(notificacion.titulo, 'Nueva versión disponible');
    expect(notificacion.texto, 'Ya podés buscar por 3, 5 o 7 km.');
    expect(notificacion.creadaEn, DateTime.parse('2026-10-12T15:30:00+00:00'));
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/data/models/notificacion_test.dart`
Expected: FAIL — no existe `lib/data/models/notificacion.dart`.

- [ ] **Step 3: Crear el modelo**

Crear `lib/data/models/notificacion.dart`:

```dart
class Notificacion {
  const Notificacion({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.creadaEn,
  });

  final String id;
  final String titulo;
  final String texto;
  final DateTime creadaEn;

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      texto: json['texto'] as String,
      creadaEn: DateTime.parse(json['creada_en'] as String),
    );
  }
}
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/data/models/notificacion_test.dart`
Expected: PASS.

- [ ] **Step 5: Escribir los tests que fallan, del cliente HTTP**

En `test/data/reciclai_api_client_test.dart`, agregar (mismo archivo,
mismo patrón `_ClienteFalso`/`_respuestaJson` ya definido arriba en el
archivo — no se repite aquí):

```dart
  test('obtenerNotificaciones manda el limite como query param y parsea la lista', () async {
    final cliente = _ClienteFalso((request) {
      expect(request.url.queryParameters['limite'], '50');
      return _respuestaJson(200, [
        {
          'id': 'n1',
          'titulo': 'Aviso',
          'texto': 'Cuerpo',
          'creada_en': '2026-10-12T15:30:00+00:00',
        },
      ]);
    });
    final api = ReciclaiApiClient(client: cliente);

    final notificaciones = await api.obtenerNotificaciones();

    expect(notificaciones, hasLength(1));
    expect(notificaciones.first.titulo, 'Aviso');
  });

  test('obtenerNotificaciones respeta un limite distinto al default', () async {
    final cliente = _ClienteFalso((request) {
      expect(request.url.queryParameters['limite'], '5');
      return _respuestaJson(200, []);
    });
    final api = ReciclaiApiClient(client: cliente);

    await api.obtenerNotificaciones(limite: 5);
  });
```

Agregar `import 'package:reciclai_mobile/data/models/notificacion.dart';`
al bloque de imports existente del archivo.

- [ ] **Step 6: Correr los tests y verificar que fallan**

Run: `flutter test test/data/reciclai_api_client_test.dart`
Expected: FAIL — `obtenerNotificaciones` no existe en `ReciclaiApiClient`.

- [ ] **Step 7: Agregar el método al cliente HTTP**

En `lib/data/reciclai_api_client.dart`, agregar
`import 'models/notificacion.dart';` al bloque de imports existente, y
el método (junto a los demás `obtener...`, mismo patrón de `_get` que ya
usa `obtenerComunas`):

```dart
  Future<List<Notificacion>> obtenerNotificaciones({int limite = 50}) async {
    final cuerpo = await _get('/notificaciones', queryParameters: {'limite': '$limite'});
    try {
      return (cuerpo as List<dynamic>)
          .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ReciclaiApiException('respuesta con forma inesperada: $e');
    }
  }
```

- [ ] **Step 8: Correr los tests y verificar que pasan**

Run: `flutter test test/data/reciclai_api_client_test.dart`
Expected: PASS — todos los tests del archivo, incluidos los 2 nuevos.

- [ ] **Step 9: Extender el fake de `ApiClientFalso` para notificaciones**

En `test/fakes.dart`, agregar
`import 'package:reciclai_mobile/data/models/notificacion.dart';` al
bloque de imports existente. En el constructor de `ApiClientFalso`,
agregar a la lista de parámetros nombrados ya existente:

```dart
    this.notificaciones = const [],
    this.excepcionNotificaciones,
    this.notificacionesPorLlamada,
```

Y, junto a los demás campos finales de la clase:

```dart
  final List<Notificacion> notificaciones;
  final ReciclaiApiException? excepcionNotificaciones;

  /// Igual que `resultadoCercanosPorLlamada`, para `obtenerNotificaciones` --
  /// recibe el numero de llamada (1, 2, 3...) y puede devolver una lista
  /// distinta por llamada, o lanzar. Para simular que una carga posterior
  /// (ej. al tocar la campana otra vez) falla sin afectar lo ya cargado.
  final List<Notificacion> Function(int numeroDeLlamada)? notificacionesPorLlamada;

  int vecesLlamadoObtenerNotificaciones = 0;

  @override
  Future<List<Notificacion>> obtenerNotificaciones({int limite = 50}) async {
    vecesLlamadoObtenerNotificaciones++;
    final porLlamada = notificacionesPorLlamada;
    if (porLlamada != null) return porLlamada(vecesLlamadoObtenerNotificaciones);
    if (excepcionNotificaciones != null) throw excepcionNotificaciones!;
    return notificaciones;
  }
```

- [ ] **Step 10: Correr la suite completa y verificar que pasa**

Run: `flutter test`
Expected: PASS — todo el proyecto (el fake ahora implementa el método
nuevo que pide la interfaz `ReciclaiApiClient`; sin este paso, el
proyecto no compila).

- [ ] **Step 11: Commit**

```bash
git add lib/data/models/notificacion.dart lib/data/reciclai_api_client.dart test/fakes.dart test/data/models/notificacion_test.dart test/data/reciclai_api_client_test.dart
git commit -m "feat: modelo Notificacion y ReciclaiApiClient.obtenerNotificaciones"
```

---

### Task 2: Dependencia `shared_preferences` y `NotificacionesViewModel`

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/ui/features/notificaciones/view_models/notificaciones_view_model.dart`
- Test: `test/ui/features/notificaciones/view_models/notificaciones_view_model_test.dart`

**Interfaces:**
- Consumes (de Task 1): `Notificacion`, `ApiClientFalso` (con
  `notificaciones`/`excepcionNotificaciones`/`notificacionesPorLlamada`).
- Produces: `NotificacionesViewModel` (`ChangeNotifier`) con
  `List<Notificacion> get notificaciones`, `bool get hayNoLeidas`, `bool
  estaLeida(String id)`, `Future<void> cargar()`, `Future<void>
  marcarLeida(String id)` — consumido por las Tasks 4 y 5.

- [ ] **Step 1: Agregar la dependencia**

En `pubspec.yaml`, agregar bajo `dependencies:` (junto a `url_launcher`,
mismo bloque):

```yaml
  shared_preferences: ^2.5.6
```

Run: `flutter pub get`
Expected: resuelve sin conflictos de versión.

- [ ] **Step 2: Escribir los tests que fallan**

Crear `test/ui/features/notificaciones/view_models/notificaciones_view_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fakes.dart';

Notificacion _n(String id) =>
    Notificacion(id: id, titulo: 'Aviso $id', texto: 'Cuerpo', creadaEn: DateTime(2026, 10, 12));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hayNoLeidas es false antes de cargar (lista vacia)', () {
    final viewModel = NotificacionesViewModel(apiClient: ApiClientFalso());

    expect(viewModel.hayNoLeidas, isFalse);
    expect(viewModel.notificaciones, isEmpty);
  });

  test('tras cargar con notificaciones nuevas y nada leido, hayNoLeidas es true', () async {
    final viewModel = NotificacionesViewModel(apiClient: ApiClientFalso(notificaciones: [_n('n1')]));

    await viewModel.cargar();

    expect(viewModel.hayNoLeidas, isTrue);
    expect(viewModel.notificaciones, hasLength(1));
  });

  test('marcarLeida saca la notificacion de "no leidas"; con todas leidas, hayNoLeidas es false',
      () async {
    final viewModel = NotificacionesViewModel(apiClient: ApiClientFalso(notificaciones: [_n('n1')]));
    await viewModel.cargar();
    expect(viewModel.hayNoLeidas, isTrue);

    await viewModel.marcarLeida('n1');

    expect(viewModel.estaLeida('n1'), isTrue);
    expect(viewModel.hayNoLeidas, isFalse);
  });

  test('marcarLeida persiste entre instancias distintas del ViewModel (Review Focus)', () async {
    final apiClient = ApiClientFalso(notificaciones: [_n('n1')]);
    final viewModel1 = NotificacionesViewModel(apiClient: apiClient);
    await viewModel1.cargar();
    await viewModel1.marcarLeida('n1');

    final viewModel2 = NotificacionesViewModel(apiClient: apiClient);
    await viewModel2.cargar();

    expect(viewModel2.estaLeida('n1'), isTrue);
    expect(viewModel2.hayNoLeidas, isFalse);
  });

  test('marcarLeida en una notificacion ya leida no falla ni la duplica (Review Focus)', () async {
    final viewModel = NotificacionesViewModel(apiClient: ApiClientFalso(notificaciones: [_n('n1')]));
    await viewModel.cargar();
    await viewModel.marcarLeida('n1');

    await viewModel.marcarLeida('n1');

    expect(viewModel.estaLeida('n1'), isTrue);
    expect(viewModel.hayNoLeidas, isFalse);
  });

  test(
      'un fallo de obtenerNotificaciones en una carga posterior no lanza y mantiene lo que ya '
      'habia (Review Focus)', () async {
    final apiClient = ApiClientFalso(
      notificacionesPorLlamada: (numeroDeLlamada) {
        if (numeroDeLlamada == 1) return [_n('n1')];
        throw const ReciclaiApiException('fallo simulado');
      },
    );
    final viewModel = NotificacionesViewModel(apiClient: apiClient);
    await viewModel.cargar();
    expect(viewModel.notificaciones, hasLength(1));
    expect(viewModel.hayNoLeidas, isTrue);

    await viewModel.cargar();

    expect(viewModel.notificaciones, hasLength(1));
    expect(viewModel.hayNoLeidas, isTrue);
  });
}
```

- [ ] **Step 3: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/notificaciones/view_models/notificaciones_view_model_test.dart`
Expected: FAIL — no existe `NotificacionesViewModel`.

- [ ] **Step 4: Crear el ViewModel**

Crear `lib/ui/features/notificaciones/view_models/notificaciones_view_model.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/models/notificacion.dart';
import '../../../../data/reciclai_api_client.dart';

const _claveIdsLeidas = 'notificaciones_leidas';

class NotificacionesViewModel extends ChangeNotifier {
  NotificacionesViewModel({required ReciclaiApiClient apiClient}) : _apiClient = apiClient;

  final ReciclaiApiClient _apiClient;

  List<Notificacion> _notificaciones = [];
  List<Notificacion> get notificaciones => _notificaciones;

  Set<String> _idsLeidas = {};
  bool _idsLeidasCargadas = false;

  bool get hayNoLeidas => _notificaciones.any((n) => !_idsLeidas.contains(n.id));

  bool estaLeida(String id) => _idsLeidas.contains(id);

  /// Sin ningun Timer -- se llama una vez al abrir la app y de nuevo cada
  /// vez que se toca la campana (ver UI), nunca en un ciclo recurrente.
  Future<void> cargar() async {
    if (!_idsLeidasCargadas) {
      await _cargarIdsLeidas();
      _idsLeidasCargadas = true;
    }
    try {
      _notificaciones = await _apiClient.obtenerNotificaciones();
    } catch (_) {
      // Fallo silencioso -- igual que comunas/materiales en MapViewModel:
      // la campana simplemente no se actualiza hasta una carga posterior
      // exitosa, sin bloquear el resto de la app ni dejar un estado a medias.
    }
    notifyListeners();
  }

  Future<void> marcarLeida(String id) async {
    if (_idsLeidas.contains(id)) return;
    _idsLeidas = {..._idsLeidas, id};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveIdsLeidas, jsonEncode(_idsLeidas.toList()));
  }

  Future<void> _cargarIdsLeidas() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_claveIdsLeidas);
    if (guardado == null) return;
    try {
      _idsLeidas = (jsonDecode(guardado) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      // Dato corrupto (no deberia pasar -- solo esta app lo escribe) -- se
      // trata como "nada leido" en vez de lanzar y bloquear la campana.
    }
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/notificaciones/view_models/notificaciones_view_model_test.dart`
Expected: PASS — los 6 tests.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/ui/features/notificaciones/view_models/notificaciones_view_model.dart test/ui/features/notificaciones/view_models/notificaciones_view_model_test.dart
git commit -m "feat: dependencia shared_preferences y NotificacionesViewModel"
```

---

### Task 3: Widget `TextoConLinks` (links estilo Markdown en el cuerpo)

**Files:**
- Create: `lib/ui/features/notificaciones/views/texto_con_links.dart`
- Test: `test/ui/features/notificaciones/views/texto_con_links_test.dart`

**Interfaces:**
- Produces: `TextoConLinks extends StatelessWidget` (`required this.texto`)
  — consumido por la Task 4 (`DetalleNotificacionModal`).

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/ui/features/notificaciones/views/texto_con_links_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/texto_con_links.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

List<TextSpan> _hijos(WidgetTester tester) {
  final richText = tester.widget<RichText>(find.byType(RichText).first);
  final raiz = richText.text as TextSpan;
  return (raiz.children ?? []).cast<TextSpan>();
}

void main() {
  testWidgets('texto sin links se muestra como un solo TextSpan plano', (tester) async {
    await tester.pumpWidget(_envolver(const TextoConLinks(texto: 'Hola mundo')));

    final hijos = _hijos(tester);
    expect(hijos, hasLength(1));
    expect(hijos.first.text, 'Hola mundo');
    expect(hijos.first.recognizer, isNull);
  });

  testWidgets('un link muestra el texto visible subrayado y tocable', (tester) async {
    await tester.pumpWidget(
      _envolver(const TextoConLinks(texto: 'hola [aquí](https://reciclai.cl) mundo')),
    );

    final hijos = _hijos(tester);
    expect(hijos.map((s) => s.text), ['hola ', 'aquí', ' mundo']);
    expect(hijos[0].recognizer, isNull);
    expect(hijos[1].recognizer, isA<TapGestureRecognizer>());
    expect(hijos[1].style?.decoration, TextDecoration.underline);
    expect(hijos[2].recognizer, isNull);
  });

  testWidgets('dos links separa los cinco segmentos correctos', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const TextoConLinks(texto: 'ver [uno](https://a.cl) y [dos](https://b.cl) ya'),
      ),
    );

    final hijos = _hijos(tester);
    expect(hijos.map((s) => s.text), ['ver ', 'uno', ' y ', 'dos', ' ya']);
    expect(hijos[1].recognizer, isNotNull);
    expect(hijos[3].recognizer, isNotNull);
  });

  testWidgets('tocar el link llama a launchUrl con el url correcto', (tester) async {
    final urlLauncherFalso = UrlLauncherPlatformFalso();
    UrlLauncherPlatform.instance = urlLauncherFalso;
    await tester.pumpWidget(
      _envolver(const TextoConLinks(texto: 'ir [aquí](https://reciclai.cl/aviso)')),
    );

    final link = _hijos(tester)[1];
    (link.recognizer as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(urlLauncherFalso.urlsLanzadas, ['https://reciclai.cl/aviso']);
  });

  testWidgets(
      'un link malformado se muestra literal, con los corchetes, sin intentar abrir nada '
      '(Review Focus)', (tester) async {
    await tester.pumpWidget(
      _envolver(const TextoConLinks(texto: 'ver [texto](no-es-url) aca')),
    );

    final hijos = _hijos(tester);
    expect(hijos, hasLength(1));
    expect(hijos.first.text, 'ver [texto](no-es-url) aca');
    expect(hijos.first.recognizer, isNull);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/notificaciones/views/texto_con_links_test.dart`
Expected: FAIL — no existe `TextoConLinks`.

- [ ] **Step 3: Crear el widget**

Crear `lib/ui/features/notificaciones/views/texto_con_links.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _regexLinks = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)');

/// Links estilo Markdown (`[texto](url)`) dentro del cuerpo de una
/// notificación -- quien escribe la notificación (vía el POST desde
/// GitHub Actions) no necesita pegar el URL completo, que muchas veces es
/// largo. Un patrón que no matchea el regex (ej. sin `http://`/`https://`)
/// se muestra literal, con los corchetes -- el regex en si ya es la
/// validación, no hace falta un manejo de error aparte.
class TextoConLinks extends StatelessWidget {
  const TextoConLinks({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var ultimoIndice = 0;
    for (final match in _regexLinks.allMatches(texto)) {
      if (match.start > ultimoIndice) {
        spans.add(TextSpan(text: texto.substring(ultimoIndice, match.start)));
      }
      final textoVisible = match.group(1)!;
      final url = match.group(2)!;
      spans.add(
        TextSpan(
          text: textoVisible,
          style: TextStyle(color: colores.primary, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      );
      ultimoIndice = match.end;
    }
    if (ultimoIndice < texto.length || spans.isEmpty) {
      spans.add(TextSpan(text: texto.substring(ultimoIndice)));
    }
    return Text.rich(TextSpan(children: spans));
  }
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/notificaciones/views/texto_con_links_test.dart`
Expected: PASS — los 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/notificaciones/views/texto_con_links.dart test/ui/features/notificaciones/views/texto_con_links_test.dart
git commit -m "feat: widget TextoConLinks (links estilo Markdown en notificaciones)"
```

---

### Task 4: Modal de detalle de notificación

**Files:**
- Create: `lib/ui/features/notificaciones/views/detalle_notificacion_modal.dart`
- Test: `test/ui/features/notificaciones/views/detalle_notificacion_modal_test.dart`

**Interfaces:**
- Consumes (de Task 1): `Notificacion`.
- Consumes (de Task 3): `TextoConLinks`.
- Produces: `DetalleNotificacionModal extends StatelessWidget` (`required
  this.notificacion`) — consumido por la Task 5 (`HojaNotificaciones`).

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/ui/features/notificaciones/views/detalle_notificacion_modal_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/detalle_notificacion_modal.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/texto_con_links.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

Notificacion _n({String texto = 'Cuerpo'}) => Notificacion(
      id: 'n1',
      titulo: 'Título del aviso',
      texto: texto,
      creadaEn: DateTime(2026, 10, 12),
    );

void main() {
  testWidgets('muestra el titulo y el texto de la notificacion', (tester) async {
    await tester.pumpWidget(_envolver(DetalleNotificacionModal(notificacion: _n())));

    expect(find.text('Título del aviso'), findsOneWidget);
    expect(find.text('Cuerpo'), findsOneWidget);
  });

  testWidgets('no se cierra con el boton atras del sistema', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(body: DetalleNotificacionModal(notificacion: _n())),
      ),
    );

    // maybePop() en si mismo no confirma si la ruta cambio o no (delega la
    // decision al PopScope) -- lo que importa observar es el efecto real:
    // el contenido sigue en pantalla.
    await navigatorKey.currentState!.maybePop();
    await tester.pump();

    expect(find.text('Título del aviso'), findsOneWidget);
  });

  testWidgets('la X cierra el modal', (tester) async {
    await tester.pumpWidget(
      _envolver(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => DetalleNotificacionModal(notificacion: _n()),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Título del aviso'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Título del aviso'), findsNothing);
  });

  testWidgets('el texto del cuerpo soporta links estilo Markdown', (tester) async {
    await tester.pumpWidget(
      _envolver(DetalleNotificacionModal(notificacion: _n(texto: 'Ver [aquí](https://reciclai.cl)'))),
    );

    // El header (titulo) tambien es un Text, que internamente tambien es
    // un RichText -- find.byType(RichText).first no distingue cual es
    // cual. Hay que acotar la busqueda al RichText QUE ESTA DENTRO de
    // TextoConLinks especificamente.
    final richText = tester.widget<RichText>(
      find.descendant(of: find.byType(TextoConLinks), matching: find.byType(RichText)).first,
    );
    final raiz = richText.text as TextSpan;
    final hijos = (raiz.children ?? []).cast<TextSpan>();
    expect(hijos.any((s) => s.text == 'aquí' && s.recognizer != null), isTrue);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/notificaciones/views/detalle_notificacion_modal_test.dart`
Expected: FAIL — no existe `DetalleNotificacionModal`.

- [ ] **Step 3: Crear el widget**

Crear `lib/ui/features/notificaciones/views/detalle_notificacion_modal.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../data/models/notificacion.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import 'texto_con_links.dart';

/// Mismo criterio que la hoja (`HojaNotificaciones`): solo la X cierra,
/// ni el boton atras ni tocar afuera -- una notificacion que el usuario
/// ya abrio no deberia "perderse" por un gesto accidental antes de
/// terminar de leerla.
class DetalleNotificacionModal extends StatelessWidget {
  const DetalleNotificacionModal({super.key, required this.notificacion});

  final Notificacion notificacion;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(espacioMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(notificacion.titulo, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: espacioSm),
              TextoConLinks(texto: notificacion.texto),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/notificaciones/views/detalle_notificacion_modal_test.dart`
Expected: PASS — los 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/notificaciones/views/detalle_notificacion_modal.dart test/ui/features/notificaciones/views/detalle_notificacion_modal_test.dart
git commit -m "feat: modal de detalle de notificacion"
```

---

### Task 5: Campana y hoja de notificaciones

**Files:**
- Create: `lib/ui/features/notificaciones/views/campana_notificaciones.dart`
- Create: `lib/ui/features/notificaciones/views/hoja_notificaciones.dart`
- Test: `test/ui/features/notificaciones/views/campana_notificaciones_test.dart`

**Interfaces:**
- Consumes (de Task 1): `Notificacion`, `ApiClientFalso`.
- Consumes (de Task 2): `NotificacionesViewModel`.
- Consumes (de Task 4): `DetalleNotificacionModal`.
- Produces: `CampanaNotificaciones extends StatelessWidget` (`required
  this.viewModel`) — consumido por la Task 6 (`MapView`).

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/ui/features/notificaciones/views/campana_notificaciones_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/views/campana_notificaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fakes.dart';

Widget _envolver(Widget child, {GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(navigatorKey: navigatorKey, home: Scaffold(body: child));

Notificacion _n(String id, {String titulo = 'Aviso'}) =>
    Notificacion(id: id, titulo: titulo, texto: 'Cuerpo', creadaEn: DateTime(2026, 10, 12));

Future<NotificacionesViewModel> _viewModelCargado(List<Notificacion> notificaciones) async {
  SharedPreferences.setMockInitialValues({});
  final viewModel = NotificacionesViewModel(apiClient: ApiClientFalso(notificaciones: notificaciones));
  await viewModel.cargar();
  return viewModel;
}

void main() {
  testWidgets('sin notificaciones no leidas, el punto rojo no se muestra', (tester) async {
    final viewModel = await _viewModelCargado([]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('con al menos una no leida, el punto rojo se muestra', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('tocar la campana abre la hoja con las notificaciones', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Primera')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Primera'), findsOneWidget);
  });

  testWidgets('con mas de 5 notificaciones aparece "Mostrar todas"; al tocarlo, se ven todas',
      (tester) async {
    final notificaciones = [for (var i = 0; i < 6; i++) _n('n$i', titulo: 'Aviso $i')];
    final viewModel = await _viewModelCargado(notificaciones);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 5'), findsNothing);
    expect(find.text('Mostrar todas'), findsOneWidget);

    await tester.tap(find.text('Mostrar todas'));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 5'), findsOneWidget);
  });

  testWidgets('con exactamente 5 notificaciones, "Mostrar todas" no aparece (Review Focus)',
      (tester) async {
    final notificaciones = [for (var i = 0; i < 5; i++) _n('n$i', titulo: 'Aviso $i')];
    final viewModel = await _viewModelCargado(notificaciones);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 4'), findsOneWidget);
    expect(find.text('Mostrar todas'), findsNothing);
  });

  testWidgets(
      'una notificacion no leida se ve en negrita con un punto; una leida, sin ninguno de los '
      'dos', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'No leida')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    final titulo = tester.widget<Text>(find.text('No leida'));
    expect(titulo.style?.fontWeight, FontWeight.bold);
    expect(find.byIcon(Icons.circle), findsOneWidget);

    await viewModel.marcarLeida('n1');
    await tester.pump();

    final tituloLeido = tester.widget<Text>(find.text('No leida'));
    expect(tituloLeido.style?.fontWeight, FontWeight.normal);
    expect(find.byIcon(Icons.circle), findsNothing);
  });

  testWidgets('tocar una notificacion abre el modal y la marca como leida sin cerrar la hoja',
      (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Tocame')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tocame'));
    await tester.pumpAndSettle();

    // El modal de detalle (titulo en grande) y la fila de la hoja (ahora
    // leida, sin negrita) coexisten en el arbol -- el modal se dibuja
    // encima, pero la hoja sigue montada debajo.
    expect(find.text('Tocame'), findsAtLeastNWidgets(1));
    expect(viewModel.estaLeida('n1'), isTrue);
  });

  testWidgets('la hoja no se cierra con el boton atras del sistema', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Persiste')]);
    await tester.pumpWidget(
      _envolver(CampanaNotificaciones(viewModel: viewModel), navigatorKey: navigatorKey),
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await navigatorKey.currentState!.maybePop();
    await tester.pump();

    expect(find.text('Persiste'), findsOneWidget);
  });

  testWidgets('la X cierra la hoja', (tester) async {
    final viewModel = await _viewModelCargado([_n('n1', titulo: 'Cerrable')]);
    await tester.pumpWidget(_envolver(CampanaNotificaciones(viewModel: viewModel)));
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Cerrable'), findsNothing);
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/ui/features/notificaciones/views/campana_notificaciones_test.dart`
Expected: FAIL — no existen `CampanaNotificaciones` ni `HojaNotificaciones`.

- [ ] **Step 3: Crear la hoja**

Crear `lib/ui/features/notificaciones/views/hoja_notificaciones.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../data/models/notificacion.dart';
import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../view_models/notificaciones_view_model.dart';
import 'detalle_notificacion_modal.dart';

const _cantidadInicial = 5;

/// Mismo criterio que el modal de detalle: solo la X cierra, ni el boton
/// atras ni tocar afuera (quien la abre, con el bloqueado, confirma que
/// `isDismissible: false`/`enableDrag: false` ya aplicados por
/// `CampanaNotificaciones` al abrirla).
class HojaNotificaciones extends StatefulWidget {
  const HojaNotificaciones({super.key, required this.viewModel});

  final NotificacionesViewModel viewModel;

  @override
  State<HojaNotificaciones> createState() => _HojaNotificacionesState();
}

class _HojaNotificacionesState extends State<HojaNotificaciones> {
  bool _mostrarTodas = false;

  void _abrirDetalle(BuildContext context, Notificacion notificacion) {
    widget.viewModel.marcarLeida(notificacion.id);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DetalleNotificacionModal(notificacion: notificacion),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FloatingSheetCard(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              final todas = widget.viewModel.notificaciones;
              // El corte es estrictamente > 5, no >= 5 -- con exactamente 5
              // no debe aparecer "Mostrar todas" (ver Review Focus del plan).
              final hayMas = !_mostrarTodas && todas.length > _cantidadInicial;
              final mostrar = _mostrarTodas ? todas : todas.take(_cantidadInicial).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Notificaciones', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: espacioMd),
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: mostrar.length + (hayMas ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < mostrar.length) {
                            final notificacion = mostrar[index];
                            final leida = widget.viewModel.estaLeida(notificacion.id);
                            return ListTile(
                              onTap: () => _abrirDetalle(context, notificacion),
                              leading: leida
                                  ? null
                                  : Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              title: Text(
                                notificacion.titulo,
                                style: TextStyle(
                                  fontWeight: leida ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return TextButton(
                            onPressed: () => setState(() => _mostrarTodas = true),
                            child: const Text('Mostrar todas'),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Crear la campana**

Crear `lib/ui/features/notificaciones/views/campana_notificaciones.dart`:

```dart
import 'package:flutter/material.dart';

import '../view_models/notificaciones_view_model.dart';
import 'hoja_notificaciones.dart';

class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key, required this.viewModel});

  final NotificacionesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Badge(
          isLabelVisible: viewModel.hayNoLeidas,
          smallSize: 8,
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _abrir(context),
          ),
        );
      },
    );
  }

  Future<void> _abrir(BuildContext context) async {
    // Refresca contra el backend cada vez que se toca la campana -- sin
    // ningun Timer en segundo plano (ver Global Constraints del plan).
    viewModel.cargar();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaNotificaciones(viewModel: viewModel),
    );
  }
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `flutter test test/ui/features/notificaciones/views/campana_notificaciones_test.dart`
Expected: PASS — los 9 tests.

- [ ] **Step 6: Correr la suite completa**

Run: `flutter test`
Expected: PASS — todo el proyecto.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/features/notificaciones/views/campana_notificaciones.dart lib/ui/features/notificaciones/views/hoja_notificaciones.dart test/ui/features/notificaciones/views/campana_notificaciones_test.dart
git commit -m "feat: campana y hoja de notificaciones"
```

---

### Task 6: Wiring — `main.dart`, `SplashView`, `MapView`

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/ui/features/splash/splash_view.dart`
- Modify: `lib/ui/features/map/views/map_view.dart`
- Test: `test/ui/features/map/views/map_view_test.dart` (agregar un caso)

**Interfaces:**
- Consumes (de Task 2): `NotificacionesViewModel`.
- Consumes (de Task 5): `CampanaNotificaciones`.
- Produces: nada que otra task consume — es el borde final de este plan.

- [ ] **Step 1: Escribir el test que falla**

En `test/ui/features/map/views/map_view_test.dart`, agregar (junto a los
demás `testWidgets`, mismo archivo — no se repiten aquí los ~20 imports
ya existentes; agregar solo los 2 nuevos):

```dart
import 'package:reciclai_mobile/ui/features/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

y el test:

```dart
  testWidgets('con un NotificacionesViewModel, muestra la campana; sin uno, no', (tester) async {
    final viewModel = MapViewModel(
      apiClient: ApiClientFalso(),
      locationService: LocationServiceFalsa(permiso: LocationPermissionStatus.denegado),
    );

    await tester.pumpWidget(
      MaterialApp(home: TickerMode(enabled: false, child: MapView(viewModel: viewModel))),
    );
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);

    SharedPreferences.setMockInitialValues({});
    final notificacionesViewModel = NotificacionesViewModel(apiClient: ApiClientFalso());
    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: MapView(viewModel: viewModel, notificacionesViewModel: notificacionesViewModel),
        ),
      ),
    );

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/ui/features/map/views/map_view_test.dart -N "con un NotificacionesViewModel"`
Expected: FAIL — `MapView` no acepta el parámetro `notificacionesViewModel`.

- [ ] **Step 3: Agregar el parámetro opcional a `MapView`**

En `lib/ui/features/map/views/map_view.dart`, agregar
`import '../../notificaciones/view_models/notificaciones_view_model.dart';`
y `import '../../notificaciones/views/campana_notificaciones.dart';` al
bloque de imports existente.

Cambiar el constructor (línea con `const MapView({super.key, required
this.viewModel, this.iniciarAlMontar = true});`) por:

```dart
  const MapView({
    super.key,
    required this.viewModel,
    this.notificacionesViewModel,
    this.iniciarAlMontar = true,
  });
```

Y agregar el campo (junto a `final MapViewModel viewModel;`):

```dart
  /// Opcional (no `required`): si es null, la campana simplemente no se
  /// muestra -- mismo comportamiento que antes de esta feature. Ver
  /// Global Constraints del plan de notificaciones (evita forzar un
  /// parametro nuevo en las ~50 construcciones de MapView ya existentes
  /// en los tests, que no tienen relacion con esta feature).
  final NotificacionesViewModel? notificacionesViewModel;
```

En `initState` (donde ya está `if (widget.iniciarAlMontar)
widget.viewModel.iniciar();`), agregar debajo, misma indentación:

```dart
    widget.notificacionesViewModel?.cargar();
```

En el `AppBar`, dentro de `actions: [...]` (donde ya está el `Padding`
con `TourTriggerButton`), agregar el nuevo ítem **antes** del existente:

```dart
        actions: [
          if (widget.notificacionesViewModel != null)
            Padding(
              padding: const EdgeInsets.only(right: espacioXs),
              child: CampanaNotificaciones(viewModel: widget.notificacionesViewModel!),
            ),
          Padding(
            padding: const EdgeInsets.only(right: espacioMd),
            child: TourTriggerButton(onTap: _iniciarTour),
          ),
        ],
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/ui/features/map/views/map_view_test.dart -N "con un NotificacionesViewModel"`
Expected: PASS.

- [ ] **Step 5: Correr la suite completa de `map_view_test.dart`**

Run: `flutter test test/ui/features/map/views/map_view_test.dart`
Expected: PASS — todos los tests del archivo, incluidos los ~52 que
construyen `MapView` sin `notificacionesViewModel` (siguen compilando y
pasando sin cambios, porque el parámetro nuevo es opcional).

- [ ] **Step 6: Wiring en `SplashView`**

En `lib/ui/features/splash/splash_view.dart`, agregar
`import '../notificaciones/view_models/notificaciones_view_model.dart';`
al bloque de imports existente.

Cambiar el constructor:
```dart
  const SplashView({super.key, required this.viewModel});

  final MapViewModel viewModel;
```
por:
```dart
  const SplashView({super.key, required this.viewModel, this.notificacionesViewModel});

  final MapViewModel viewModel;
  final NotificacionesViewModel? notificacionesViewModel;
```

Y en `_irAlMapa()`, cambiar:
```dart
        builder: (_) => MapView(viewModel: widget.viewModel, iniciarAlMontar: false),
```
por:
```dart
        builder: (_) => MapView(
          viewModel: widget.viewModel,
          notificacionesViewModel: widget.notificacionesViewModel,
          iniciarAlMontar: false,
        ),
```

- [ ] **Step 7: Wiring en `main.dart`**

En `lib/main.dart`, agregar los imports:
```dart
import 'data/reciclai_api_client.dart';
```
(si no está ya — confirmar antes de duplicar) y
```dart
import 'ui/features/notificaciones/view_models/notificaciones_view_model.dart';
```

Cambiar `build()`:
```dart
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReciclAI',
      theme: construirTemaReciclai(Brightness.light),
      darkTheme: construirTemaReciclai(Brightness.dark),
      themeMode: ThemeMode.system,
      home: SplashView(
        viewModel: MapViewModel(
          apiClient: ReciclaiApiClient(),
          locationService: LocationService(),
        ),
      ),
    );
  }
```
por:
```dart
  @override
  Widget build(BuildContext context) {
    // Un solo ReciclaiApiClient compartido -- MapViewModel y
    // NotificacionesViewModel son datos/responsabilidades distintas, pero
    // no hay motivo para dos http.Client separados hablando con el mismo
    // backend.
    final apiClient = ReciclaiApiClient();
    return MaterialApp(
      title: 'ReciclAI',
      theme: construirTemaReciclai(Brightness.light),
      darkTheme: construirTemaReciclai(Brightness.dark),
      themeMode: ThemeMode.system,
      home: SplashView(
        viewModel: MapViewModel(apiClient: apiClient, locationService: LocationService()),
        notificacionesViewModel: NotificacionesViewModel(apiClient: apiClient),
      ),
    );
  }
```

- [ ] **Step 8: Correr la suite completa**

Run: `flutter test`
Expected: PASS — todo el proyecto.

- [ ] **Step 9: Commit**

```bash
git add lib/main.dart lib/ui/features/splash/splash_view.dart lib/ui/features/map/views/map_view.dart test/ui/features/map/views/map_view_test.dart
git commit -m "feat: wiring de notificaciones en main.dart, SplashView y MapView"
```
