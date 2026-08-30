import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

Future<void> callRecipient(BuildContext context) async {
  final uri = Uri(scheme: 'tel', path: '+905321110026');
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aranıyor…')));
  }
}

Future<void> openDirections(BuildContext context, DeliveryTask task) async {
  final apple = Uri.parse('https://maps.apple.com/?daddr=${task.lat},${task.lng}&dirflg=d');
  final google = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${task.lat},${task.lng}',
  );
  final geo = Uri.parse('geo:${task.lat},${task.lng}?q=${task.lat},${task.lng}');

  final appleOs = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
  final primary = appleOs ? apple : geo;
  var ok = await launchUrl(primary, mode: LaunchMode.externalApplication);
  if (!ok) {
    ok = await launchUrl(google, mode: LaunchMode.externalApplication);
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yol tarifi açılıyor…')));
  }
}
