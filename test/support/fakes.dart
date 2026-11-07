import 'dart:async';

import 'package:kiosco/data/kiosk_api.dart';
import 'package:kiosco/data/models/api_error.dart';
import 'package:kiosco/data/models/device_identity.dart';
import 'package:kiosco/data/models/gps_fix.dart';
import 'package:kiosco/data/models/kiosk_context.dart';
import 'package:kiosco/data/models/punch_result.dart';
import 'package:kiosco/services/device_identity_service.dart';
import 'package:kiosco/services/location_service.dart';

/// The six punch types the ERP returns, in the backend order.
const List<PunchType> demoPunchTypes = [
  PunchType(key: 'check_in', label: 'Entrada'),
  PunchType(key: 'lunch_start', label: 'Inicio de comida'),
  PunchType(key: 'lunch_end', label: 'Fin de comida'),
  PunchType(key: 'break_start', label: 'Permiso / salida'),
  PunchType(key: 'break_end', label: 'Regreso de permiso'),
  PunchType(key: 'check_out', label: 'Salida'),
];

KioskContext sampleContext({
  bool face = true,
  bool employeeNumber = true,
  List<PunchType> types = demoPunchTypes,
}) {
  return KioskContext(
    device: const KioskDevice(
      id: 7,
      name: 'Tablet Recepción',
      location: 'Oficina central',
    ),
    punchTypes: types,
    faceRecognitionEnabled: face,
    employeeNumberEnabled: employeeNumber,
    serverTime: DateTime.now(),
  );
}

const PunchResult sampleResult = PunchResult(
  userName: 'Ana Torres',
  employeeNumber: 'EMP-0001',
  type: 'check_in',
  typeLabel: 'Entrada',
  punchedAt: '08:03',
  dateLabel: '07/11/2026',
  suggestedNext: 'lunch_start',
  suggestedNextLabel: 'Inicio de comida',
  similarity: 97.5,
);

class FakeKioskApi implements KioskApi {
  FakeKioskApi({
    KioskContext? context,
    this.pingError,
    this.bootstrapError,
    this.punchError,
    this.facePunchError,
    this.result = sampleResult,
  }) : context = context ?? sampleContext();

  KioskContext context;
  ApiError? pingError;
  ApiError? bootstrapError;
  ApiError? punchError;
  ApiError? facePunchError;
  PunchResult result;

  int pingCalls = 0;
  int bootstrapCalls = 0;
  int punchCalls = 0;
  int facePunchCalls = 0;
  bool closed = false;

  /// Lets a test hold a request open (double-tap / loading assertions).
  Completer<void>? gate;

  String? lastEmployeeNumber;
  String? lastType;
  String? lastPhoto;
  GpsFix? lastFix;
  DeviceIdentity? lastIdentity;

  @override
  Future<KioskPing> ping() async {
    pingCalls++;
    if (pingError != null) throw pingError!;
    return KioskPing(serverTime: DateTime.now());
  }

  @override
  Future<KioskContext> bootstrap(DeviceIdentity identity) async {
    bootstrapCalls++;
    lastIdentity = identity;
    if (bootstrapError != null) throw bootstrapError!;
    return context;
  }

  @override
  Future<PunchResult> punch({
    required String employeeNumber,
    required String type,
    required GpsFix location,
    required DeviceIdentity identity,
    String? photo,
  }) async {
    punchCalls++;
    lastEmployeeNumber = employeeNumber;
    lastType = type;
    lastFix = location;
    lastIdentity = identity;
    lastPhoto = photo;
    if (gate != null) await gate!.future;
    if (punchError != null) throw punchError!;
    return result;
  }

  @override
  Future<PunchResult> facePunch({
    required String type,
    required String photo,
    required GpsFix location,
    required DeviceIdentity identity,
  }) async {
    facePunchCalls++;
    lastType = type;
    lastPhoto = photo;
    lastFix = location;
    lastIdentity = identity;
    if (gate != null) await gate!.future;
    if (facePunchError != null) throw facePunchError!;
    return result;
  }

  @override
  void close() => closed = true;
}

class FakeIdentityService implements DeviceIdentityService {
  FakeIdentityService({this.identity = const DeviceIdentity(key: 'device-1', name: 'SM-T500')});

  DeviceIdentity identity;
  int calls = 0;

  @override
  Future<DeviceIdentity> load() async {
    calls++;
    return identity;
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService({
    this.fix = const GpsFix(latitude: -12.0464, longitude: -77.0428, accuracy: 6),
    this.permission = true,
    this.serviceEnabled = true,
  });

  GpsFix? fix;
  bool permission;

  /// Whether the OS location switch (GPS) is on.
  bool serviceEnabled;

  int fixCalls = 0;
  int permissionRequests = 0;
  int locationSettingsOpened = 0;
  int appSettingsOpened = 0;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<void> openLocationSettings() async {
    locationSettingsOpened++;
  }

  @override
  Future<void> openAppSettings() async {
    appSettingsOpened++;
  }

  @override
  Future<GpsFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    fixCalls++;
    return fix;
  }
}
