/// Recognition method the collaborator picked on step 2.
enum IdentificationMethod { face, employeeNumber }

/// The tablet row the server created or recognized from `device_key`.
class KioskDevice {
  const KioskDevice({required this.id, required this.name, this.location});

  final int id;
  final String name;
  final String? location;

  static KioskDevice? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = json['id'];
    return KioskDevice(
      id: id is int ? id : int.tryParse('$id') ?? 0,
      name: '${json['name'] ?? ''}'.isEmpty ? 'Tablet Android' : '${json['name']}',
      location: '${json['location'] ?? ''}'.isEmpty ? null : '${json['location']}',
    );
  }
}

/// One option of the punch-type selector. The label is rendered, the key is
/// sent to the server.
class PunchType {
  const PunchType({required this.key, required this.label});

  final String key;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is PunchType && other.key == key && other.label == label;

  @override
  int get hashCode => Object.hash(key, label);
}

/// Everything `POST /bootstrap` tells the kiosk.
class KioskContext {
  const KioskContext({
    required this.punchTypes,
    required this.faceRecognitionEnabled,
    required this.employeeNumberEnabled,
    this.device,
    this.appName = 'Construmax',
    this.serverTime,
    this.timezone,
  });

  final KioskDevice? device;

  /// Ordered `key -> label` list, exactly as the server sent it.
  final List<PunchType> punchTypes;

  final bool faceRecognitionEnabled;
  final bool employeeNumberEnabled;
  final String appName;
  final DateTime? serverTime;
  final String? timezone;

  bool get hasAnyMethod =>
      faceRecognitionEnabled || employeeNumberEnabled;

  String get deviceName => device?.name ?? 'Tablet Android';
  String? get deviceLocation => device?.location;

  factory KioskContext.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['punchTypes'];
    final punchTypes = <PunchType>[];

    if (rawTypes is Map) {
      for (final entry in rawTypes.entries) {
        punchTypes.add(
          PunchType(key: '${entry.key}', label: '${entry.value}'),
        );
      }
    }

    return KioskContext(
      device: KioskDevice.fromJson(json['device']),
      punchTypes: punchTypes,
      faceRecognitionEnabled: json['faceRecognitionEnabled'] == true,
      employeeNumberEnabled: json['employeeNumberEnabled'] == true,
      appName: '${json['appName'] ?? 'Construmax'}',
      serverTime: DateTime.tryParse('${json['server_time'] ?? ''}'),
      timezone: json['timezone'] == null ? null : '${json['timezone']}',
    );
  }
}
