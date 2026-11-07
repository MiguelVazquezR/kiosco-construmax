import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco/data/models/api_error.dart';
import 'package:kiosco/data/models/kiosk_context.dart';
import 'package:kiosco/state/kiosk_controller.dart';

import 'support/camera_fakes.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  group('start-up', () {
    test('ping + bootstrap move the kiosk to ready', () async {
      final controller = makeController();

      await controller.start();

      expect(controller.status, KioskStatus.ready);
      expect(controller.punchTypes.length, 6);
      expect(controller.punchTypes.first.label, 'Entrada');
      expect(apiOf(controller).pingCalls, 1);
      expect(apiOf(controller).bootstrapCalls, 1);
      expect(controller.errorMessage, isNull);
      expect(controller.identity.key, 'device-1');

      controller.dispose();
    });

    test('an unreachable server shows the retry view', () async {
      final api = FakeKioskApi(pingError: ApiError.unreachable());
      final controller = makeController(api: api);

      await controller.start();

      expect(controller.status, KioskStatus.unreachable);
      expect(controller.errorMessage, ApiError.unreachableMessage);

      controller.dispose();
    });

    test('a failed bootstrap also lands on the retry view', () async {
      final api = FakeKioskApi(
        bootstrapError: ApiError.fromResponse(422, {'message': 'Nope'}),
      );
      final controller = makeController(api: api);

      await controller.start();

      expect(controller.status, KioskStatus.unreachable);
      expect(controller.errorMessage, 'Nope');

      controller.dispose();
    });

    test('recovers by itself once the server is back', () async {
      final api = FakeKioskApi(pingError: ApiError.unreachable());
      final controller = makeController(api: api);

      await controller.start();
      expect(controller.status, KioskStatus.unreachable);

      api.pingError = null;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.status, KioskStatus.ready);
      expect(api.pingCalls, greaterThanOrEqualTo(2));

      controller.dispose();
    });

    test('warns when the device clock drifts from the server', () async {
      final controller = KioskController(
        api: FakeKioskApi(
          context: KioskContext(
            device: null,
            punchTypes: demoPunchTypes,
            faceRecognitionEnabled: true,
            employeeNumberEnabled: true,
            serverTime: DateTime.now().add(const Duration(minutes: 30)),
          ),
        ),
        identityService: FakeIdentityService(),
        locationService: FakeLocationService(),
        cameraFactory: FakeCameraFactory(),
        timings: testTimings,
      );

      await controller.start();

      expect(controller.clockDriftWarning, isTrue);

      controller.dispose();
    });
  });

  group('selection flow', () {
    test('the kiosk waits until the collaborator picks a type', () async {
      final controller = makeController();
      await controller.start();

      expect(controller.isWaiting, isTrue);
      expect(controller.method, isNull);

      controller.selectType(demoPunchTypes.first);
      expect(controller.selectedType?.key, 'check_in');
      expect(controller.isWaiting, isFalse);

      await controller.clearType();
      expect(controller.selectedType, isNull);
      expect(controller.isWaiting, isTrue);

      controller.dispose();
    });

    test('a method cannot be chosen before the punch type', () async {
      final controller = makeController();
      await controller.start();

      await controller.selectMethod(IdentificationMethod.employeeNumber);

      expect(controller.method, isNull);
      expect(controller.errorMessage, KioskController.selectTypeMessage);

      controller.dispose();
    });

    test('choosing the keypad closes the camera', () async {
      final controller = makeController();
      await controller.start();
      controller.selectType(demoPunchTypes.first);

      await controller.selectMethod(IdentificationMethod.employeeNumber);

      expect(controller.method, IdentificationMethod.employeeNumber);
      expect(controller.camera, isNull);

      controller.dispose();
    });

    test('choosing the face opens and releases the camera', () async {
      final controller = makeController();
      await controller.start();
      controller.selectType(demoPunchTypes.first);

      await controller.selectMethod(IdentificationMethod.face);

      final camera = camerasOf(controller).created.single;
      expect(controller.method, IdentificationMethod.face);
      expect(camera.initializeCalls, 1);
      expect(controller.cameraReady, isTrue);

      await controller.resetToWaiting();

      expect(controller.method, isNull);
      expect(controller.camera, isNull);
      expect(camera.disposed, isTrue);

      controller.dispose();
    });

    test('reports a camera that cannot be opened', () async {
      final camera = FakeFaceCamera(ready: false);
      final controller = makeController(camera: camera);
      await controller.start();
      controller.selectType(demoPunchTypes.first);

      await controller.selectMethod(IdentificationMethod.face);

      expect(controller.cameraReady, isFalse);
      expect(controller.errorMessage, KioskController.cameraUnavailableMessage);

      controller.dispose();
    });
  });

  group('punch', () {
    test('keypad: registers, shows the overlay and resets', () async {
      final controller = makeController();
      await controller.start();
      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.employeeNumber);

      controller.appendKey('E');
      controller.appendKey('1');
      controller.deleteLastKey();
      controller.appendKey('MP-1');
      controller.clearNumber();
      controller.appendKey('EMP-0001');

      expect(controller.employeeNumber, 'EMP-0001');

      await controller.submitEmployeeNumber();

      final api = apiOf(controller);
      expect(api.punchCalls, 1);
      expect(api.lastEmployeeNumber, 'EMP-0001');
      expect(api.lastType, 'check_in');
      expect(api.lastFix?.latitude, -12.0464);
      expect(controller.lastResult?.userName, 'Ana Torres');
      expect(controller.isSubmitting, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(controller.lastResult, isNull);
      expect(controller.selectedType, isNull);
      expect(controller.method, isNull);
      expect(controller.isWaiting, isTrue);

      controller.dispose();
    });

    test('blocks the punch when the GPS fix is missing', () async {
      final location = FakeLocationService(fix: null);
      final controller = makeController(location: location);
      await controller.start();
      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.employeeNumber);
      controller.appendKey('EMP-0001');

      await controller.submitEmployeeNumber();

      expect(location.fixCalls, 1);
      expect(apiOf(controller).punchCalls, 0);
      expect(controller.errorMessage, KioskController.locationErrorMessage);
      expect(controller.locationPermissionMissing, isTrue);
      expect(controller.lastResult, isNull);

      controller.dispose();
    });

    test('surfaces the employee-number validation message', () async {
      final api = FakeKioskApi(
        punchError: ApiError.fromResponse(422, {
          'message': 'Datos inválidos.',
          'errors': {
            'employee_number': ['El número de empleado no existe.'],
          },
        }),
      );
      final controller = makeController(api: api);
      await controller.start();
      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.employeeNumber);
      controller.appendKey('NOPE');

      await controller.submitEmployeeNumber();

      expect(controller.errorMessage, 'El número de empleado no existe.');
      expect(controller.lastResult, isNull);
      expect(controller.isSubmitting, isFalse);
      expect(controller.employeeNumber, 'NOPE');

      controller.dispose();
    });

    test('ignores a second tap while the request is in flight', () async {
      final api = FakeKioskApi()..gate = Completer<void>();
      final controller = makeController(api: api);
      await controller.start();
      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.employeeNumber);
      controller.appendKey('EMP-0001');

      final first = controller.submitEmployeeNumber();
      await controller.submitEmployeeNumber();
      api.gate!.complete();
      await first;

      expect(api.punchCalls, 1);

      controller.dispose();
    });

    test('face: sends the captured photo', () async {
      final camera = FakeFaceCamera(
        capturedDataUrl: 'data:image/jpeg;base64,ZmFrZQ==',
      );
      final controller = makeController(camera: camera);
      await controller.start();
      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.face);

      await controller.submitFace();

      final api = apiOf(controller);
      expect(camera.captureCalls, 1);
      expect(api.facePunchCalls, 1);
      expect(api.lastPhoto, 'data:image/jpeg;base64,ZmFrZQ==');
      expect(api.lastType, 'check_in');
      expect(controller.lastResult?.typeLabel, 'Entrada');

      controller.dispose();
    });

    test('face: reports a frame that could not be captured', () async {
      final camera = FakeFaceCamera(capturedDataUrl: null);
      final controller = makeController(camera: camera);
      await controller.start();
      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.face);

      await controller.submitFace();

      expect(apiOf(controller).facePunchCalls, 0);
      expect(controller.errorMessage, KioskController.cameraFailedMessage);
      expect(controller.isSubmitting, isFalse);

      controller.dispose();
    });

    test('an unreachable punch switches to the retry view', () async {
      final api = FakeKioskApi(punchError: ApiError.unreachable());
      final controller = makeController(api: api);
      await controller.start();
      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.employeeNumber);
      controller.appendKey('EMP-0001');

      await controller.submitEmployeeNumber();

      expect(controller.status, KioskStatus.unreachable);
      expect(controller.isSubmitting, isFalse);
      expect(controller.method, isNull);

      controller.dispose();
    });
  });

  group('location banner', () {
    test('flags the banner while the OS switch is off', () async {
      final location = FakeLocationService(serviceEnabled: false);
      final controller = makeController(location: location);

      await controller.start();

      expect(controller.locationPermissionMissing, isTrue);

      await controller.enableLocation();

      expect(location.locationSettingsOpened, 1);
      expect(location.permissionRequests, 0);
      // The OS screen was opened but the switch is still off.
      expect(controller.locationPermissionMissing, isTrue);
      expect(controller.isEnablingLocation, isFalse);

      // The operator turns it on and comes back to the kiosk.
      location.serviceEnabled = true;
      await controller.refreshLocationState();

      expect(controller.locationPermissionMissing, isFalse);

      controller.dispose();
    });

    test('requests the permission when only the permission is missing',
        () async {
      final location = FakeLocationService(permission: false);
      final controller = makeController(location: location);

      await controller.start();

      expect(controller.locationPermissionMissing, isTrue);

      await controller.enableLocation();

      expect(location.locationSettingsOpened, 0);
      expect(location.permissionRequests, 1);
      // Still denied, so the app settings page is the last resort.
      expect(location.appSettingsOpened, 1);
      expect(controller.locationPermissionMissing, isTrue);

      controller.dispose();
    });

    test('a permission granted in the OS clears the banner', () async {
      final location = FakeLocationService(permission: false);
      final controller = makeController(location: location);

      await controller.start();
      expect(controller.locationPermissionMissing, isTrue);

      // The operator grants it from the system dialog/settings and the kiosk
      // re-reads the state when it comes back to the foreground.
      location.permission = true;
      await controller.refreshLocationState();

      expect(controller.locationPermissionMissing, isFalse);
      expect(location.locationSettingsOpened, 0);

      controller.dispose();
    });
  });

  group('identification methods', () {
    test('the face is offered even without the biometric provider', () async {
      final controller = makeController(
        api: FakeKioskApi(context: sampleContext(face: false)),
      );

      await controller.start();

      expect(controller.faceAvailable, isTrue);
      expect(controller.faceConfigured, isFalse);

      controller.selectType(demoPunchTypes.first);
      await controller.selectMethod(IdentificationMethod.face);

      expect(controller.method, IdentificationMethod.face);
      expect(camerasOf(controller).created, hasLength(1));
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });

    test('the face is configured when the server says so', () async {
      final controller = makeController();

      await controller.start();

      expect(controller.faceAvailable, isTrue);
      expect(controller.faceConfigured, isTrue);

      controller.dispose();
    });
  });

}
