import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/kiosk_config.dart';
import '../data/kiosk_api.dart';
import '../data/models/api_error.dart';
import '../data/models/device_identity.dart';
import '../data/models/gps_fix.dart';
import '../data/models/kiosk_context.dart';
import '../data/models/punch_result.dart';
import '../services/camera_service.dart';
import '../services/device_identity_service.dart';
import '../services/location_service.dart';
import '../services/photo_encoder.dart';

/// `checking → ready → (punch flow) → ready`, with `unreachable` as the only
/// blocker (§6 of the specification).
enum KioskStatus { checking, ready, unreachable }

/// State machine and punch flow of the single kiosk screen.
class KioskController extends ChangeNotifier {
  KioskController({
    required this.api,
    required this.identityService,
    required this.locationService,
    required this.cameraFactory,
    this.timings = const KioskTimings(),
  });

  final KioskApi api;
  final DeviceIdentityService identityService;
  final LocationService locationService;
  final FaceCameraFactory cameraFactory;
  final KioskTimings timings;

  static const String verifyingMessage = 'Verificando conexión…';
  static const String unreachableTitle = 'No se pudo conectar con el servidor.';
  static const String unreachableHint = 'Verifica la red del dispositivo.';
  static const String locationErrorMessage =
      'No se pudo obtener la ubicación del dispositivo. Activa la ubicación e intenta de nuevo.';
  static const String clockDriftMessage =
      'La fecha y hora del dispositivo no son correctas. Pide al administrador que las ajustes.';
  static const String noMethodMessage =
      'El kiosco no tiene un método de registro activo. Pide ayuda al administrador.';
  static const String cameraUnavailableMessage =
      'No se pudo abrir la cámara. Pide ayuda al administrador.';
  static const String cameraFailedMessage =
      'No se pudo tomar la fotografía. Intenta de nuevo.';
  static const String emptyEmployeeNumberMessage =
      'Escribe tu número de empleado.';
  static const String selectTypeMessage =
      'Selecciona el tipo de fichaje para continuar.';
  static const String personalNotice =
      'El registro es personal e individual. No registres la asistencia de otra persona.';
  static const String faceHint =
      'Colócate de frente a la cámara, con buena iluminación.';

  KioskStatus _status = KioskStatus.checking;
  KioskContext? _context;
  DeviceIdentity _identity = DeviceIdentity.unknown;
  PunchType? _selectedType;
  IdentificationMethod? _method;
  String _employeeNumber = '';
  String? _error;
  PunchResult? _lastResult;
  FaceCamera? _camera;
  bool _cameraReady = false;
  bool _isLocating = false;
  bool _isSubmitting = false;
  bool _clockDriftWarning = false;
  bool _locationPermissionMissing = false;
  bool _disposed = false;

  Timer? _pingTimer;
  Timer? _bootstrapTimer;
  Timer? _retryTimer;
  Timer? _overlayTimer;

  KioskStatus get status => _status;
  KioskContext? get context => _context;
  DeviceIdentity get identity => _identity;
  PunchType? get selectedType => _selectedType;
  IdentificationMethod? get method => _method;
  String get employeeNumber => _employeeNumber;
  String? get errorMessage => _error;
  PunchResult? get lastResult => _lastResult;
  FaceCamera? get camera => _camera;
  bool get cameraReady => _cameraReady;
  bool get isLocating => _isLocating;
  bool get isSubmitting => _isSubmitting;
  bool get clockDriftWarning => _clockDriftWarning;
  bool get locationPermissionMissing => _locationPermissionMissing;

  /// True while the kiosk waits for a punch type / method ("En espera").
  bool get isWaiting => _method == null && _selectedType == null;

  String get deviceName => _context?.deviceName ?? 'Tablet Android';
  String? get deviceLocation => _context?.deviceLocation;
  String get appName => _context?.appName ?? 'Construmax';

  List<PunchType> get punchTypes => _context?.punchTypes ?? const [];

  bool get faceEnabled => _context?.faceRecognitionEnabled ?? false;
  bool get employeeNumberEnabled =>
      _context?.employeeNumberEnabled ?? false;

  /// `ping` + `bootstrap`, then the kiosk is ready. Called on start-up, on
  /// every automatic retry and from the `unreachable` view.
  Future<void> start() async {
    _retryTimer?.cancel();
    _stopRuntimeTimers();
    _status = KioskStatus.checking;
    _error = null;
    _notify();

    try {
      _identity = await identityService.load();
      final ping = await api.ping();
      _checkClockDrift(ping.serverTime);

      final context = await api.bootstrap(_identity);
      _context = context;
      _checkClockDrift(context.serverTime ?? ping.serverTime);
      _locationPermissionMissing = !await locationService.hasPermission();
      if (_disposed) return;

      _status = KioskStatus.ready;
      _scheduleRuntimeTimers();
    } on ApiError catch (error) {
      if (_disposed) return;
      _status = KioskStatus.unreachable;
      _error = error.message;
      _scheduleRetry();
    } catch (_) {
      if (_disposed) return;
      _status = KioskStatus.unreachable;
      _error = ApiError.unreachableMessage;
      _scheduleRetry();
    }

    _notify();
  }

  Future<void> retry() => start();

  void selectType(PunchType type) {
    if (_isSubmitting) return;
    _selectedType = type;
    _error = null;
    _notify();
  }

  /// "Cambiar tipo": back to the type selector and the waiting view.
  Future<void> clearType() async {
    if (_isSubmitting) return;
    _selectedType = null;
    await _clearIdentification();
    _error = null;
    _notify();
  }

  Future<void> selectMethod(IdentificationMethod method) async {
    if (_isSubmitting) return;
    if (_selectedType == null) {
      _error = selectTypeMessage;
      _notify();
      return;
    }

    _method = method;
    _employeeNumber = '';
    _error = null;
    _notify();

    if (method == IdentificationMethod.face) {
      await _openCamera();
    } else {
      await _closeCamera();
    }
  }

  /// Dismisses the camera preview or the keypad and returns to "En espera".
  Future<void> resetToWaiting() async {
    if (_isSubmitting) return;
    await _clearIdentification();
    _error = null;
    _notify();
  }

  void appendKey(String key) {
    if (_isSubmitting) return;
    if (_employeeNumber.length >= 50) return;
    _employeeNumber = '$_employeeNumber$key';
    _error = null;
    _notify();
  }

  void deleteLastKey() {
    if (_isSubmitting || _employeeNumber.isEmpty) return;
    _employeeNumber = _employeeNumber.substring(0, _employeeNumber.length - 1);
    _notify();
  }

  void clearNumber() {
    if (_isSubmitting) return;
    _employeeNumber = '';
    _notify();
  }

  /// Punch by employee number (keypad).
  Future<void> submitEmployeeNumber() async {
    final type = _selectedType;
    if (_isSubmitting || type == null) return;

    final employeeNumber = _employeeNumber.trim();
    if (employeeNumber.isEmpty) {
      _error = emptyEmployeeNumberMessage;
      _notify();
      return;
    }

    await _submitWithLocation(
      (fix) => api.punch(
        employeeNumber: employeeNumber,
        type: type.key,
        location: fix,
        identity: _identity,
      ),
    );
  }

  /// Captures the camera frame and punches by face.
  Future<void> submitFace() async {
    final type = _selectedType;
    final camera = _camera;
    if (_isSubmitting || type == null || camera == null) return;

    _error = null;
    _isSubmitting = true;
    _notify();

    String? photo;
    try {
      photo = await camera.capture();
    } on PhotoEncodingException catch (error) {
      photo = null;
      _error = error.message;
    } catch (_) {
      photo = null;
    }

    if (photo == null) {
      _isSubmitting = false;
      _error ??= cameraFailedMessage;
      _notify();
      return;
    }

    final dataUrl = photo;
    _isSubmitting = false;
    await _submitWithLocation(
      (fix) => api.facePunch(
        type: type.key,
        photo: dataUrl,
        location: fix,
        identity: _identity,
      ),
    );
  }

  /// Hides the success overlay and returns to the waiting view.
  Future<void> dismissSuccess() async {
    _overlayTimer?.cancel();
    _lastResult = null;
    _selectedType = null;
    await _clearIdentification();
    _error = null;
    _notify();
  }

  Future<void> _submitWithLocation(
    Future<PunchResult> Function(GpsFix fix) send,
  ) async {
    if (_isSubmitting) return;

    _isSubmitting = true;
    _isLocating = true;
    _error = null;
    _notify();

    try {
      final fix = await locationService.currentFix(
        timeout: timings.locationTimeout,
      );
      _isLocating = false;
      _notify();

      if (fix == null) {
        _isSubmitting = false;
        _locationPermissionMissing = true;
        _error = locationErrorMessage;
        _notify();
        return;
      }

      final result = await send(fix);
      _isSubmitting = false;
      _lastResult = result;
      _notify();

      _overlayTimer?.cancel();
      _overlayTimer = Timer(timings.successOverlayDuration, () {
        _lastResult = null;
        _selectedType = null;
        _clearIdentification();
        _notify();
      });
    } on ApiError catch (error) {
      _isSubmitting = false;
      _isLocating = false;

      if (error.isUnreachable) {
        await _goUnreachable(error);
        return;
      }

      _error = _punchErrorMessage(error);
      _notify();
    } catch (_) {
      _isSubmitting = false;
      _isLocating = false;
      _error = cameraFailedMessage;
      _notify();
    }
  }

  /// Validation keys mapped to their UI slot, most specific first (§5).
  String _punchErrorMessage(ApiError error) {
    const keys = [
      'employee_number',
      'face',
      'photo',
      'user',
      'type',
      'latitude',
      'longitude',
    ];

    for (final key in keys) {
      final messages = error.fieldErrors[key];
      if (messages != null && messages.isNotEmpty) return messages.first;
    }

    if (error.isThrottled) return ApiError.throttleMessage;
    return error.message;
  }

  Future<void> _goUnreachable(ApiError error) async {
    _status = KioskStatus.unreachable;
    _error = error.message;
    _stopRuntimeTimers();
    await _clearIdentification();
    _scheduleRetry();
    _notify();
  }

  Future<void> _openCamera() async {
    await _closeCamera();
    final camera = cameraFactory.create();
    _camera = camera;
    try {
      await camera.initialize();
    } catch (_) {
      // Reported through the ready check below.
    }
    _cameraReady = camera.isReady;
    if (!_cameraReady) _error = cameraUnavailableMessage;
    _notify();
  }

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    _cameraReady = false;
    try {
      await camera?.dispose();
    } catch (_) {
      // Already released.
    }
  }

  Future<void> _clearIdentification() async {
    _method = null;
    _employeeNumber = '';
    await _closeCamera();
  }

  void _checkClockDrift(DateTime? serverTime) {
    if (serverTime == null) return;
    final drift = serverTime.difference(DateTime.now()).abs();
    _clockDriftWarning = drift > timings.clockDriftTolerance;
  }

  void _scheduleRuntimeTimers() {
    _stopRuntimeTimers();
    _pingTimer = Timer.periodic(timings.pingInterval, (_) => _pingQuietly());
    _bootstrapTimer = Timer.periodic(
      timings.bootstrapInterval,
      (_) => _bootstrapQuietly(),
    );
  }

  void _stopRuntimeTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _bootstrapTimer?.cancel();
    _bootstrapTimer = null;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(timings.unreachableRetryInterval, start);
  }

  Future<void> _pingQuietly() async {
    try {
      final ping = await api.ping();
      _checkClockDrift(ping.serverTime);
      _notify();
    } on ApiError catch (error) {
      if (error.isUnreachable) await _goUnreachable(error);
    } catch (_) {
      await _goUnreachable(ApiError.unreachable());
    }
  }

  Future<void> _bootstrapQuietly() async {
    try {
      _context = await api.bootstrap(_identity);
      _notify();
    } on ApiError catch (error) {
      if (error.isUnreachable) await _goUnreachable(error);
    } catch (_) {
      await _goUnreachable(ApiError.unreachable());
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pingTimer?.cancel();
    _bootstrapTimer?.cancel();
    _retryTimer?.cancel();
    _overlayTimer?.cancel();
    _closeCamera();
    api.close();
    super.dispose();
  }
}
