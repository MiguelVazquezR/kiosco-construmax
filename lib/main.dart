import 'package:flutter/material.dart';

import 'config/kiosk_config.dart';
import 'data/kiosk_api.dart';
import 'services/camera_service.dart';
import 'services/device_identity_service.dart';
import 'services/kiosk_lock_service.dart';
import 'services/location_service.dart';
import 'state/kiosk_controller.dart';
import 'ui/kiosk_screen.dart';
import 'ui/kiosk_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const KioskLockService().enable();
  runApp(const KioskApp());
}

/// The app opens straight into the kiosk: no login, no setup screen and no
/// navigation stack.
class KioskApp extends StatefulWidget {
  const KioskApp({super.key, this.controllerBuilder});

  /// Injected by tests so the app never needs the platform channels.
  final KioskController Function()? controllerBuilder;

  @override
  State<KioskApp> createState() => _KioskAppState();
}

class _KioskAppState extends State<KioskApp> {
  late KioskController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerBuilder?.call() ?? buildKioskController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiosco de asistencia',
      debugShowCheckedModeBanner: false,
      theme: buildKioskTheme(),
      home: KioskScreen(controller: _controller),
    );
  }
}

/// Production wiring of the kiosk dependencies.
KioskController buildKioskController() {
  return KioskController(
    api: DioKioskApi(baseUrl: KioskConfig.baseUrl),
    identityService: const AndroidDeviceIdentityService(),
    locationService: const GeolocatorLocationService(),
    cameraFactory: const DeviceFaceCameraFactory(),
  );
}
