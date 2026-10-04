import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'draft.dart';

class PluxeeCameraDenied implements Exception {
  const PluxeeCameraDenied();
}

class PluxeeFix {
  const PluxeeFix({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.denied = false,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final bool denied;
}

Future<PluxeePhoto?> capturePluxeePhoto(String slot) async {
  final picker = ImagePicker();
  try {
    final file = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PluxeePhoto(
      slot: slot,
      capturedAt: DateTime.now().toUtc(),
      bytes: Uint8List.fromList(bytes),
      path: file.path,
    );
  } on PlatformException catch (error) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') ||
        code.contains('access') ||
        code.contains('permission')) {
      throw const PluxeeCameraDenied();
    }
    rethrow;
  }
}

Future<PluxeeFix> capturePluxeeFix() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return PluxeeFix(
      latitude: 0,
      longitude: 0,
      capturedAt: DateTime.now().toUtc(),
      denied: true,
    );
  }
  final position = await Geolocator.getCurrentPosition();
  return PluxeeFix(
    latitude: position.latitude,
    longitude: position.longitude,
    capturedAt: position.timestamp,
  );
}

Future<void> openPluxeeSettings() => Geolocator.openAppSettings();
