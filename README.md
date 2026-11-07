# Kiosco de asistencia · Construmax

App Flutter (Android) que se instala en una tablet en modo kiosco para que los
colaboradores registren su fichaje. Abre directamente en la pantalla de
fichaje: reloj, selector de tipo de fichaje y luego identificación por rostro o
por número de empleado. No hay login ni navegación: el único estado bloqueante
es "servidor inalcanzable".

## Flujo

1. `checking` → `GET /ping` + `POST /bootstrap` (identidad del dispositivo).
2. `ready` → el colaborador elige el tipo de fichaje (Entrada, Salida, …).
3. Elige método: **rostro** (preview de cámara + `Capturar`) o **número de
   empleado** (teclado en pantalla).
4. Se pide un fix GPS obligatorio, se envía el fichaje y se muestra el overlay
   de éxito (`Registro exitoso`, nombre, tipo y hora) que se cierra solo.
5. `Cancelar` (cámara o teclado) o `Cambiar tipo` regresan a la vista
   "En espera".
6. Si el servidor no responde → vista de error con `Reintentar` y reintento
   automático cada `unreachableRetryInterval`.

## Backend esperado (Laravel)

Base: `KIOSK_BASE_URL` (por defecto `http://10.0.2.2:8000/api/v1/kiosk`, el
host del emulador). Todas las respuestas son JSON.

| Método | Ruta | Cuerpo | Respuesta |
| --- | --- | --- | --- |
| `GET` | `/ping` | – | `{ "server_time": "…", "device": { "id", "name", "location" } }` |
| `POST` | `/bootstrap` | `device_key`, `device_name` | `{ "device": {…}, "punchTypes": { "check_in": "Entrada", … }, "faceRecognitionEnabled": true, "employeeNumberEnabled": true, "appName": "Construmax", "server_time", "timezone" }` |
| `POST` | `/punch` | `employee_number`, `type`, `latitude`, `longitude`, `location_accuracy`, `device_key`, `device_name`, `photo` (opcional) | `{ "user_name", "employee_number", "type", "type_label", "punched_at": "HH:mm", "date_label": "dd/MM/yyyy", "suggested_next", "suggested_next_label" }` |
| `POST` | `/face-punch` | `type`, `photo` (base64 sin prefijo), `latitude`, `longitude`, `location_accuracy`, `device_key`, `device_name` | igual que `/punch`, más `similarity` (0-100) |

Errores: Laravel `422 { "message", "errors": { "employee_number": ["…"] } }`,
`429` para rate limit. El kiosco muestra el primer mensaje del campo más
específico (`employee_number`, `face`, `photo`, `user`, `type`, `latitude`,
`longitude`).

## Configuración de compilación

```bash
flutter build apk --release \
  --dart-define=KIOSK_BASE_URL=https://erp.example.com/api/v1/kiosk \
  --dart-define=KIOSK_LOCK_TASK=true
```

- `KIOSK_BASE_URL`: raíz del API (sin `/` final). En debug se permite HTTP en
  claro (`android/app/src/debug/AndroidManifest.xml`).
- `KIOSK_LOCK_TASK=true`: intenta entrar en *screen pinning* / lock task. En
  tablets sin *device owner* Android puede pedir confirmación manual; sin el
  flag la app nunca lo intenta.

## Permisos Android

Cámara, ubicación (`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`), internet
y estado de red. La actividad es `singleTask` y el botón atrás está bloqueado
(`PopScope`). `MainActivity.kt` expone el canal `com.example.kiosco/kiosk`
(`startLockTask`, `stopLockTask`, `bringToFront`).

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d android
```

Estructura:

```
lib/
  config/       KioskConfig (base URL y tiempos) + KioskTimings
  data/         KioskApi (abstracta) + DioKioskApi + modelos
  services/     identidad del dispositivo, GPS, cámara, codificador de foto,
                bloqueo de kiosco
  state/        KioskController (máquina de estados y envío de fichajes)
  ui/           KioskScreen + widgets (reloj, grid de tipos, selector de método,
                teclado, cámara, overlay de éxito, banner de error)
test/           unitarias de modelos/API/controlador y widget tests con fakes
```

Los tests no tocan la red ni los canales de plataforma: usan `FakeKioskApi`,
`FakeFaceCamera`, `FakeLocationService` y `FakeIdentityService`
(`test/support/`), y `KioskTimings` para acelerar los temporizadores.
