/// Static configuration of the attendance kiosk app.
///
/// The base URL is a build-time constant so the APK points to the right
/// deployment without touching the screens:
///
/// ```
/// flutter build apk --dart-define=KIOSK_BASE_URL=https://erp.example.com/api/v1/kiosk
/// ```
class KioskConfig {
  const KioskConfig._();

  /// Kiosk API root. Never add a trailing slash: paths are built as
  /// `$baseUrl/punch`, `$baseUrl/ping`, ...
  static const String baseUrl = String.fromEnvironment(
    'KIOSK_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1/kiosk',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 25);
  static const Duration sendTimeout = Duration(seconds: 25);

  /// A punch by face can take a few seconds on AWS, the rest are fast.
  static const Duration facePunchTimeout = Duration(seconds: 40);

  static const Duration pingInterval = Duration(seconds: 60);
  static const Duration bootstrapInterval = Duration(minutes: 5);
  static const Duration unreachableRetryInterval = Duration(seconds: 15);
  static const Duration successOverlayDuration = Duration(seconds: 7);
  static const Duration locationTimeout = Duration(seconds: 10);
  static const Duration clockDriftTolerance = Duration(minutes: 2);

  /// Hard limit accepted by the backend for the whole `photo` string.
  static const int maxPhotoCharacters = 2000000;

  static const int photoMaxSide = 1024;
  static const int photoQuality = 75;
}

/// Intervals the kiosk uses. Injected in tests to keep them fast.
class KioskTimings {
  const KioskTimings({
    this.pingInterval = KioskConfig.pingInterval,
    this.bootstrapInterval = KioskConfig.bootstrapInterval,
    this.unreachableRetryInterval = KioskConfig.unreachableRetryInterval,
    this.successOverlayDuration = KioskConfig.successOverlayDuration,
    this.locationTimeout = KioskConfig.locationTimeout,
    this.clockDriftTolerance = KioskConfig.clockDriftTolerance,
  });

  final Duration pingInterval;
  final Duration bootstrapInterval;
  final Duration unreachableRetryInterval;
  final Duration successOverlayDuration;
  final Duration locationTimeout;
  final Duration clockDriftTolerance;
}
