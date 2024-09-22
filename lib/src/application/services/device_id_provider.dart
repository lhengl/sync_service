import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

abstract class DeviceIdProvider {
  Future<String> getDeviceId();
}

class DeviceInfoDeviceIdProvider implements DeviceIdProvider {
  const DeviceInfoDeviceIdProvider();
  @override
  Future<String> getDeviceId() async {
    var deviceId = '';
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
    }
    return _cleanFieldName(deviceId);
  }

  // https://firebase.google.com/docs/firestore/quotas#limits
  // If dots are used in field names, then will break the mapping process during an update
  String _cleanFieldName(String fieldName) {
    fieldName = fieldName.replaceAll(RegExp(r'[^\w-]'), '_'); // Replace invalid characters

    // Ensure it doesn't start or end with double underscores
    if (fieldName.startsWith('__')) {
      fieldName = fieldName.substring(2);
    }
    if (fieldName.endsWith('__')) {
      fieldName = fieldName.substring(0, fieldName.length - 2);
    }

    return fieldName;
  }
}

class FakeDeviceIdProvider implements DeviceIdProvider {
  final String deviceId;
  const FakeDeviceIdProvider(this.deviceId);
  @override
  Future<String> getDeviceId() async => deviceId;
}
