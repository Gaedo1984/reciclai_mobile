# ReciclAI — Mobile

Cliente Flutter de ReciclAI: mapa con los puntos de reciclaje de tu comuna, auto-geolocalización
con selector manual como respaldo. Backend en
[`service-reciclai`](https://github.com/Gaedo1984/service-reciclai).

## Cómo correrlo localmente

Con el backend corriendo local (`uv run uvicorn reciclai.infrastructure.inbound.http.app:app
--reload` desde `service-reciclai`, con `RECICLAI_API_KEY` seteada):

```bash
flutter run \
  --dart-define=RECICLAI_API_KEY=<la-misma-clave-que-RECICLAI_API_KEY-del-backend> \
  --dart-define=RECICLAI_API_BASE_URL=http://localhost:8000
```

**`RECICLAI_API_BASE_URL` según el target:**
- Emulador Android: `http://10.0.2.2:8000` (es el valor por defecto si no se pasa el
  `--dart-define` — `10.0.2.2` es el alias que usa el emulador para referirse al `localhost` de
  la máquina host).
- Simulador iOS / macOS / Linux / Windows / navegador: `http://localhost:8000`.
- Dispositivo físico: la IP de la máquina que corre el backend en la red local (ej.
  `http://192.168.1.X:8000`), nunca `localhost`.

El backend hoy solo corre local — desplegarlo a un hosting real (Railway, Fly.io, etc.) es un
tema aparte, todavía sin resolver.

## Correr los tests

```bash
flutter test
```

Ningún test llama al backend real, ni local ni desplegado — todos usan fakes/mocks (ver
`test/fakes.dart` y los mocks de `http.Client` en `test/data/reciclai_api_client_test.dart`).

## Estructura del proyecto

```
lib/
├── config.dart                    -- lee RECICLAI_API_KEY / RECICLAI_API_BASE_URL
├── data/
│   ├── models/                    -- Comuna, Material, RecyclingPoint, PointsNearbyResult
│   ├── reciclai_api_client.dart   -- consume los 4 endpoints de lectura del backend
│   └── reciclai_api_exception.dart
├── domain/
│   └── location_service.dart      -- envoltorio testeable sobre geolocator
└── ui/features/map/
    ├── view_models/
    │   ├── map_state.dart
    │   └── map_view_model.dart
    └── views/
        ├── map_view.dart
        ├── comuna_picker_sheet.dart
        └── point_details_sheet.dart
```

- `docs/superpowers/specs/` y `docs/superpowers/plans/` — documentos de diseño e implementación.
