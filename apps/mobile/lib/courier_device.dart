import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Kurye uygulamasının `PUT /courier-devices` gövdesine eklediği model ve izinler.
class CourierDeviceReport {
  const CourierDeviceReport({this.model, this.permissions = const {}});

  final String? model;
  final Map<String, bool?> permissions;

  static Future<CourierDeviceReport> collect() async {
    return CourierDeviceReport(
      model: await _model(),
      permissions: {
        'location': await _granted(Permission.location),
        'backgroundLocation': await _granted(Permission.locationAlways),
        'camera': await _granted(Permission.camera),
        'notifications': await _granted(Permission.notification),
      },
    );
  }

  static Future<String?> _model() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final text = '${info.manufacturer} ${info.model}'.trim();
      return text.isEmpty ? null : text;
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      final machine = info.utsname.machine.trim();
      if (machine.isNotEmpty) return machine;
      final model = info.model.trim();
      return model.isEmpty ? null : model;
    }
    return null;
  }

  static Future<bool?> _granted(Permission permission) async {
    try {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) return true;
      if (status.isDenied ||
          status.isPermanentlyDenied ||
          status.isRestricted) {
        return false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
