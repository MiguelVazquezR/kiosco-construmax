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

## Distribuir el APK (sideload, sin Play Store)

Las tablets del kiosco no pasan por Google Play: se compila un APK firmado y se
instala a mano en cada equipo.

```powershell
# APK firmado universal -> dist\kiosco-construmax-<version>.apk (+ su .sha256)
powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1

# variantes
#   -LockTask              activa el screen pinning (KIOSK_LOCK_TASK=true)
#   -BuildNumber 2         sube el versionCode para actualizar equipos
#   -BaseUrl https://...   apunta a otro backend
#   -SkipBuild             solo copia y verifica el APK ya compilado
#   -NewKeystore           crea la llave de firma la primera vez
```

- **Firma:** `android/app/kiosco-release.jks` + `android/key.properties`, ambos
  fuera de git. Respáldalos en un lugar seguro: todas las actualizaciones deben
  firmarse con la misma llave o Android las rechaza
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) y hay que desinstalar la app.
- **Universal:** el APK incluye `arm64-v8a`, `armeabi-v7a` y `x86_64` (~50 MB),
  así que el mismo archivo sirve para cualquier tablet.
- **URL grabada en el build:** `KIOSK_BASE_URL` queda dentro del binario
  (por defecto `https://erp.construmax-occidente.com/api/v1/kiosk`). Si cambia
  el servidor hay que recompilar y volver a repartir el archivo.
- **Migración desde el APK de pruebas:** los equipos que ya traen el build
  anterior (firmado con la llave de *debug*) deben desinstalarlo primero; al
  cambiar de firma también cambia el `device_key` (android id) y el backend los
  registra como dispositivos nuevos.

Instalación en cada tablet: copiar el `.apk` al equipo, habilitar
*Ajustes → Seguridad → Instalar apps desconocidas* para el explorador de
archivos, abrir el archivo e instalar (Play Protect pedirá *Instalar de todos
modos*). Después conceder permisos de cámara y ubicación.

## Permisos Android

Cámara, ubicación (`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`), internet
y estado de red. La actividad es `singleTask` y el botón atrás está bloqueado
(`PopScope`). `MainActivity.kt` expone el canal `com.example.kiosco/kiosk`
(`startLockTask`, `stopLockTask`, `bringToFront`).

## Probar en tablet física contra Laravel Herd (túnel USB)

El sitio de Herd (`https://construmax.test`) solo escucha en `127.0.0.1:443` y
responde 404 si el `Host` no coincide, así que `adb reverse` por sí solo no
alcanza. El flujo usa un proxy mínimo (`tool/dev_proxy.dart`) que convierte HTTP
local en HTTPS con el `Host`/SNI correctos.

1. Conecta la tablet por USB y acepta la depuración.

2. Abre el túnel (proxy + `adb reverse`). Deja la ventana abierta mientras
   pruebes:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\dev_tunnel.ps1
   ```

   Termina con `GET /api/v1/kiosk/ping -> HTTP/1.1 200 OK` y deja el log en
   `%TEMP%\kiosco-proxy.log`.

3. Compila e instala apuntando al túnel (release arm64 por defecto, porque el
   APK debug no cabe en tablets con poco espacio):

   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\dev_install.ps1
   # solo instalar el APK ya compilado:
   powershell -ExecutionPolicy Bypass -File tool\dev_install.ps1 -SkipBuild
   # APK debug (perfilado / hot reload):
   powershell -ExecutionPolicy Bypass -File tool\dev_install.ps1 -DebugBuild
   ```

   La URL compilada es `http://localhost:8001/api/v1/kiosk`; el
   `network_security_config.xml` permite texto claro solo para
   `localhost`/`127.0.0.1`/`10.0.2.2`.

4. Requisitos en el backend para que el kiosco quede operativo:

   - Migraciones al día (`php artisan migrate`): sin
     `attendance_devices.fingerprint_hash` el `POST /bootstrap` devuelve 500.
   - `payroll_settings.kiosk_employee_number_enabled` en `true`: si no, la app
     muestra "Sin método de registro". El fichaje por rostro solo aparece cuando
     el proveedor biométrico está configurado.

5. En HyperOS/MIUI hace falta activar **Opciones de desarrollador → Instalar vía
   USB** para que `adb install` no falle con `INSTALL_FAILED_USER_RESTRICTED`, y
   los permisos de cámara/ubicación se conceden a mano en la tablet (`pm grant`
   está bloqueado por el sistema).

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
