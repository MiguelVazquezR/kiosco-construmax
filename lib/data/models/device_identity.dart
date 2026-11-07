/// How the tablet identifies itself to the ERP. Not a secret (§3.2 of the
/// specification): it only keeps every punch traceable.
class DeviceIdentity {
  const DeviceIdentity({required this.key, required this.name});

  static const DeviceIdentity unknown = DeviceIdentity(key: '', name: '');

  /// Android ID.
  final String key;

  /// Device model, e.g. `SM-T500`.
  final String name;

  bool get isKnown => key.isNotEmpty || name.isNotEmpty;

  Map<String, dynamic> toJson() => {
    if (key.isNotEmpty) 'device_key': key,
    if (name.isNotEmpty) 'device_name': name,
  };
}
