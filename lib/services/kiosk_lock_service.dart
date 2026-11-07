import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Android kiosk hardening that lives in Dart: immersive full screen, the
/// screen always on while the kiosk view is mounted, and the optional
/// "screen pinning" / lock task mode implemented in `MainActivity.kt`.
class KioskLockService {
  const KioskLockService({this.enableLockTask = KioskLockService.lockTaskByDefault});

  /// Lock task mode can only be entered silently on a device-owner tablet;
  /// anywhere else Android shows a confirmation dialog, so it is opt-in:
  ///
  /// ```
  /// flutter build apk --dart-define=KIOSK_LOCK_TASK=true
  /// ```
  static const bool lockTaskByDefault = bool.fromEnvironment(
    'KIOSK_LOCK_TASK',
    defaultValue: false,
  );

  static const MethodChannel _channel = MethodChannel(
    'com.example.kiosco/kiosk',
  );

  final bool enableLockTask;

  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Unsupported platform (desktop/web preview).
    }
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // Best effort: the chrome mode depends on the OEM ROM.
    }
    if (enableLockTask) {
      try {
        await _channel.invokeMethod<bool>('startLockTask');
      } catch (_) {
        // Not whitelisted: the kiosk keeps working without pinning.
      }
    }
  }

  Future<void> disable() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Ignored.
    }
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Ignored.
    }
  }

  /// Brings the kiosk back to the foreground (used by the operator).
  Future<void> bringToFront() async {
    try {
      await _channel.invokeMethod<bool>('bringToFront');
    } catch (_) {
      // Ignored: not running on Android.
    }
  }
}
