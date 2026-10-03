import 'package:latlong2/latlong.dart';

import 'geo.dart';
import 'map_config.dart';
import 'models.dart';
import 'road.dart';

/// Kartın varış eşiği — API geofence (200 m) değil, ev CTA’sı.
const geofenceArrivalM = 150;

enum NextStopPhase { enroute, arrived, failed }

class StopAddress {
  const StopAddress({required this.street, this.hood});

  final String street;
  final String? hood;
}

class AppointmentWindow {
  const AppointmentWindow({required this.label, required this.minutesLeft});

  final String label;
  final int? minutesLeft;

  bool get urgent => minutesLeft != null && minutesLeft! < 45;
}

NextStopPhase nextStopPhase({
  required bool selfLocated,
  required bool arrivedManual,
  required int? distanceMeters,
  required TaskStatus status,
}) {
  if (status == TaskStatus.failed) return NextStopPhase.failed;
  if (arrivedManual) return NextStopPhase.arrived;
  if (!selfLocated) return NextStopPhase.enroute;
  if (distanceMeters != null && distanceMeters <= geofenceArrivalM) {
    return NextStopPhase.arrived;
  }
  return NextStopPhase.enroute;
}

int? stopDistanceMeters({
  required DeliveryTask task,
  required double selfLat,
  required double selfLng,
  RoadSlice? slice,
}) {
  if (slice != null) return slice.meters;
  if (!task.hasCoordinates) return null;
  return haversineMeters(
    LatLng(selfLat, selfLng),
    LatLng(task.lat, task.lng),
  ).round();
}

StopAddress parseStopAddress(String raw) {
  var text = raw.trim();
  text = text.replaceFirst(RegExp(r',\s*[^,/]+/\s*[^,]+$'), '').trim();
  final mah = RegExp(r'^(.+?\bMah\.)\s+(.+)$', caseSensitive: false).firstMatch(
    text,
  );
  if (mah != null) {
    return StopAddress(street: mah.group(2)!.trim(), hood: mah.group(1)!.trim());
  }
  return StopAddress(street: text);
}

AppointmentWindow? parseAppointmentWindow(
  String window, {
  int? slaMinutesLeft,
  DateTime? now,
}) {
  final raw = window.trim();
  if (raw.isEmpty || raw == '—') return null;
  final m = RegExp(r'(\d{1,2})[:.](\d{2})\s*[–\-]\s*(\d{1,2})[:.](\d{2})')
      .firstMatch(raw);
  if (m == null) return AppointmentWindow(label: raw, minutesLeft: slaMinutesLeft);
  final a =
      '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  final b =
      '${m.group(3)!.padLeft(2, '0')}:${m.group(4)}';
  var left = slaMinutesLeft;
  if (left == null) {
    final clock = now ?? DateTime.now();
    final end = DateTime(
      clock.year,
      clock.month,
      clock.day,
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
    );
    left = end.difference(clock).inMinutes;
  }
  return AppointmentWindow(label: '$a – $b', minutesLeft: left);
}

String? mapSnapshotUrl({
  required DeliveryTask task,
  required double selfLat,
  required double selfLng,
  List<LatLng>? road,
  int width = 720,
  int height = 280,
}) {
  if (!useMapboxTiles || !task.hasCoordinates) return null;
  final overlays = <String>[
    'pin-s+22C55E(${selfLng.toStringAsFixed(5)},${selfLat.toStringAsFixed(5)})',
    'pin-s+FF7A2F(${task.lng.toStringAsFixed(5)},${task.lat.toStringAsFixed(5)})',
  ];
  if (road != null && road.length > 1) {
    final slim = road.length > 80
        ? [
            for (var i = 0; i < 80; i++)
              road[(i * (road.length - 1) / 79).round()],
          ]
        : road;
    overlays.insert(0, 'path-4+7B61FF(${Uri.encodeComponent(encodePolyline(slim))})');
  }
  return 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/static/'
      '${overlays.join(',')}/auto/${width}x$height@2x?access_token=$kMapboxToken';
}
