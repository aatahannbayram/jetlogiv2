import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';
import 'models.dart';

Future<void> dialNumber(BuildContext context, String? phone) async {
  final raw = (phone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
  if (raw.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.noRecipientPhone)));
    }
    return;
  }
  final uri = Uri(scheme: 'tel', path: raw);
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.callOpening)));
  }
}

/// Belge / PDF bağlantısını tarayıcıda açar; açılamazsa uyarı gösterir.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok =
      uri != null &&
      uri.hasScheme &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.linkOpenFailed)));
  }
}

Future<void> callRecipient(BuildContext context, {String? phone}) =>
    dialNumber(context, phone);

Future<void> openDirections(BuildContext context, DeliveryTask task) async {
  // Koordinat yoksa (0,0) adresle aranır; yoksa harita okyanusa gider.
  final dest = task.hasCoordinates
      ? '${task.lat},${task.lng}'
      : Uri.encodeComponent(task.address);
  final apple = Uri.parse('https://maps.apple.com/?daddr=$dest&dirflg=d');
  final google = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving',
  );
  // Android: haritada nokta göstermek yerine doğrudan yol tarifini başlatır.
  final geo = Uri.parse('google.navigation:q=$dest&mode=d');

  final appleOs =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  final primary = appleOs ? apple : (kIsWeb ? google : geo);
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Google Haritalar kurulu değilse şema açılamaz; sıradakine geçilir.
      return false;
    }
  }

  final ok = await open(primary) || await open(google);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.mapsUnavailable)));
  }
}
