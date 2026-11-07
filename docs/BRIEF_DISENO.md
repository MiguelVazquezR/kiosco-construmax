# Brief de diseño · Kiosco de asistencia Construmax

Documento para entregar a un agente de diseño AI. Describe **qué hace** la app,
**cómo se ve hoy** y **qué NO se puede tocar** (paleta de color de marca).
La propuesta debe ser un rediseño visual, no un cambio de funcionalidad.

---

## 1. Contexto de uso (esto manda en las decisiones de diseño)

- App **Flutter para Android**, instalada en una **tablet fija** (10", horizontal
  o vertical) montada en la entrada de una obra / planta de Construmax.
- La tablet queda en **modo kiosco**: pantalla pinneada, botón atrás bloqueado,
  pantalla siempre encendida, sin teclado físico y sin mouse.
- La usan **colaboradores (obreros, personal de planta) que pasan uno por uno**,
  de pie, a veces con guantes, polvo o luz solar directa. Debe leerse y tocarse
  bien a ~50–100 cm de distancia.
- **No hay login, ni usuarios, ni navegación, ni menús, ni ajustes.** La app abre
  directamente en la pantalla de fichaje y solo hay una pantalla + overlays.
- Sesión típica: 2–5 segundos por persona. Debe ser **obvio sin instrucciones**.
- No hay modo oscuro, ni imágenes de marca dentro de la app (solo el ícono de
  lanzador y un splash blanco del sistema).

## 2. Funciones de la app (funcionalidad que se debe conservar)

### Estados globales
1. **Verificando** (`checking`): spinner centrado + texto "Verificando conexión…".
   Se llama `GET /ping` y `POST /bootstrap` contra el backend Laravel.
2. **Listo** (`ready`): la pantalla de fichaje (todo lo de abajo).
3. **Sin servidor** (`unreachable`): tarjeta con ícono `cloud_off`, título
   "No se pudo conectar con el servidor.", ayuda "Verifica la red del dispositivo.",
   botón "Reintentar" y **reintento automático cada 15 s**.

### Flujo de fichaje (una sola pantalla, dos pasos)
1. **Paso 1 – Tipo de fichaje**: título "1. Elige el tipo de fichaje" y una
   cuadrícula 2 columnas × 3 filas con 6 botones (Entrada, Salida, Inicio/Fin de
   comida, Inicio/Fin de descanso; las etiquetas vienen del servidor). Cada botón
   lleva ícono + texto. Al elegir uno, el botón queda marcado y aparece
   "Cambiar tipo" para deshacer.
2. **Paso 2 – Identificación**: panel "¿Cómo quieres identificarte?" con dos
   tarjetas grandes: **"Con mi rostro"** (preview de cámara) y
   **"Con mi número de empleado"** (teclado numérico).
3. **Rostro**: preview de cámara frontal en vivo con óvalo guía, texto de ayuda
   "Colócate de frente a la cámara, con buena iluminación.", botones
   **Capturar** (naranja) y **Cancelar**. Al capturar se toma la foto, se pide
   GPS y se envía a `POST /face-punch`.
4. **Número de empleado**: teclado numérico propio (1–9, Limpiar, 0, retroceso),
   display grande del número, aviso legal, botón **Registrar** y **Cancelar**.
   Envía a `POST /punch` con GPS obligatorio.
5. **Éxito**: overlay a pantalla completa con check verde, "Registro exitoso",
   nombre del colaborador, tipo + hora, fecha, y "Siguiente registro sugerido: …"
   con botón "Continuar". **Se cierra solo a los 7 segundos** y vuelve al estado
   "En espera".
6. **En espera** (estado inicial del paso 2): panel con ícono de toque, título
   "En espera" y "Selecciona el tipo de fichaje para comenzar."

### Estados de error / aviso (parte del diseño, no los omitas)
- **Error de validación** (banner rojo suave, arriba de los controles): p. ej.
  "Escribe tu número de empleado.", mensajes del backend (422 / 429).
- **Ubicación desactivada**: banner ámbar persistente con acción "Activar"
  ("La ubicación está desactivada. Actívala para registrar tu fichaje.").
- **Reloj desfasado**: mismo banner ámbar ("La fecha y hora del dispositivo no
  son correctas. Pide al administrador que las ajustes.").
- **Cámara no disponible / reconocimiento facial no configurado**: texto de aviso
  sobre el video en color ámbar claro.
- **Obteniendo GPS**: texto de estado "Obteniendo ubicación…" junto a los botones.
- **Enviando**: los botones se deshabilitan y muestran un spinner blanco.

### Datos fijos que se muestran
- **Header**: nombre de la tablet ("Tablet Android" o el nombre que asigna el
  servidor), app + ubicación ("Construmax · Planta Norte"), **reloj en vivo HH:mm
  grande** y fecha en español ("lunes 7 de julio").
- Tipos de fichaje: los 6 del backend, con estos íconos Material: login,
  restaurant, restaurant_menu, logout, replay, exit_to_app.

---

## 3. Aspecto actual (lo que el rediseño puede mejorar)

Estilo: **Material 3 "tarjetas planas"**, fondo gris muy claro + tarjetas
blancas con borde de 1 px, esquinas redondeadas, **sin sombras**, mucho aire,
íconos Material Rounded, tipografía del sistema (Roboto en Android), pesos 600/700
y tamaños entre 10 px y 34 px. Nada de degradados salvo el scrim de la cámara.

### Layout responsive (relevante: debe funcionar en tablet horizontal y vertical)
- Ancho ≥ 820 px (tablet horizontal): dos columnas — izquierda 5/9 tipos de
  fichaje, derecha 4/9 identificación; padding 20 px, separación 20 px.
- Ancho < 820 px (vertical / teléfono): apilado, tipos arriba (flex 4) e
  identificación abajo (flex 6), padding 16 px.
- Cuando ya se eligió método (rostro o teclado), **el panel ocupa la pantalla
  completa** (máx. 640 px de ancho en vertical, 960 px en horizontal) y la
  cuadrícula de tipos se oculta; arriba queda solo una línea recordatorio
  "✓ Tipo: Entrada".
- El header se compacta por debajo de 520 px de ancho (oculta la fecha y reduce
  el reloj de 34 a 26 px).

### Inventario de piezas y su aspecto actual
1. **Header** (`ClockHeader`): barra blanca a todo el ancho con borde inferior
   gris, una **barra vertical naranja de 12 px y esquinas 6 px** a la izquierda,
   nombre del dispositivo (20 px, w700), subtítulo app · ubicación (13 px gris),
   y a la derecha el reloj (34 px, w700, cifras tabulares) con la fecha debajo.
   Si el reloj está desfasado, aparece un ícono `warning_amber` naranja.
2. **Banner de advertencia** (`WarningBanner`): franja ámbar a todo el ancho, sin
   radio, borde inferior ámbar más oscuro, ícono + texto 14 px w600 + acción
   "Activar".
3. **Cuadrícula de tipos** (`PunchTypeGrid`): 6 botones con relación 2.4:1,
   separación 12 px, radio 18 px. Normal: fondo blanco, borde 1 px gris, ícono
   30 px gris. Seleccionado: fondo crema naranja, borde 2 px naranja, ícono y
   texto naranjas, w700.
4. **Panel "En espera"** (`WaitingPanel`): tarjeta blanca radio 20 px, ícono
   `touch_app` naranja de 56 px, "En espera" 24 px w700 y subtítulo 15 px gris.
5. **Selector de método** (`MethodSelector`): tarjeta blanca radio 20 px con dos
   filas tipo "lista": cuadro de 46 px crema con el ícono naranja 26 px, título
   17 px w700, subtítulo 13 px gris y chevron a la derecha; radio 16 px.
6. **Teclado** (`KeypadCard`): tarjeta blanca radio 20 px. Arriba
   "NÚMERO DE EMPLEADO" (11 px, mayúsculas, letter-spacing 1.4, gris); display
   con placeholder en gris, fondo gris claro, radio 12 px; 4 filas de teclas
   (alto calculado entre 34 y 88 px) fondo gris claro con borde y radio 12 px,
   dígitos 24 px w700; luego el aviso legal 12 px gris, botón "Registrar"
   (naranja, 56 px) y "Cancelar" (outline).
7. **Cámara** (`CameraCard`): tarjeta blanca radio 20 px con el video ocupando
   todo el interior (radio 16 px), **fondo del video #11161C**, **óvalo guía
   blanco al 70 % con borde de 3 px**, degradado negro 72 % abajo con el texto de
   ayuda en blanco 70 %, estados en blanco y avisos en ámbar claro; los botones
   son **píldoras superpuestas** ("Cancelar" outline translúcido y "Capturar"
   naranja relleno con ícono de cámara).
8. **Overlay de éxito** (`SuccessOverlay`): fondo negro al 90 % a pantalla
   completa; tarjeta blanca radio 24 px (máx. 520 px) con círculo verde claro de
   76 px y check verde, "Registro exitoso" 26 px, nombre 20 px, "Entrada · 07:58"
   en naranja 17 px, fecha 14 px gris, sugerencia 14 px gris y botón "Continuar".
9. **Error** (`ErrorBanner`): tarjeta roja suave radio 14 px con borde rojo claro,
   ícono `error_outline` y texto rojo 15 px w600.
10. **Sin conexión** (`UnreachableView`): tarjeta blanca centrada (máx. 460 px),
    ícono `cloud_off` rojo de 64 px, título 22 px w700, ayuda 15 px gris y botón
    "Reintentar".

### Tokens visuales actuales
- Radios: 6 (barra), 12 (teclas/display), 14 (banner de error), 16 (botones y
  tarjetas internas), 18 (tipos de fichaje), 20 (tarjetas), 24 (overlay/error
  global), píldora (botones sobre la cámara).
- Alturas de control: botones principales 56 px (46 px en modo compacto), teclas
  34–88 px, píldoras de cámara 44 px.
- Espaciados: múltiplos de 4/6/8/10/12/16/20/24.
---

## 4. PALETA OBLIGATORIA — no cambiar por otros colores

Estos son los colores de marca/estado definidos en `lib/ui/kiosk_theme.dart`
(la misma naranja que el kiosco web de Construmax). **El rediseño puede cambiar
layout, tipografía, formas, densidad e íconos, pero debe mantener exactamente
estos valores HEX.** Si necesitas variantes (hover, sombras, velos), derívalas de
estos mismos colores con opacidad; no introduzcas tonos nuevos de marca.

| Rol | HEX | Uso en la app |
| --- | --- | --- |
| **Naranja de marca (`brand`)** | `#F26C17` | Botones primarios, selección de tipo de fichaje, íconos activos, barra del header, tipo+hora en el overlay de éxito, textos de estado |
| **Naranja muy suave (`brandSoft`)** | `#FFF1E6` | Fondo del botón de tipo seleccionado y del cuadro de ícono en el selector de método |
| **Fondo de app (`background`)** | `#F6F7F9` | Scaffold y fondo de teclas / display del teclado |
| **Superficie (`surface`)** | `#FFFFFF` | Todas las tarjetas, header, overlay de éxito |
| **Texto principal (`textPrimary`)** | `#1F2933` | Títulos, números del teclado, reloj |
| **Texto secundario (`textMuted`)** | `#6B7280` | Subtítulos, fechas, placeholders, íconos inactivos |
| **Borde (`border`)** | `#E5E7EB` | Borde de 1 px de tarjetas, teclas, separadores |
| **Peligro (`danger`)** | `#D92D20` | Error de validación, ícono "sin conexión" |
| **Peligro suave (`dangerSoft`)** | `#FEECEB` | Fondo del banner de error |
| **Peligro borde** | `#F5C2BF` | Borde del banner de error |
| **Advertencia suave (`warningSoft`)** | `#FFF7E6` | Fondo del banner persistente (GPS / reloj) |
| **Advertencia borde** | `#F3D9A4` | Línea inferior del banner de advertencia |
| **Advertencia texto** | `#8A6100` | Ícono y texto del banner de advertencia |
| **Aviso sobre cámara** | `#FFD166` | Texto de aviso encima del video (facial no configurado) |
| **Éxito (`success`)** | `#12805C` | Check y texto del registro exitoso |
| **Éxito suave** | `#E6F5EF` | Círculo de fondo del check |
| **Fondo de cámara** | `#11161C` | Lienzo del preview cuando no hay video |
| **Velo del overlay** | `#E611161C` | Fondo del overlay de éxito (negro 90 %) |
| **Blanco / negro con alfa** | `#FFFFFF`, negro 72 % | Óvalo guía, textos y botones sobre el video |

Reglas adicionales de color:
- **Naranja = acción/selección**; verde = éxito; rojo = error; ámbar = aviso.
  No uses naranja para errores ni rojo para botones primarios.
- El fondo de la app se queda **claro** (no hay modo oscuro). Solo el área de
  video y el velo del overlay son oscuros.
- Contraste: texto sobre naranja debe ser **blanco** (`#FFFFFF`); texto sobre
  fondos suaves usa el color fuerte correspondiente.

## 5. Requisitos que la propuesta debe respetar

- **Tablet táctil**: áreas de toque ≥ 44 px (ideal 56 px de alto para acciones
  primarias); nada de controles pequeños ni menús desplegables.
- **Sin scroll** en tablet 10" (ni horizontal ni vertical) en el flujo normal:
  header + tipos + panel de identificación deben caber juntos.
- **Legible a 1 m**: números del reloj y del teclado grandes; textos de ayuda
  ≥ 13 px.
- **Jerarquía de 2 pasos** clara (primero tipo, luego identificación), con
  recordatorio del tipo elegido ("✓ Tipo: Entrada") y salida siempre disponible
  ("Cambiar tipo" / "Cancelar").
- **Retroalimentación inmediata**: estado seleccionado, spinner en botones,
  overlay de éxito de 7 s que se cierra solo.
- **Estados vacíos y de error diseñados**, no improvisados (ver sección 2).
- Funciona igual en vertical y horizontal; la propuesta debe mostrar ambos.

## 6. Textos exactos (copy que ya existe y debe caber en el diseño)

- Estados: "Verificando conexión…", "En espera",
  "Selecciona el tipo de fichaje para comenzar.", "1. Elige el tipo de fichaje",
  "Cambiar tipo", "¿Cómo quieres identificarte?", "Con mi rostro",
  "La cámara te reconoce automáticamente.", "Con mi número de empleado",
  "Escribe tu número en el teclado.", "Capturar", "Cancelar", "Registrar",
  "Limpiar", "NÚMERO DE EMPLEADO", "Número de empleado" (placeholder),
  "Tipo: Entrada", "Obteniendo ubicación…".
- Avisos: "Colócate de frente a la cámara, con buena iluminación.",
  "El registro es personal e individual. No registres la asistencia de otra
  persona.", "La ubicación está desactivada. Actívala para registrar tu fichaje.",
  "La fecha y hora del dispositivo no son correctas. Pide al administrador que
  las ajustes.", "El reconocimiento facial aún no está configurado en el
  servidor. Pide ayuda al administrador.", "La cámara no está disponible.",
  "No se pudo obtener la ubicación del dispositivo. Activa la ubicación e
  intenta de nuevo.", "Escribe tu número de empleado.", "Activar", "Activando…".
- Éxito: "Registro exitoso", nombre del colaborador, "{Tipo} · {HH:mm}",
  "{dd/MM/yyyy}", "Siguiente registro sugerido: {tipo}", "Continuar".
- Sin conexión: "No se pudo conectar con el servidor.",
  "Verifica la red del dispositivo.", "Reintentar".

## 7. Qué se espera de la propuesta de diseño

1. 2–3 direcciones visuales distintas, cada una con: pantalla "En espera",
   pantalla con tipo seleccionado + selector de método, teclado numérico,
   cámara con óvalo, overlay de éxito y estado sin conexión.
2. Versión horizontal (landscape, 1280×800 aprox.) y vertical (800×1280).
3. Especificación de tokens: tipografía (tamaños/pesos), espaciados, radios,
   alturas de control, estados (normal / presionado / seleccionado /
   deshabilitado / cargando) — **usando solo la paleta de la sección 4**.
4. Justificación breve de cómo mejora la legibilidad a distancia, la rapidez de
   uso (2–5 s por persona) y la claridad para usuarios no técnicos.

---

## Anexo · Archivos de referencia (para el desarrollador, no para el agente)

| Pieza | Archivo |
| --- | --- |
| Paleta y tema Material 3 | `lib/ui/kiosk_theme.dart` |
| Pantalla y layout responsive | `lib/ui/kiosk_screen.dart` |
| Header con reloj | `lib/ui/widgets/clock_header.dart` |
| Cuadrícula de tipos | `lib/ui/widgets/punch_type_grid.dart` |
| "En espera" | `lib/ui/widgets/waiting_panel.dart` |
| Selector rostro / número | `lib/ui/widgets/method_selector.dart` |
| Teclado numérico | `lib/ui/widgets/keypad_card.dart` |
| Cámara + óvalo | `lib/ui/widgets/camera_card.dart` |
| Overlay de éxito | `lib/ui/widgets/success_overlay.dart` |
| Banners de error / aviso | `lib/ui/widgets/banners.dart` |
| Sin conexión | `lib/ui/widgets/unreachable_view.dart` |
| Textos y máquina de estados | `lib/state/kiosk_controller.dart` |
| Temporizadores (7 s overlay, 15 s reintento) | `lib/config/kiosk_config.dart` |
| Ícono de la app | `lib/icon.png` (tablet con huella, sobre naranja) |

