import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'l10n.dart';
import 'scan.dart';

enum PushPermit { granted, denied, blocked }

PushPermit pushPermitFromStatus(PermissionStatus status) {
  if (status.isGranted || status.isLimited) return PushPermit.granted;
  if (status.isPermanentlyDenied || status.isRestricted) {
    return PushPermit.blocked;
  }
  return PushPermit.denied;
}

bool get _skipHardware {
  try {
    if (inWidgetTest) return true;
    WidgetsBinding.instance;
  } catch (_) {
    return true;
  }
  return false;
}

/// Tek seferlik konum. Sürekli takip yok — vardiya/rota/yenilemede çağrılır.
Future<({double lat, double lng})?> readDeviceLocation() async {
  if (_skipHardware) return null;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever ||
        perm == LocationPermission.unableToDetermine) {
      return null;
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return (lat: p.latitude, lng: p.longitude);
  } catch (_) {
    return null;
  }
}

Future<bool> requestLocationAccess() async {
  if (_skipHardware) return true;
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

Future<bool> requestCameraAccess() async {
  if (_skipHardware) return true;
  try {
    final s = await Permission.camera.request();
    return s.isGranted || s.isLimited;
  } catch (_) {
    return false;
  }
}

Future<PushPermit> readPushPermit() async {
  if (_skipHardware) return PushPermit.granted;
  try {
    return pushPermitFromStatus(await Permission.notification.status);
  } catch (_) {
    return PushPermit.denied;
  }
}

Future<PushPermit> requestPushPermit() async {
  if (_skipHardware) return PushPermit.granted;
  try {
    return pushPermitFromStatus(await Permission.notification.request());
  } catch (_) {
    return PushPermit.denied;
  }
}

Future<bool> requestPushAccess() async =>
    (await requestPushPermit()) == PushPermit.granted;

void explainPushPermit(BuildContext context, PushPermit permit) {
  if (permit == PushPermit.granted || !context.mounted) return;
  final l = L10n.of(context);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          permit == PushPermit.blocked ? l.notifyBlocked : l.notifyDenied,
        ),
        action: permit == PushPermit.blocked
            ? SnackBarAction(
                label: l.openSettings,
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
}
