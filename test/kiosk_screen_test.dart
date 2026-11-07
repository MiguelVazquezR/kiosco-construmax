import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco/data/models/api_error.dart';
import 'package:kiosco/data/models/kiosk_context.dart';
import 'package:kiosco/state/kiosk_controller.dart';
import 'package:kiosco/ui/kiosk_screen.dart';
import 'package:kiosco/ui/kiosk_theme.dart';
import 'package:kiosco/ui/widgets/keypad_card.dart';

import 'support/camera_fakes.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

/// Mounts the kiosk on a landscape tablet surface (1280×800).
Future<KioskController> pumpKiosk(
  WidgetTester tester, {
  FakeKioskApi? api,
  FakeFaceCamera? camera,
  FakeLocationService? location,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
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
}) async {
  final controller = await pumpKiosk(
    tester,
    api: api,
    camera: camera,
    location: location,
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
    testWidgets('shows the confirmation and Continuar resets the kiosk', (
      tester,
    ) async {
      await withKiosk(tester, (controller) async {
        await tapText(tester, 'Entrada');
        await tapText(tester, 'Con mi número de empleado');
        await tapDigits(tester, ['1', '2', '3', '4']);
        await tapText(tester, 'Registrar');

        expect(find.text('Registro exitoso'), findsOneWidget);
        expect(find.text('Ana Torres'), findsOneWidget);
        expect(find.text('Entrada · 08:03'), findsOneWidget);
        expect(apiOf(controller).lastEmployeeNumber, '1234');

        await tapText(tester, 'Continuar');

        expect(find.text('Registro exitoso'), findsNothing);
        expect(find.text('En espera'), findsOneWidget);
        expect(controller.selectedType, isNull);
        expect(controller.lastResult, isNull);
      });
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
        expect(find.text('Registro exitoso'), findsNothing);
        expect(find.byType(KeypadCard), findsOneWidget);
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

    testWidgets('warns when no identification method is enabled', (
      tester,
    ) async {
      final api = FakeKioskApi(
        context: sampleContext(face: false, employeeNumber: false),
      );

      await withKiosk(tester, (controller) async {
        expect(find.text('Sin método de registro'), findsOneWidget);
        expect(find.text(KioskController.noMethodMessage), findsOneWidget);
      }, api: api);
    });
  });
}
