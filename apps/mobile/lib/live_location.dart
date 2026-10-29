import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'geo.dart';
import 'scan.dart';

/// Canlı takip için tek konum ölçümü.
class LiveFix {
  const LiveFix({
    required this.lat,
    required this.lng,
    required this.at,
    this.accuracy,
    this.heading,
    this.speed,
    this.mocked = false,
  });

  final double lat;
  final double lng;
  final DateTime at;
  final double? accuracy;
  final double? heading;
  final double? speed;

  /// Android'de sahte konum sağlayıcısından geldi.
  final bool mocked;
}

/// Kurye API kuralı: canlı konum en fazla 30 sn'de bir ve yaklaşık 50 m
/// hareketten sonra gönderilir. İlk ölçüm hemen gider.
bool shouldSendLiveFix(LiveFix? last, LiveFix next) {
  if (last == null) return true;
  if (next.at.difference(last.at) < const Duration(seconds: 30)) return false;
  final moved = haversineMeters(
    LatLng(last.lat, last.lng),
    LatLng(next.lat, next.lng),
  );
  return moved >= 50;
}

/// Sunucu yalnız taze konumu kabul eder (son 5 dk); çevrimdışı birikmiş
/// eski ölçümler gönderilmez.
bool isFreshLiveFix(LiveFix fix, DateTime now) =>
    now.difference(fix.at) < const Duration(minutes: 5);

/// Cihazın konum akışı (uygulama ön plandayken). İzin ya da konum servisi
/// yoksa boş akış döner; izin burada istenmez, izin ekranında alınır.
Stream<LiveFix> liveFixStream() async* {
  if (inWidgetTest) return;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return;
    }
  } catch (_) {
    return;
  }
  // Vardiya / görev sürerken ekran kilitlense ya da uygulama arka plana geçse de
  // konum akmaya devam eder: Android'de kalıcı bildirimli ön plan servisi,
  // iOS'ta arka plan konum güncellemesi (mavi durum çubuğu göstergesiyle).
  final LocationSettings settings = switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
      intervalDuration: const Duration(seconds: 15),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Dijigoo vardiyası açık',
        notificationText:
            'Vardiya ve görev boyunca konumunuz şubeyle paylaşılıyor.',
        enableWakeLock: true,
      ),
    ),
    TargetPlatform.iOS => AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
      activityType: ActivityType.automotiveNavigation,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
      pauseLocationUpdatesAutomatically: false,
    ),
    _ => const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    ),
  };
  yield* Geolocator.getPositionStream(locationSettings: settings).map(
    (p) => LiveFix(
      lat: p.latitude,
      lng: p.longitude,
      at: p.timestamp,
      accuracy: p.accuracy,
      heading: p.heading,
      speed: p.speed,
      mocked: p.isMocked,
    ),
  );
}
