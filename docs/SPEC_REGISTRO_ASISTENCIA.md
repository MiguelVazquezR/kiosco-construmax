# Spec · Registro de asistencia desde el kiosco — cambios para la app Android

> **Para quién:** agente o desarrollador que mantiene la app Flutter del kiosco
> (`C:\Users\windows 11\Desktop\Apps moviles\construmax\kiosco`).
>
> **Origen:** commit `a4b65c2` ("Kiosco", 12-nov-2026) del repo web `Construmax`.
> Ese commit reescribió el flujo de fichaje del kiosco web, pero **no** actualizó
> la API que consume la app Android, creada en el commit anterior `443efd2`
> ("Preparación para app android de kiosco", 7-nov-2026). Este documento describe
> **lo que la app debe hacer ahora** y **los cambios de backend necesarios** para
> que ese contrato exista.
>
> **Alcance:** app Flutter + API/backend. No cambia el modelo de datos ni el
> endurecimiento del kiosco (lock task, wakelock, permisos, `unreachable`).

---

## 0. Resumen de lo que cambia

| # | Cambio | Dónde | Imprescindible |
|---|--------|-------|----------------|
| 1 | El servidor aplica la **secuencia diaria** de fichajes y rechaza con `422 attendance_punch_not_allowed` + `options[]` | Backend | Sí |
| 2 | La app muestra un **modal "ya registrado"** en lugar de un error genérico o de red | App | Sí |
| 3 | **Overlay bloqueante** "Procesando tu registro…" mientras se envía el fichaje | App | Sí |
| 4 | **Modal de éxito** con el copy nuevo y auto-cierre a los 7 s | App | Sí |
| 5 | Los seis botones de tipo se **atenúan con su motivo** cuando el servidor dice que no están permitidos | App | Recomendado |
| 6 | `ApiError.code` + `PunchNotAllowed` para distinguir el 422 de negocio | App | Sí |
| 7 | La ventana anti-duplicado de ±2 min **se eliminó** (la sustituye la secuencia diaria) | Backend | Ya hecho |

---

## 1. Punto de partida y hueco detectado

### 1.1 Lo que ya tiene la app (contrato de `443efd2`)

`GET /ping`, `POST /bootstrap`, `POST /punch` y `POST /face-punch` funcionan y
están cubiertos por `tests/Feature/Payroll/ApiKioskTest.php`. La app Flutter ya
implementa el flujo completo (`checking → ready → punch → ready`, con
`unreachable`), el GPS obligatorio y el bloqueo del dispositivo.

### 1.2 Lo que cambió en `a4b65c2` y la API todavía no refleja

`app/Actions/Payroll/RegisterAttendancePunchAction.php` ahora llama a
`AttendancePunchPolicy::ensureCanRegister()` **antes** de guardar el fichaje y
lanza `App\Services\Payroll\Exceptions\AttendancePunchNotAllowedException`
cuando el movimiento no sigue la secuencia del día.

`app/Http/Controllers/Api/V1/KioskController.php` (`punch()` en la línea 84,
`facePunch()` en la línea 99) **no captura esa excepción**. Consecuencia
verificada:

* Un segundo fichaje del mismo tipo responde **500** (`{"message":"Server Error"}`
  o HTML si falta `Accept: application/json`).
* `ApiError.fromResponse(500, …)` cae en `_defaultMessage(500)` →
  `"No se pudo conectar con el servidor."` → la app muestra un problema de red
  cuando en realidad el servidor está perfecto.
* `ApiKioskTest.php` no tiene ningún test de fichaje duplicado, por eso el 500
  pasó desapercibido.

El kiosco web sí recibió el contrato bueno
(`app/Http/Controllers/Payroll/KioskController.php:452`,
`punchNotAllowedResponse()`) y su test de referencia es
`tests/Feature/Payroll/KioskAttendanceTest.php:374`
(`test_punch_rejects_a_movement_already_registered_and_returns_the_options`).

### 1.3 Documentación obsoleta

`docs/kiosk-android-app.md` (repo web) sigue afirmando en §5 y en el checklist
(línea 508) que existe una "duplicate window" de ±2 minutos. Debe corregirse
(ver §9.5 de este documento).

---

## 2. Flujo objetivo de la app

```
                 ┌──────────────────────────────────────────────┐
                 │  ready · en espera (sin tipo, sin método)     │
                 └──────────────────────────────────────────────┘
                        │ toca un tipo permitido
                        ▼
                 paso 2 · identificación (rostro | número de empleado)
                        │ envía
                        ▼
     ┌──────────────────────────────────────────────┐
     │ processing · overlay bloqueante (sin taps)    │
     └──────────────────────────────────────────────┘
        │ 200                    │ 422 not_allowed            │ 422 otro / 429
        ▼                        ▼                            ▼
  modal de éxito          modal "ya registrado"          banner de error
  (auto-cierre 7 s)       (botón "Elegir otro registro")  (se queda en el paso)
        │                        │
        └────────► ready · en espera ◄────┘
```

Diferencia clave con la versión actual: el error del servidor puede ser **de
negocio** (el fichaje no corresponde) y ese caso **no** es un error de red ni un
banner: es un **modal** que explica qué pasa y devuelve al colaborador al paso 1.

---

## 3. Contrato de API

Base: `{APP_URL}/api/v1/kiosk` (sin barra final). Cabeceras en todas las
peticiones: `Accept: application/json` y `Content-Type: application/json`.
No hay token de dispositivo: la API es anónima a propósito.

### 3.1 `POST /punch` — número de empleado

```json
{
  "employee_number": "EMP-0100",
  "type": "check_in",
  "latitude": 20.676,
  "longitude": -103.347,
  "location_accuracy": 12.5,
  "device_key": "9774d56d682e549c",
  "device_name": "SM-T500"
}
```

### 3.2 `POST /face-punch` — rostro

```json
{
  "type": "check_in",
  "photo": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
  "latitude": 20.676,
  "longitude": -103.347,
  "location_accuracy": 12.5,
  "device_key": "9774d56d682e549c",
  "device_name": "SM-T500"
}
```

`latitude` y `longitude` son **obligatorios** (evidencia del fichaje). `photo` es
un data URL JPEG (calidad 70-75, lado mayor ≤ 1024 px, ≤ 2 000 000 caracteres).

### 3.3 `200` — fichaje guardado

```json
{
  "user_name": "Juan Pérez",
  "employee_number": "EMP-0100",
  "type": "check_in",
  "type_label": "Entrada",
  "punched_at": "09:14",
  "date_label": "07/11/2026",
  "suggested_next": "lunch_start",
  "suggested_next_label": "Inicio de comida",
  "options": [
    { "type": "check_in",    "label": "Entrada",            "allowed": false, "reason": "Ya registraste tu entrada a las 09:14. Selecciona otro tipo de registro.", "last_registered_at": "09:14" },
    { "type": "lunch_start", "label": "Inicio de comida",   "allowed": true,  "reason": null, "last_registered_at": null },
    { "type": "lunch_end",   "label": "Fin de comida",      "allowed": false, "reason": "No tienes una comida en curso.", "last_registered_at": null },
    { "type": "break_start", "label": "Permiso / salida",   "allowed": true,  "reason": null, "last_registered_at": null },
    { "type": "break_end",   "label": "Regreso de permiso", "allowed": false, "reason": "No tienes un permiso en curso.", "last_registered_at": null },
    { "type": "check_out",   "label": "Salida",             "allowed": true,  "reason": null, "last_registered_at": null }
  ]
}
```

`POST /face-punch` añade `"similarity": 98.42` (porcentaje 0-100 de AWS
Rekognition, redondeado a 2 decimales).

> **`options` es nuevo** y lo añade el backend en este cambio (§9.3). Si el
> servidor no lo manda, la app debe seguir funcionando (`options` vacío ⇒ ningún
> botón se atenúa).

### 3.4 `422` — validación clásica

```json
{
  "message": "Número de empleado no encontrado. Verifícalo o pide ayuda al administrador.",
  "errors": {
    "employee_number": ["Número de empleado no encontrado. Verifícalo o pide ayuda al administrador."]
  }
}
```

Sigue mostrándose como hoy: `errors.<campo>[0]` en el banner del paso actual
(`KioskController._punchErrorMessage`).

### 3.5 `422` **nuevo** — el fichaje no corresponde (duplicado o fuera de orden)

```json
{
  "message": "Ya registraste tu entrada a las 09:14. Selecciona otro tipo de registro.",
  "code": "attendance_punch_not_allowed",
  "type": "check_in",
  "last_registered_at": "09:14",
  "options": [ /* las seis opciones, igual que en §3.3 */ ],
  "errors": { "type": ["Ya registraste tu entrada a las 09:14. Selecciona otro tipo de registro."] }
}
```

| Campo | Tipo | Significado |
|---|---|---|
| `message` | string | Motivo, ya redactado para el colaborador. **Es el texto del modal.** |
| `code` | string | Siempre `attendance_punch_not_allowed`. Es la señal para la app: **nunca** inferir por el status ni por el texto. |
| `type` | string | Tipo de fichaje rechazado (`check_in`, `lunch_start`, …). |
| `last_registered_at` | `HH:mm` \| `null` | Hora del último fichaje **de ese mismo tipo** hoy. `null` = nunca se registró, el rechazo es por orden. |
| `options` | array | Estado de los seis tipos: `type`, `label`, `allowed`, `reason`, `last_registered_at`. |
| `errors.type` | string[] | Mismo mensaje, por compatibilidad con el mapeo de validación. |

Regla de la app: **si `code == "attendance_punch_not_allowed"` se muestra el modal
de §6.3 y se ignoran `errors.*`.**

### 3.6 Otros estados

| Status | Cuándo | Reacción de la app |
|---|---|---|
| `429` | Throttle (60 peticiones por minuto en `/punch` y `/face-punch`) | `"Demasiados intentos. Espera unos segundos e intenta de nuevo."` (sin cambios) |
| `5xx`, timeout, sin red | Servidor caído | Pantalla `unreachable` con reintento cada 15 s (sin cambios) |
| `403` | **Nunca** en esta API (no hay autorización de dispositivo) | — |

---

## 4. Secuencia diaria que aplica el servidor

`AttendancePunchPolicy` recalcula el estado del día a partir de los fichajes de
**ese** día (`outside` → `working` → `meal` / `break` → `outside`). Cada día
empieza de nuevo con la entrada; un día sin salida no afecta al siguiente.

La app **no debe replicar esta lógica**: solo pinta lo que devuelve el servidor.

| Tipo | `outside` | `working` | `meal` (comida en curso) | `break` (permiso en curso) |
|---|---|---|---|---|
| `check_in` (Entrada) | ✅ | ❌ ya registrada | ❌ | ❌ |
| `lunch_start` (Inicio de comida) | ❌ primero la entrada | ✅ | ❌ ya en curso | ❌ primero el regreso |
| `lunch_end` (Fin de comida) | ❌ | ❌ no hay comida | ✅ | ❌ |
| `break_start` (Permiso / salida) | ❌ | ✅ | ❌ termina la comida | ❌ ya en curso |
| `break_end` (Regreso de permiso) | ❌ | ❌ no hay permiso | ❌ | ✅ |
| `check_out` (Salida) | ❌ | ✅ | ✅ | ✅ |

Motivos que puede devolver el servidor (copiados de
`AttendancePunchPolicy::reasonFor()`; no inventar otros):

* `Ya registraste tu entrada a las HH:mm. Selecciona otro tipo de registro.`
* `Primero registra tu entrada.`
* `Ya registraste tu salida a las HH:mm. Registra una nueva entrada si vas a continuar.`
* `No puedes registrar la salida en este momento.`
* `Ya registraste el inicio de comida a las HH:mm. Registra el fin de comida.`
* `Ya tienes una comida en curso.`
* `Termina tu comida antes de registrar un permiso.`
* `No puedes iniciar la comida en este momento.`
* `Ya registraste el fin de comida a las HH:mm.`
* `No tienes una comida en curso.`
* `Ya registraste un permiso a las HH:mm. Registra tu regreso de permiso.`
* `Ya tienes un permiso en curso.`
* `No puedes registrar un permiso en este momento.`
* `Primero registra tu regreso de permiso.`
* `Ya registraste el regreso de permiso a las HH:mm.`
* `No tienes un permiso en curso.`
* `Este registro no está permitido en este momento.`

---

## 5. Prevención del doble registro (cuatro capas)

El problema: un colaborador toca dos veces "Registrar" (o dos personas se cruzan)
y se crean dos fichajes del mismo tipo. Se resuelve en capas, de la más barata a
la más fiable:

1. **Bloqueo de UI (app).** Mientras `isSubmitting == true` se muestra un overlay
   opaco a pantalla completa que absorbe los taps (`ProcessingOverlay`), y todos
   los callbacks del controlador tienen el guard `if (_isSubmitting) return;`.
   Además hay que **cerrar la ventana** entre la captura de la foto y el envío:
   hoy `submitFace()` pone `_isSubmitting = false` en la línea 315 y vuelve a
   entrar en `_submitWithLocation()`, lo que abre un hueco de doble tap (§7.5).
2. **El servidor manda (autoridad).** La validación real es
   `AttendancePunchPolicy` dentro de la transacción del fichaje. La app **nunca**
   decide si un tipo está permitido para guardarlo: solo lo atenúa visualmente.
3. **`options[]` (app).** Tras un rechazo o un éxito la app actualiza los seis
   botones: los `allowed: false` se ven atenuados y, al tocarlos, muestran el
   mismo modal con su `reason` **sin llamar a la API**.
4. **Reinicio de sesión (app).** Tras el modal de éxito (auto-cierre a los 7 s o
   botón "Cerrar") y tras cerrar el modal de rechazo se limpian tipo
   seleccionado, método, número tecleado, cámara y `options`. Así el siguiente
   colaborador no hereda nada y no puede reenviar el estado anterior.

---

## 6. UI: overlay de proceso y modales

Todos los textos van en **sentence case** y en español. Los colores salen de
`lib/ui/kiosk_theme.dart` (`KioskColors`, `KioskSpacing`, `KioskRadius`,
`KioskShadows`, `KioskText`); ningún widget declara colores propios.

### 6.1 Overlay de proceso (nuevo, bloqueante)

* Scrim oscuro a pantalla completa + tarjeta blanca centrada (`maxWidth: 420`).
* `CircularProgressIndicator` (color `KioskColors.brand`, 44×44, `strokeWidth: 4`).
* Título: **`Procesando tu registro…`**
* Ayuda: **`Esto tarda solo un momento.`**
* Se muestra mientras `isSubmitting == true`, incluida la obtención del GPS.
* Absorbe los taps (`Positioned.fill` + `AbsorbPointer`), para que nadie pueda
  tocar un tipo ni el botón de registrar mientras viaja la petición.
* Va **el último** del `Stack`, por encima del modal de éxito y del de rechazo.

### 6.2 Modal de éxito (actualizar `lib/ui/widgets/success_overlay.dart`)

| Elemento | Texto exacto |
|---|---|
| Icono | círculo `KioskColors.successSoft` + `Icons.check_rounded` (ya existe) |
| Título | `¡Registro exitoso!` |
| Nombre | `{user_name}` (ya existe) |
| Chip | `{type_label} · {punched_at}` sobre `brandSoft`, borde `border`, texto `brand` |
| Rostro (solo si `similarity != null`) | `Identificado por rostro · {similarity}% de coincidencia` |
| Siguiente | `Siguiente sugerido: {suggested_next_label}` (solo si no es `null`) |
| Botón | `Cerrar` (antes decía "Continuar") |
| Nota al pie | `Esta ventana se cierra automáticamente en unos segundos.` |

* `similarity` se formatea con 2 decimales y sin ceros sobrantes
  (`98.42`, `98.4`, `98`).
* Auto-cierre a los `timings.successOverlayDuration` (7 s), ya implementado.
* `date_label` puede seguir mostrándose debajo del chip (el modal web no lo
  muestra); no es crítico para la paridad.

### 6.3 Modal "ya registrado" (widget nuevo)

Equivalente Flutter de `AttendanceAlreadyRegisteredDialog.vue`.

| Elemento | Valor |
|---|---|
| Scrim | `KioskColors.dangerScrim` (nuevo token `0x99D92D20`, rojo translúcido igual que el web) |
| Icono | círculo `dangerSoft` + `Icons.warning_rounded` en `danger`, 52 px |
| Título | si `last_registered_at != null` → `Ese registro ya se realizó`; si es `null` → `No se pudo registrar ese movimiento` |
| Mensaje | `reason` de la opción rechazada; si no viene, `message` del 422; si tampoco, `Ese registro ya se realizó o no está disponible en este momento.` |
| Chip (si hay `last_registered_at`) | `{label} · Registrado a las {HH:mm}` — `label` es el `label` del tipo rechazado |
| Ayuda | `Selecciona otro tipo de registro para continuar.`, **solo** si el mensaje no contiene ya `selecciona otro` (comparación en minúsculas, igual que el web) |
| Botón (ancho completo, `danger`) | `Elegir otro registro` |

Al cerrarlo: se limpian tipo seleccionado, método, número tecleado y cámara, y la
pantalla queda en el paso 1.

### 6.4 Banner o modal: qué se usa en cada caso

| Situación | Presentación |
|---|---|
| `code == attendance_punch_not_allowed` | **Modal** §6.3 (nunca banner) |
| Botón de tipo con `allowed: false` tocado | El mismo **modal** §6.3, sin HTTP |
| Validación (`employee_number`, `face`, `photo`, `user`, `latitude`, `longitude`) | **Banner** del paso actual (sin cambios) |
| `429` | **Banner** con el mensaje de throttle (sin cambios) |
| `5xx` / sin red | Pantalla `unreachable` (sin cambios) |

---

## 7. Cambios en la app Flutter

### 7.1 Nuevo `lib/data/models/punch_option.dart`

```dart
/// One punch type of the daily sequence, as reported by the server in
/// `options[]` (`200` payload and `422 attendance_punch_not_allowed`).
class PunchOption {
  const PunchOption({
    required this.type,
    required this.label,
    required this.allowed,
    this.reason,
    this.lastRegisteredAt,
  });

  final String type;
  final String label;
  final bool allowed;

  /// Why the type cannot be registered, already written for the collaborator.
  final String? reason;

  /// `HH:mm` of the last punch of this type today, `null` when never used.
  final String? lastRegisteredAt;

  factory PunchOption.fromJson(Map<String, dynamic> json) {
    return PunchOption(
      type: _text(json['type']) ?? '',
      label: _text(json['label']) ?? '',
      allowed: json['allowed'] == true,
      reason: _text(json['reason']),
      lastRegisteredAt: _text(json['last_registered_at']),
    );
  }

  /// Reads `options[]`; a missing or malformed list yields an empty list.
  static List<PunchOption> listFromJson(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => PunchOption.fromJson(Map<String, dynamic>.from(item)))
        .where((option) => option.type.isNotEmpty)
        .toList();
  }

  static String? _text(dynamic value) {
    if (value == null) return null;

    final text = '$value';

    return text.isEmpty ? null : text;
  }
}
```

### 7.2 Nuevo `lib/data/models/punch_not_allowed.dart`

```dart
import 'api_error.dart';
import 'punch_option.dart';

/// Business rejection `422 attendance_punch_not_allowed`: the requested
/// movement does not follow the daily attendance sequence.
class PunchNotAllowed {
  const PunchNotAllowed({
    required this.type,
    required this.message,
    this.lastRegisteredAt,
    this.options = const [],
  });

  final String type;
  final String message;
  final String? lastRegisteredAt;
  final List<PunchOption> options;

  static const String fallbackMessage =
      'Ese registro ya se realizó o no está disponible en este momento.';
  static const String hint =
      'Selecciona otro tipo de registro para continuar.';

  String get title => lastRegisteredAt != null
      ? 'Ese registro ya se realizó'
      : 'No se pudo registrar ese movimiento';

  /// The rejected option, so the dialog can show its label.
  PunchOption? get rejectedOption {
    for (final option in options) {
      if (option.type == type) return option;
    }

    return null;
  }

  String get typeLabel => rejectedOption?.label ?? '';

  /// Same rule as the web kiosk: do not repeat the hint when the server
  /// message already tells the collaborator to pick another type.
  bool get showsHint => !message.toLowerCase().contains('selecciona otro');

  factory PunchNotAllowed.fromApiError(ApiError error) {
    final data = error.responseData ?? const <String, dynamic>{};
    final options = PunchOption.listFromJson(data['options']);
    final type = '${data['type'] ?? ''}';

    PunchOption? rejected;
    for (final option in options) {
      if (option.type == type) {
        rejected = option;
        break;
      }
    }

    return PunchNotAllowed(
      type: type,
      message: _text(data['message']) ?? error.message,
      lastRegisteredAt:
          _text(data['last_registered_at']) ?? rejected?.lastRegisteredAt,
      options: options,
    );
  }

  /// Used when the collaborator taps a disabled type: the server would answer
  /// exactly the same, so the kiosk shows it without spending a request.
  factory PunchNotAllowed.fromOption(
    PunchOption option, {
    required List<PunchOption> options,
  }) {
    return PunchNotAllowed(
      type: option.type,
      message: option.reason ?? fallbackMessage,
      lastRegisteredAt: option.lastRegisteredAt,
      options: options,
    );
  }

  static String? _text(dynamic value) {
    if (value == null) return null;

    final text = '$value';

    return text.isEmpty ? null : text;
  }
}
```

### 7.3 `lib/data/models/api_error.dart` — añadir `code` y `responseData`

```dart
  const ApiError({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.code,
    this.responseData,
  });

  /// Machine-readable code sent by the backend, e.g.
  /// `attendance_punch_not_allowed`.
  final String? code;

  /// Decoded JSON body, kept so a screen can build a rich dialog out of a
  /// business error without parsing the raw JSON twice.
  final Map<String, dynamic>? responseData;

  static const String punchNotAllowedCode = 'attendance_punch_not_allowed';

  /// The daily attendance sequence rejected the movement (§4): show the
  /// "already registered" dialog instead of a generic error.
  bool get isPunchNotAllowed => code == punchNotAllowedCode;
```

Y dentro de `ApiError.fromResponse`, junto a las variables locales que ya hay:

```dart
    Map<String, dynamic>? payload;
    String? code;

    if (data is Map) {
      payload = Map<String, dynamic>.from(data);

      final rawCode = data['code'];
      if (rawCode is String && rawCode.trim().isNotEmpty) {
        code = rawCode;
      }

      // …el parseo actual de `message` y `errors` no cambia…
    }
```

```dart
    return ApiError(
      statusCode: statusCode,
      message: message ?? _defaultMessage(statusCode),
      fieldErrors: fieldErrors,
      code: code,
      responseData: payload,
    );
```

No hace falta tocar `kiosk_api.dart`: `_json()` ya lanza
`ApiError.fromResponse(status, data)`.

### 7.4 `lib/data/models/punch_result.dart` — añadir `options`

```dart
    this.options = const [],
  });

  /// Daily sequence reported by the server, empty when it did not send it.
  final List<PunchOption> options;
```

```dart
      options: PunchOption.listFromJson(json['options']),
```

Y actualizar el comentario de `similarity`: ahora **sí** se muestra al
colaborador (§6.2).

### 7.5 `lib/state/kiosk_controller.dart` — estado, guard y rechazo

**Campos y getters**

```dart
  List<PunchOption> _options = const [];
  PunchNotAllowed? _punchNotAllowed;

  List<PunchOption> get options => _options;
  PunchNotAllowed? get punchNotAllowed => _punchNotAllowed;
```

**Separar el guard del envío** (cierra el hueco de doble tap de `submitFace`)

```dart
  /// Entry point for the keypad: takes the lock and delegates.
  Future<void> _submitWithLocation(
    Future<PunchResult> Function(GpsFix fix) send,
  ) async {
    if (_isSubmitting) return;

    _isSubmitting = true;
    await _runPunch(send);
  }

  /// Sends the punch with a GPS fix. The caller must already hold
  /// `_isSubmitting`, so a double tap can never send two punches.
  Future<void> _runPunch(Future<PunchResult> Function(GpsFix fix) send) async {
    _isLocating = true;
    _error = null;
    _notify();

    try {
      final fix = await locationService.currentFix(
        timeout: timings.locationTimeout,
      );
      _isLocating = false;
      _notify();

      if (fix == null) {
        _isSubmitting = false;
        _locationPermissionMissing = true;
        _error = locationErrorMessage;
        _notify();
        return;
      }

      final result = await send(fix);
      _isSubmitting = false;
      _punchNotAllowed = null;
      _lastResult = result;
      if (result.options.isNotEmpty) _options = result.options;
      _notify();

      _startSuccessTimer();
    } on ApiError catch (error) {
      _isSubmitting = false;
      _isLocating = false;

      if (error.isUnreachable) {
        await _goUnreachable(error);
        return;
      }

      if (error.isPunchNotAllowed) {
        await _showPunchNotAllowed(PunchNotAllowed.fromApiError(error));
        return;
      }

      _error = _punchErrorMessage(error);
      _notify();
    } catch (_) {
      _isSubmitting = false;
      _isLocating = false;
      _error = cameraFailedMessage;
      _notify();
    }
  }
```

**`submitFace()`**: borrar el `_isSubmitting = false;` de la línea 315 y llamar a
`_runPunch(...)` en lugar de `_submitWithLocation(...)`, porque la toma del lock
ya ocurrió al principio del método con `_isSubmitting = true`.

**Nuevos métodos**

```dart
  void _startSuccessTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(timings.successOverlayDuration, () {
      _lastResult = null;
      _selectedType = null;
      _options = const [];
      _clearIdentification();
      _notify();
    });
  }

  /// The server rejected the movement: show the dialog and go back to step 1.
  Future<void> _showPunchNotAllowed(PunchNotAllowed rejection) async {
    _overlayTimer?.cancel();
    _lastResult = null;
    _punchNotAllowed = rejection;
    if (rejection.options.isNotEmpty) _options = rejection.options;
    _selectedType = null;
    _error = null;
    await _clearIdentification();
    _notify();
  }

  /// Button "Elegir otro registro" of the rejection dialog.
  Future<void> dismissPunchNotAllowed() async {
    _punchNotAllowed = null;
    _selectedType = null;
    _error = null;
    await _clearIdentification();
    _notify();
  }

  /// Tapping a disabled punch type: the same dialog the server would return,
  /// without spending a request.
  void showBlockedOption(PunchOption option) {
    if (_isSubmitting) return;

    _punchNotAllowed = PunchNotAllowed.fromOption(option, options: _options);
    _selectedType = null;
    _error = null;
    _notify();
  }
```

**Ajustes menores**

* `dismissSuccess()`: añadir `_options = const [];` junto a `_selectedType = null`.
* `start()`: añadir `_punchNotAllowed = null;` y `_options = const [];` al
  reiniciar la sesión.
* `_punchErrorMessage()`: dejar `'type'` como último recurso (si un backend
  antiguo no manda `code`, el mensaje sale en el banner en vez de perderse).

### 7.6 `lib/ui/widgets/success_overlay.dart` — copy nuevo

Sustituir el contenido del `Column` (líneas 49-110) por:

```dart
                  const SizedBox(height: KioskSpacing.md),
                  const Text(
                    '¡Registro exitoso!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.sm),
                  if (result.userName.isNotEmpty)
                    Text(
                      result.userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: KioskColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: KioskSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KioskSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: KioskColors.brandSoft,
                      borderRadius: KioskRadius.bannerRadius,
                      border: Border.all(color: KioskColors.border),
                    ),
                    child: Text(
                      '${result.typeLabel} · ${result.punchedAt}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: KioskColors.brand,
                      ),
                    ),
                  ),
                  if (result.similarity != null) ...[
                    const SizedBox(height: KioskSpacing.xs),
                    Text(
                      'Identificado por rostro · '
                      '${formatSimilarity(result.similarity!)}% de coincidencia',
                      textAlign: TextAlign.center,
                      style: KioskText.secondary,
                    ),
                  ],
                  if (result.suggestedNextLabel != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Siguiente sugerido: ${result.suggestedNextLabel}',
                      textAlign: TextAlign.center,
                      style: KioskText.secondary,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDismiss,
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.xs),
                  const Text(
                    'Esta ventana se cierra automáticamente en unos segundos.',
                    textAlign: TextAlign.center,
                    style: KioskText.caption,
                  ),
```

Helper al final del archivo:

```dart
/// `98.42` → `98.42`, `98.5` → `98.5`, `98.0` → `98`.
String formatSimilarity(double value) {
  return value
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}
```

### 7.7 Nuevo `lib/ui/widgets/already_registered_overlay.dart`

```dart
import 'package:flutter/material.dart';

import '../../data/models/punch_not_allowed.dart';
import '../kiosk_theme.dart';

/// Full-screen dialog shown when the server rejects a punch because the daily
/// sequence does not allow it (duplicate or out of order).
class AlreadyRegisteredOverlay extends StatelessWidget {
  const AlreadyRegisteredOverlay({
    super.key,
    required this.rejection,
    required this.onDismiss,
  });

  final PunchNotAllowed rejection;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: KioskColors.dangerScrim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KioskSpacing.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: KioskColors.surface,
                borderRadius: KioskRadius.overlayRadius,
                boxShadow: KioskShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: KioskColors.dangerSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: KioskColors.danger,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.md),
                  Text(
                    rejection.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.sm),
                  Text(
                    rejection.message,
                    textAlign: TextAlign.center,
                    style: KioskText.body,
                  ),
                  if (rejection.lastRegisteredAt != null) ...[
                    const SizedBox(height: KioskSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KioskSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: KioskColors.dangerSoft,
                        borderRadius: KioskRadius.bannerRadius,
                        border: Border.all(color: KioskColors.dangerBorder),
                      ),
                      child: Text(
                        '${rejection.typeLabel} · Registrado a las '
                        '${rejection.lastRegisteredAt}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: KioskColors.danger,
                        ),
                      ),
                    ),
                  ],
                  if (rejection.showsHint) ...[
                    const SizedBox(height: KioskSpacing.sm),
                    const Text(
                      PunchNotAllowed.hint,
                      textAlign: TextAlign.center,
                      style: KioskText.secondary,
                    ),
                  ],
                  const SizedBox(height: KioskSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: KioskColors.danger,
                      ),
                      onPressed: onDismiss,
                      child: const Text('Elegir otro registro'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 7.8 Nuevo `lib/ui/widgets/processing_overlay.dart`

```dart
import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Blocks the whole kiosk while a punch is being sent, so a double tap or a
/// second collaborator cannot start another request (see §5).
class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: KioskColors.overlayScrim,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: KioskColors.surface,
                borderRadius: KioskRadius.overlayRadius,
                boxShadow: KioskShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                  const SizedBox(height: KioskSpacing.md),
                  const Text(
                    'Procesando tu registro…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.xs),
                  Text(
                    'Esto tarda solo un momento.',
                    textAlign: TextAlign.center,
                    style: KioskText.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 7.9 `lib/ui/kiosk_theme.dart` — dos tokens nuevos

Añadir en `KioskColors`, junto a `successScrim`:

```dart
  /// Scrim that blocks the kiosk while a request is in flight.
  static const Color overlayScrim = Color(0xB311161C);

  /// Scrim of the "already registered" dialog (same red as the web kiosk).
  static const Color dangerScrim = Color(0x99D92D20);
```

### 7.10 `lib/ui/widgets/punch_type_grid.dart` — tipos atenuados

**Constructor** (líneas 8-19): añadir dos parámetros.

```dart
  const PunchTypeGrid({
    super.key,
    required this.types,
    required this.onSelect,
    this.selectedKey,
    this.enabled = true,
    this.options = const [],
    this.onBlocked,
  });

  final List<PunchType> types;
  final ValueChanged<PunchType> onSelect;
  final String? selectedKey;
  final bool enabled;

  /// Daily sequence reported by the server: a type with `allowed == false` is
  /// rendered dimmed and explains its reason when tapped.
  final List<PunchOption> options;
  final ValueChanged<PunchOption>? onBlocked;
```

**Import nuevo:** `import '../../data/models/punch_option.dart';`

**`_buildTile`** (líneas 80-91) queda así:

```dart
  Widget _buildTile(int index) {
    if (index >= types.length) {
      return const SizedBox.shrink();
    }

    final type = types[index];
    final option = _optionFor(type.key);
    final blocked = option != null && !option.allowed;

    final tile = _PunchTypeButton(
      label: type.label,
      icon: _icons[type.key] ?? Icons.fingerprint_rounded,
      selected: !blocked && type.key == selectedKey,
      onTap: !enabled
          ? null
          : blocked
          ? () => onBlocked?.call(option)
          : () => onSelect(type),
    );

    // Dimmed but still tappable, so the collaborator learns why (web parity).
    return Opacity(opacity: blocked ? 0.45 : 1, child: tile);
  }

  PunchOption? _optionFor(String key) {
    for (final option in options) {
      if (option.type == key) return option;
    }

    return null;
  }
```

`_PunchTypeButton` no cambia: `Opacity` mantiene el hit test, así que el tap en un
tipo atenuado sigue llegando y abre el modal con su motivo.

### 7.11 `lib/ui/kiosk_screen.dart` — apilar los overlays

En el `Stack` (líneas 63-100), justo después del `SuccessOverlay`:

```dart
                  if (_controller.lastResult != null)
                    SuccessOverlay(
                      result: _controller.lastResult!,
                      onDismiss: _controller.dismissSuccess,
                    ),
                  if (_controller.punchNotAllowed != null)
                    AlreadyRegisteredOverlay(
                      rejection: _controller.punchNotAllowed!,
                      onDismiss: _controller.dismissPunchNotAllowed,
                    ),
                  if (_controller.isSubmitting) const ProcessingOverlay(),
```

> El overlay de proceso va **al final** para quedar por encima de todo.

Imports nuevos:

```dart
import 'widgets/already_registered_overlay.dart';
import 'widgets/processing_overlay.dart';
```

Y la instancia de `PunchTypeGrid` (líneas 258-263):

```dart
              child: PunchTypeGrid(
                types: _controller.punchTypes,
                options: _controller.options,
                selectedKey: selected?.key,
                enabled: !_controller.isSubmitting,
                onSelect: _controller.selectType,
                onBlocked: _controller.showBlockedOption,
              ),
```

### 7.12 `lib/config/kiosk_config.dart`

Sin cambios: `successOverlayDuration` (7 s) ya existe y se reutiliza tal cual.

---

## 8. Textos exactos (usar tal cual, sentence case)

| Uso | Texto |
|---|---|
| Overlay de proceso · título | `Procesando tu registro…` |
| Overlay de proceso · ayuda | `Esto tarda solo un momento.` |
| Éxito · título | `¡Registro exitoso!` |
| Éxito · rostro | `Identificado por rostro · {n}% de coincidencia` |
| Éxito · siguiente | `Siguiente sugerido: {label}` |
| Éxito · botón | `Cerrar` |
| Éxito · nota | `Esta ventana se cierra automáticamente en unos segundos.` |
| Rechazo · título con hora | `Ese registro ya se realizó` |
| Rechazo · título sin hora | `No se pudo registrar ese movimiento` |
| Rechazo · mensaje de respaldo | `Ese registro ya se realizó o no está disponible en este momento.` |
| Rechazo · chip | `{label} · Registrado a las {HH:mm}` |
| Rechazo · ayuda | `Selecciona otro tipo de registro para continuar.` |
| Rechazo · botón | `Elegir otro registro` |

---

## 9. Cambios de backend necesarios (repo web `Construmax`)

Sin estos cambios la app recibiría **500** en lugar del `422` documentado en §3.5.

> **Estado: aplicado y verificado el 12-nov-2026** — un archivo nuevo y dos
> modificados, más dos tests. Lo que sigue documenta exactamente lo que quedó
> implementado, para que nadie lo reinvete ni lo rompa.

### 9.1 Nuevo `app/Actions/Payroll/BuildPunchNotAllowedResponseAction.php`

```php
<?php

namespace App\Actions\Payroll;

use App\Services\Payroll\Exceptions\AttendancePunchNotAllowedException;

/**
 * Error payload for a punch that does not follow the daily attendance
 * sequence. Shared by the web kiosk and the Android kiosk API so both clients
 * receive exactly the same contract.
 */
class BuildPunchNotAllowedResponseAction
{
    /**
     * @return array<string, mixed>
     */
    public function execute(AttendancePunchNotAllowedException $exception): array
    {
        return [
            'message' => $exception->getMessage(),
            'code' => 'attendance_punch_not_allowed',
            'type' => $exception->punchType,
            'last_registered_at' => $exception->lastRegisteredAt,
            'options' => $exception->options,
            'errors' => [
                'type' => [$exception->getMessage()],
            ],
        ];
    }
}
```

Devuelve exactamente lo mismo que hoy devuelve
`Payroll\KioskController::punchNotAllowedResponse()` (línea 452), así que los dos
kioscos comparten contrato. Opcional: que ese método privado delegue en esta
acción para no duplicar el array; no es obligatorio, el kiosco web ya funciona.

### 9.2 `app/Http/Controllers/Api/V1/KioskController.php` — capturar la excepción

Imports nuevos:

```php
use App\Actions\Payroll\BuildPunchNotAllowedResponseAction;
use App\Services\Payroll\Exceptions\AttendancePunchNotAllowedException;
```

Añadir al constructor:

```php
        private readonly BuildPunchNotAllowedResponseAction $buildPunchNotAllowedResponseAction,
```

Y envolver los dos métodos de fichaje:

```php
    public function punch(KioskPunchRequest $request): JsonResponse
    {
        $data = $request->validated();

        try {
            $log = $this->employeeNumberPunchAction->execute(
                $data,
                $this->resolveDevice($request, $data['device_key'] ?? null, $data['device_name'] ?? null),
            );
        } catch (AttendancePunchNotAllowedException $exception) {
            return response()->json(
                $this->buildPunchNotAllowedResponseAction->execute($exception),
                422,
            );
        }

        return response()->json($this->buildPunchResponseAction->execute($log));
    }

    public function facePunch(KioskFacePunchRequest $request): JsonResponse
    {
        $data = $request->validated();

        try {
            ['log' => $log, 'similarity' => $similarity] = $this->facePunchAction->execute(
                $data,
                $this->resolveDevice($request, $data['device_key'] ?? null, $data['device_name'] ?? null),
            );
        } catch (AttendancePunchNotAllowedException $exception) {
            return response()->json(
                $this->buildPunchNotAllowedResponseAction->execute($exception),
                422,
            );
        }

        return response()->json($this->buildPunchResponseAction->execute($log, $similarity));
    }
```

### 9.3 `app/Actions/Payroll/BuildPunchResponseAction.php` — añadir `options`

Import y constructor:

```php
use App\Services\Payroll\AttendancePunchPolicy;

    public function __construct(
        private readonly AttendanceService $attendanceService,
        private readonly AttendancePunchPolicy $punchPolicy,
    ) {}
```

Y en el array de retorno:

```php
        return [
            ...$payload,
            'suggested_next' => $suggestedNext,
            'suggested_next_label' => $suggestedNext ? (AttendanceLog::TYPES[$suggestedNext] ?? null) : null,
            'options' => $log->user ? $this->punchPolicy->optionsFor($log->user) : [],
        ];
```

Actualizar también el docblock `@return` con `options: array<int, array<string, mixed>>`.

Esta acción **solo** la usa `Api\V1\KioskController` (verificado), así que añadir la
clave no altera el kiosco web ni ninguna pantalla de Inertia.

### 9.4 Tests — `tests/Feature/Payroll/ApiKioskTest.php`

**Ya implementados** (reutilizan `deviceHeaders()`, `locationPayload()` y
`$this->employee`, que existen en el archivo):

```php
    public function test_punch_rejects_a_movement_already_registered_and_returns_the_options(): void
    {
        $payload = [
            'employee_number' => 'EMP-0100',
            'type' => AttendanceLog::TYPE_CHECK_IN,
            ...$this->locationPayload(),
        ];

        $registeredAt = $this->postJson(route('api.kiosk.punch'), $payload, $this->deviceHeaders())
            ->assertOk()
            ->assertJsonPath('options.0.type', AttendanceLog::TYPE_CHECK_IN)
            ->assertJsonPath('options.0.allowed', false)
            ->assertJsonPath('options.1.type', AttendanceLog::TYPE_LUNCH_START)
            ->assertJsonPath('options.1.allowed', true)
            ->json('punched_at');

        $this->postJson(route('api.kiosk.punch'), $payload, $this->deviceHeaders())
            ->assertStatus(422)
            ->assertJsonPath('code', 'attendance_punch_not_allowed')
            ->assertJsonPath('type', AttendanceLog::TYPE_CHECK_IN)
            ->assertJsonPath('last_registered_at', $registeredAt)
            ->assertJsonValidationErrors('type')
            ->assertJsonPath('options.0.allowed', false)
            ->assertJsonPath('options.0.last_registered_at', $registeredAt);

        $this->assertDatabaseCount('attendance_logs', 1);
    }

    public function test_face_punch_rejects_a_movement_already_registered(): void
    {
        $this->mock(FaceRecognitionService::class, function (MockInterface $mock) {
            $mock->shouldReceive('isConfigured')->andReturn(true);
            $mock->shouldReceive('search')->twice()->andReturn([
                'external_image_id' => (string) $this->employee->id,
                'face_id' => 'aws-face-1',
                'similarity' => 98.42,
            ]);
        });

        $payload = [
            'type' => AttendanceLog::TYPE_CHECK_IN,
            'photo' => 'data:image/jpeg;base64,'.base64_encode('fake-photo'),
            ...$this->locationPayload(),
        ];

        $this->postJson(route('api.kiosk.face-punch'), $payload, $this->deviceHeaders())->assertOk();

        $this->postJson(route('api.kiosk.face-punch'), $payload, $this->deviceHeaders())
            ->assertStatus(422)
            ->assertJsonPath('code', 'attendance_punch_not_allowed')
            ->assertJsonPath('type', AttendanceLog::TYPE_CHECK_IN)
            ->assertJsonValidationErrors('type');

        $this->assertDatabaseCount('attendance_logs', 1);
    }
```

`last_registered_at` se compara con el `punched_at` que devolvió el primer `200`
en lugar de con `now()`: así el test no es frágil si cambia el minuto entre las
dos peticiones.

Comandos:

```bash
php artisan test --testsuite=Feature --filter=ApiKioskTest
php artisan test --testsuite=Feature --filter=KioskAttendanceTest
```

> Ojo: `php artisan test --filter=...` a secas falla en este repo porque
> `phpunit.xml` declara la suite `Unit` sobre `tests/Unit`, que no existe. Usa
> siempre `--testsuite=Feature`.

Resultado esperado el 12-nov-2026: `ApiKioskTest` 26 de 27 en verde (el único
fallo, `bootstrap returns the device punch types and settings`, es previo y depende
del entorno: `AwsFaceRecognitionService::isConfigured()` devuelve `true` en local
porque el `.env` tiene credenciales de AWS; no tiene relación con este cambio) y
`KioskAttendanceTest` 22 de 22 en verde.

### 9.5 `docs/kiosk-android-app.md` (repo web) — dejar de mentir

* §5: la fila del `422` debe documentar el `code` `attendance_punch_not_allowed`
  y remitir al modal "ya registrado".
* §6 y §7: añadir los dos estados nuevos (procesando y ya registrado).
* §10 (línea ~508): eliminar la mención a la "duplicate window" de ±2 minutos;
  ahora es la secuencia diaria de `AttendancePunchPolicy`.
* §11: añadir `BuildPunchNotAllowedResponseAction` a la tabla de referencia.

---

## 10. Tests a añadir en la app (`test/`)

Los tests viven en `test/` (estructura espejo de `lib/`, con `test/support/` para
fakes y harness).

| Archivo | Casos |
|---|---|
| `test/models_test.dart` | `PunchOption.fromJson` y `listFromJson` (lista vacía, `allowed` ausente, `reason` null). `PunchNotAllowed.fromApiError` con el JSON de §3.5: `title`, `message`, `typeLabel`, `lastRegisteredAt`, `options.length == 6` y `showsHint == false` cuando el mensaje ya dice "selecciona otro". `PunchNotAllowed.fromOption` para un tile bloqueado. `PunchResult.fromJson` con y sin `options`. `ApiError.fromResponse(422, …)` expone `code` e `isPunchNotAllowed`. |
| `test/kiosk_controller_test.dart` | (1) Un `422` con `code` deja `punchNotAllowed != null`, `errorMessage == null`, `selectedType == null`, `options` actualizado e `isSubmitting == false`. (2) Doble `submitEmployeeNumber()` con un `Completer` sin resolver ⇒ `api.punch` invocado **una** sola vez. (3) `dismissPunchNotAllowed()` limpia todo y vuelve a "en espera". (4) `showBlockedOption()` no hace HTTP. (5) Tras un `200` con `options`, `controller.options` se actualiza y el timer de 7 s limpia la selección. |
| `test/kiosk_screen_test.dart` | Con `punchNotAllowed` activo se ve `Ese registro ya se realizó`, `Registrado a las 09:14` y el botón `Elegir otro registro`. Con `isSubmitting` se ve `Procesando tu registro…`. Con `lastResult` se ve `¡Registro exitoso!` y `Cerrar`. |
| `test/kiosk_api_test.dart` | El `422` con `code` se propaga como `ApiError` con `isPunchNotAllowed == true` (usar el mock de Dio que ya está en `test/support/fakes.dart`). |

Comandos de verificación:

```bash
flutter analyze
flutter test
```

---

## 11. Orden de implementación sugerido

1. ~~Backend~~ **Hecho** (§9.1 → §9.4): el `422` con `code` y el `options[]` del
   `200` ya están en el servidor y con tests en verde. La app ya puede
   implementarse contra el contrato de §3.
2. **Modelos de la app** (§7.1 → §7.4) y sus tests de `test/models_test.dart`.
3. **Controlador** (§7.5) con sus tests de `test/kiosk_controller_test.dart`.
4. **UI** (§7.6 → §7.11) y sus widget tests.
5. **Documentación** del repo web (§9.5).

---

## 12. Checklist de aceptación

**Backend**

- [ ] Un segundo `check_in` del mismo día responde `422` con
      `code: attendance_punch_not_allowed`, `type`, `last_registered_at`,
      `options` (seis elementos) y `errors.type`.
- [ ] El `200` de `/punch` y `/face-punch` incluye `options` (seis elementos).
- [ ] `php artisan test --filter=ApiKioskTest` pasa.
- [ ] `php artisan test --filter=KioskAttendanceTest` sigue pasando (kiosco web
      intacto).

**App**

- [ ] Tocar "Registrar" dos veces rápido produce **un solo** fichaje.
- [ ] Durante el envío se ve `Procesando tu registro…` y la pantalla no responde
      a taps.
- [ ] Tras un fichaje correcto: `¡Registro exitoso!`, chip `Entrada · 09:14`,
      `Siguiente sugerido: …`, botón `Cerrar` y cierre automático a los 7 s.
- [ ] Un fichaje por rostro muestra
      `Identificado por rostro · 98.42% de coincidencia`.
- [ ] Un duplicado muestra el modal rojo con el motivo del servidor, el chip
      `Entrada · Registrado a las 09:14`, la ayuda (solo si aplica) y el botón
      `Elegir otro registro`; al cerrarlo se vuelve al paso 1 limpio.
- [ ] Los tipos no permitidos se ven atenuados y al tocarlos muestran el mismo
      modal **sin** petición HTTP.
- [ ] Los errores de validación siguen saliendo en banner; `429` y `5xx`/sin red
      se comportan como hoy.
- [ ] `flutter analyze` sin warnings nuevos y `flutter test` en verde.
