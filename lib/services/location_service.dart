import 'package:geolocator/geolocator.dart';

import '../data/models/gps_fix.dart';

/// GPS access. Abstracted so the kiosk logic and the tests never touch the
/// platform channel.
abstract class LocationService {
  Future<bool> hasPermission();

  Future<bool> requestPermission();

  /// Whether the OS location switch (GPS) is on. Permission can be granted
  /// while the switch is off, and then no fix is possible.
  Future<bool> isServiceEnabled();

  /// Opens the OS screen where the operator turns the location switch on.
  Future<void> openLocationSettings();

  /// Opens the app permission page, used after a permanent denial (the OS no
  /// longer shows the permission dialog).
  Future<void> openAppSettings();

  /// Current fix, or `null` when the permission is denied or it takes longer
  /// than [timeout]. Location is mandatory evidence, so a `null` fix blocks
  /// the punch.
  Future<GpsFix?> currentFix({Duration timeout = const Duration(seconds: 10)});
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> hasPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      // The OS may refuse to open its settings screen; the banner stays.
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      // Same as above: nothing else the kiosk can do.
    }
  }

  @override
  Future<GpsFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      if (!await hasPermission() && !await requestPermission()) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return GpsFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (_) {
      return null;
    }
  }
}
