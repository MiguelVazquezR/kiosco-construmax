import 'package:device_info_plus/device_info_plus.dart';

import '../data/models/device_identity.dart';

/// Reads the tablet identity sent as `device_key` / `device_name`.
abstract class DeviceIdentityService {
  Future<DeviceIdentity> load();
}

class AndroidDeviceIdentityService implements DeviceIdentityService {
  const AndroidDeviceIdentityService();

  @override
  Future<DeviceIdentity> load() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return DeviceIdentity(key: info.id, name: info.model);
    } catch (_) {
      // Not an Android device (desktop/web preview): the backend accepts a
      // punch without device fields.
      return DeviceIdentity.unknown;
    }
  }
}
