import 'package:kiosco/config/kiosk_config.dart';
import 'package:kiosco/state/kiosk_controller.dart';

import 'camera_fakes.dart';
import 'fakes.dart';

/// Fast timers for pure Dart tests.
const KioskTimings testTimings = KioskTimings(
  pingInterval: Duration(hours: 1),
  bootstrapInterval: Duration(hours: 1),
  unreachableRetryInterval: Duration(milliseconds: 20),
  successOverlayDuration: Duration(milliseconds: 20),
  locationTimeout: Duration(milliseconds: 50),
);

/// Timers used by widget tests: long enough to assert the overlay and to avoid
/// the automatic retry firing during a `pump`.
const KioskTimings widgetTimings = KioskTimings(
  pingInterval: Duration(hours: 1),
  bootstrapInterval: Duration(hours: 1),
  unreachableRetryInterval: Duration(hours: 1),
  successOverlayDuration: Duration(seconds: 5),
  locationTimeout: Duration(milliseconds: 50),
);

KioskController makeController({
  FakeKioskApi? api,
  FakeFaceCamera? camera,
  FakeLocationService? location,
  FakeIdentityService? identity,
  KioskTimings timings = testTimings,
}) {
  return KioskController(
    api: api ?? FakeKioskApi(),
    identityService: identity ?? FakeIdentityService(),
    locationService: location ?? FakeLocationService(),
    cameraFactory: FakeCameraFactory(camera: camera),
    timings: timings,
  );
}

FakeKioskApi apiOf(KioskController controller) =>
    controller.api as FakeKioskApi;

FakeLocationService locationOf(KioskController controller) =>
    controller.locationService as FakeLocationService;

FakeCameraFactory camerasOf(KioskController controller) =>
    controller.cameraFactory as FakeCameraFactory;

FakeFaceCamera cameraOf(KioskController controller) =>
    camerasOf(controller).created.last;
