import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco/data/models/api_error.dart';
import 'package:kiosco/data/models/kiosk_context.dart';
import 'package:kiosco/data/models/punch_not_allowed.dart';
import 'package:kiosco/data/models/punch_result.dart';
import 'package:kiosco/state/kiosk_controller.dart';
import 'package:kiosco/ui/kiosk_screen.dart';
import 'package:kiosco/ui/kiosk_theme.dart';
import 'package:kiosco/ui/widgets/camera_card.dart';
import 'package:kiosco/ui/widgets/keypad_card.dart';

import 'support/camera_fakes.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

/// Mounts the kiosk on a landscape tablet surface (1280×800) unless [size] is
/// given (e.g. a 360×640 phone to check the keypad fits).
Future<KioskController> pumpKiosk(
  WidgetTester tester, {
  FakeKioskApi? api,
  FakeFaceCamera? camera,
  FakeLocationService? location,
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  final controller = makeController(
    api: api,
    camera: camera,
    location: location,
    timings: widgetTimings,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: buildKioskTheme(),
      home: KioskScreen(controller: controller),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));

  return controller;
}

/// Runs [body] with a mounted kiosk and always releases the widget tree (and
/// its timers) before the test finishes.
Future<void> withKiosk(
  WidgetTester tester,
  Future<void> Function(KioskController controller) body, {
  FakeKioskApi? api,
  FakeFaceCamera? camera,
  FakeLocationService? location,
  Size size = const Size(1280, 800),
}) async {
  final controller = await pumpKiosk(
    tester,
    api: api,
    camera: camera,
    location: location,
    size: size,
  );
  try {
    await body(controller);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    tester.view.reset();
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Future<void> tapDigits(WidgetTester tester, List<String> digits) async {
  for (final digit in digits) {
    await tester.tap(
      find.descendant(of: find.byType(KeypadCard), matching: find.text(digit)),
    );
    await tester.pump();
  }
}

/// Taps [label] after scrolling it into view: the identification selector is
/// scrollable, so on short screens the last option may start below the fold.
Future<void> tapTextScrolling(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tapText(tester, label);
}

void main() {
  group('waiting view', () {
    testWidgets('shows the clock, the kiosk name and the punch types', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        expect(find.text('Tablet Recepción'), findsOneWidget);
        expect(find.text('Construmax · Oficina central'), findsOneWidget);
        expect(find.text('1. Elige el tipo de fichaje'), findsOneWidget);
        expect(find.text('Entrada'), findsOneWidget);
        expect(find.text('Inicio de comida'), findsOneWidget);
        expect(find.text('En espera'), findsOneWidget);
        expect(
          find.text('Selecciona el tipo de fichaje para comenzar.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('picking a punch type reveals the identification selector', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');

        expect(find.text('¿Cómo quieres identificarte?'), findsOneWidget);
        expect(find.text('Tipo: Entrada'), findsOneWidget);
        expect(find.text('Con mi rostro'), findsOneWidget);
        expect(find.text('Con mi número de empleado'), findsOneWidget);
        expect(find.text('En espera'), findsNothing);
        expect(controller.selectedType?.key, 'check_in');

        await tapText(tester, 'Cambiar tipo');

        expect(find.text('¿Cómo quieres identificarte?'), findsNothing);
        expect(find.text('En espera'), findsOneWidget);
      });
    });
  });

  group('keypad', () {
    testWidgets('typing shows the number and Cancelar returns to waiting', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');

        expect(find.byType(KeypadCard), findsOneWidget);
        expect(find.text('NÚMERO DE EMPLEADO'), findsOneWidget);
        expect(find.text(KioskController.personalNotice), findsOneWidget);
        expect(controller.method, IdentificationMethod.employeeNumber);

        await tapDigits(tester, ['1', '2', '3', '4']);

        expect(controller.employeeNumber, '1234');
        expect(find.text('1234'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.backspace_outlined));
        await tester.pump();
        expect(controller.employeeNumber, '123');

        await tapText(tester, 'Cancelar');

        expect(find.byType(KeypadCard), findsNothing);
        expect(find.text('En espera'), findsOneWidget);
        expect(controller.method, isNull);
        expect(controller.employeeNumber, isEmpty);
      });
    });
  });

  group('camera', () {
    testWidgets('choosing the face shows the preview and Cancelar hides it', (
      tester,
    ) async {
      final camera = FakeFaceCamera();
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi rostro');

        expect(
          find.byKey(const ValueKey('fake-camera-preview')),
          findsOneWidget,
        );
        expect(find.text('Capturar'), findsOneWidget);
        expect(find.text(KioskController.faceHint), findsOneWidget);
        expect(controller.method, IdentificationMethod.face);
        expect(camera.initializeCalls, 1);

        await tapText(tester, 'Cancelar');

        expect(find.byKey(const ValueKey('fake-camera-preview')), findsNothing);
        expect(find.text('En espera'), findsOneWidget);
        expect(controller.camera, isNull);
        expect(camera.disposed, isTrue);
      }, camera: camera);
    });

    testWidgets('the preview fills the card on a phone held in landscape', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi rostro');

        expect(tester.takeException(), isNull);

        final previewRect = tester.getRect(
          find.byKey(const ValueKey('fake-camera-preview')),
        );
        final cardRect = tester.getRect(find.byType(CameraCard));

        // The frame covers the card and keeps (almost) all of its height: the
        // overlaid controls no longer squeeze it into a thin strip.
        expect(previewRect.width, closeTo(cardRect.width, 40));
        expect(previewRect.height, greaterThanOrEqualTo(cardRect.height * 0.9));
      }, size: const Size(1024, 600));
    });

    testWidgets('a camera that cannot be opened shows the admin message', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi rostro');

        expect(
          find.text(KioskController.cameraUnavailableMessage),
          findsOneWidget,
        );
        expect(find.text('Capturar'), findsOneWidget);
      }, camera: FakeFaceCamera(ready: false));
    });
  });

  group('success overlay', () {
    testWidgets('shows the confirmation and Cerrar resets the kiosk', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');
        await tapDigits(tester, ['1', '2', '3', '4']);
        await tapText(tester, 'Registrar');

        expect(find.text('¡Registro exitoso!'), findsOneWidget);
        expect(find.text('Ana Torres'), findsOneWidget);
        expect(find.text('Entrada · 08:03'), findsOneWidget);
        expect(find.text('Siguiente sugerido: Inicio de comida'), findsOneWidget);
        expect(
          find.text('Esta ventana se cierra automáticamente en unos segundos.'),
          findsOneWidget,
        );
        // The keypad response carries no biometric similarity.
        expect(find.textContaining('de coincidencia'), findsNothing);
        expect(apiOf(controller).lastEmployeeNumber, '1234');

        await tapText(tester, 'Cerrar');

        expect(find.text('¡Registro exitoso!'), findsNothing);
        expect(find.text('En espera'), findsOneWidget);
        expect(controller.selectedType, isNull);
        expect(controller.lastResult, isNull);
      });
    });

    testWidgets('face: shows the match percentage', (tester) async {
      final api = FakeKioskApi(
        result: const PunchResult(
          userName: 'Ana Torres',
          employeeNumber: 'EMP-0001',
          type: 'check_in',
          typeLabel: 'Entrada',
          punchedAt: '08:03',
          dateLabel: '07/11/2026',
          similarity: 98.42,
        ),
      );

      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi rostro');
        await tapText(tester, 'Capturar');

        expect(find.text('¡Registro exitoso!'), findsOneWidget);
        expect(
          find.text('Identificado por rostro · 98.42% de coincidencia'),
          findsOneWidget,
        );
      }, api: api);
    });

    testWidgets('a punch in flight shows the processing overlay', (
      tester,
    ) async {
      final api = FakeKioskApi()..gate = Completer<void>();

      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');
        await tapDigits(tester, ['1', '2', '3', '4']);

        await tester.tap(find.text('Registrar'));
        await tester.pump();

        expect(find.text('Procesando tu registro…'), findsOneWidget);
        expect(find.text('Esto tarda solo un momento.'), findsOneWidget);

        api.gate!.complete();
        await tester.pump();
        await tester.pump();

        expect(find.text('Procesando tu registro…'), findsNothing);
        expect(find.text('¡Registro exitoso!'), findsOneWidget);
      }, api: api);
    });

    testWidgets('a rejected punch keeps the kiosk on the keypad', (
      tester,
    ) async {
      final api = FakeKioskApi(
        punchError: ApiError.fromResponse(422, {
          'message': 'Datos inválidos.',
          'errors': {
            'employee_number': ['El número de empleado no existe.'],
          },
        }),
      );

      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');
        await tapDigits(tester, ['9']);
        await tapText(tester, 'Registrar');

        expect(find.text('El número de empleado no existe.'), findsOneWidget);
        expect(find.text('¡Registro exitoso!'), findsNothing);
        expect(find.byType(KeypadCard), findsOneWidget);
        // A plain validation error is a banner, never the rejection dialog.
        expect(find.text('Ese registro ya se realizó'), findsNothing);
      }, api: api);
    });
  });

  group('punch rejection', () {
    testWidgets('a 422 shows the already-registered dialog', (tester) async {
      final api = FakeKioskApi(punchError: punchNotAllowedError());

      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');
        await tapDigits(tester, ['1', '0', '0']);
        await tapText(tester, 'Registrar');

        expect(find.text('Ese registro ya se realizó'), findsOneWidget);
        expect(find.text('Entrada · Registrado a las 09:14'), findsOneWidget);
        // The server message already asks for another type: no repeated hint.
        expect(find.text(PunchNotAllowed.hint), findsNothing);
        expect(find.textContaining('Ya registraste tu entrada'), findsOneWidget);

        await tapText(tester, 'Elegir otro registro');

        expect(find.text('Ese registro ya se realizó'), findsNothing);
        expect(find.text('En espera'), findsOneWidget);
        expect(controller.selectedType, isNull);
      }, api: api);
    });

    testWidgets('a dimmed type explains itself without a request', (
      tester,
    ) async {
      final api = FakeKioskApi(punchError: punchNotAllowedError());

      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');
        await tapDigits(tester, ['1', '0', '0']);
        await tapText(tester, 'Registrar');
        await tapText(tester, 'Elegir otro registro');

        final calls = api.punchCalls;

        // The rejected type is dimmed but still tappable: it explains itself.
        await tapText(tester, 'Entrada');

        expect(find.text('Ese registro ya se realizó'), findsOneWidget);
        expect(api.punchCalls, calls);
      }, api: api);
    });
  });

  group('unreachable', () {
    testWidgets('offers a retry that returns to the waiting view', (
      tester,
    ) async {
      final api = FakeKioskApi(pingError: ApiError.unreachable());

      await withKiosk(tester, (controller) async {
        expect(
          find.text('No se pudo conectar con el servidor.'),
          findsOneWidget,
        );
        expect(find.text(KioskController.unreachableHint), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text('En espera'), findsNothing);

        api.pingError = null;
        await tapText(tester, 'Reintentar');

        expect(find.text('No se pudo conectar con el servidor.'), findsNothing);
        expect(find.text('En espera'), findsOneWidget);
      }, api: api);
    });

    testWidgets('offers the face even when the biometric provider is missing', (
      tester,
    ) async {
      final api = FakeKioskApi(context: sampleContext(face: false));

      await withKiosk(tester, (controller) async {
        expect(controller.faceConfigured, isFalse);

        await tapText(tester, 'Entrada');

        expect(find.text('Con mi rostro'), findsOneWidget);
        expect(
          find.text(KioskController.faceNotConfiguredMessage),
          findsOneWidget,
        );
      }, api: api);
    });
  });

  group('location banner', () {
    testWidgets('turns the OS location switch on from the banner', (
      tester,
    ) async {
      final location = FakeLocationService(serviceEnabled: false);

      await withKiosk(tester, (controller) async {
        expect(
          find.text(KioskController.locationDisabledMessage),
          findsOneWidget,
        );
        expect(find.text('Activar'), findsOneWidget);

        await tapText(tester, 'Activar');

        expect(location.locationSettingsOpened, 1);

        // The operator turned the switch on: the banner goes away on refresh.
        location.serviceEnabled = true;
        await controller.refreshLocationState();
        await tester.pump();

        expect(
          find.text(KioskController.locationDisabledMessage),
          findsNothing,
        );
      }, location: location);
    });

    testWidgets('asks for the permission when the switch is already on', (
      tester,
    ) async {
      final location = FakeLocationService(permission: false);

      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Activar');

        expect(location.permissionRequests, 1);
        expect(location.locationSettingsOpened, 0);

        location.permission = true;
        await controller.refreshLocationState();
        await tester.pump();

        expect(
          find.text(KioskController.locationDisabledMessage),
          findsNothing,
        );
      }, location: location);
    });
  });

  group('layout', () {
    testWidgets('the waiting view fits a landscape tablet', (tester) async {
      await withKiosk(tester, (controller) async {
        expect(find.text('En espera'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('the waiting view fits a portrait tablet', (tester) async {
      await withKiosk(tester, (controller) async {
        expect(find.text('1. Elige el tipo de fichaje'), findsOneWidget);
        expect(find.text('En espera'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, size: const Size(800, 1280));
    });

    testWidgets('the camera step fits a short landscape screen', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        expect(find.text('Tipo: Entrada'), findsOneWidget);

        await tapText(tester, 'Con mi rostro');

        expect(find.text('Capturar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, size: const Size(1024, 600));
    });

    testWidgets('the keypad fits a short landscape screen', (tester) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');

        expect(find.text('Registrar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, size: const Size(1024, 600));
    });
  });

  group('small screens', () {
    testWidgets('the keypad takes over the screen on a phone', (tester) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapTextScrolling(tester, 'Con mi número de empleado');

        expect(find.byType(KeypadCard), findsOneWidget);
        // The punch-type grid is hidden, so the keypad owns the viewport.
        expect(find.text('Inicio de comida'), findsNothing);
        expect(find.text('Tipo: Entrada'), findsOneWidget);

        for (final key in ['1', '5', '9', '0']) {
          expect(
            find.descendant(
              of: find.byType(KeypadCard),
              matching: find.text(key),
            ),
            findsOneWidget,
          );
        }

        // Every control is on screen and tappable without scrolling.
        await tester.tap(find.text('Registrar'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.text(KioskController.emptyEmployeeNumberMessage),
          findsOneWidget,
        );
      }, size: const Size(360, 640));
    });
  });
}
