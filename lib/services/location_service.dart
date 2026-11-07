import 'package:geolocator/geolocator.dart';

import '../data/models/gps_fix.dart';

/// GPS access. Abstracted so the kiosk logic and the tests never touch the
/// platform channel.
abstract class LocationService {
  Future<bool> hasPermission();

  Future<bool> requestPermission();

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
