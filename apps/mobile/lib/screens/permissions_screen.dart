import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../locate.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  final granted = <String>{};
  bool _busy = false;

  List<(IconData, String, String, String)> _items(L10n l) => [
    (LucideIcons.mapPin, l.permLocation, l.permLocationHint, 'loc'),
    (LucideIcons.camera, l.permCamera, l.permCameraHint, 'cam'),
    (LucideIcons.bell, l.permPush, l.permPushHint, 'push'),
  ];

  Future<bool> _ask(String key) async {
    return switch (key) {
      'loc' => requestLocationAccess(),
      'cam' => requestCameraAccess(),
      'push' => requestPushAccess(),
      _ => false,
    };
  }

  Future<void> _grantOne(String key) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (key == 'push') {
      final permit = await requestPushPermit();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (permit == PushPermit.granted) granted.add(key);
      });
      explainPushPermit(context, permit);
      return;
    }
    final ok = await _ask(key);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) granted.add(key);
    });
  }

  Future<void> _grantAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    PushPermit? push;
    for (final key in ['loc', 'cam', 'push']) {
      if (granted.contains(key)) continue;
      if (key == 'push') {
        push = await requestPushPermit();
        if (push == PushPermit.granted) granted.add(key);
        continue;
      }
      final ok = await _ask(key);
      if (ok) granted.add(key);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (push != null) explainPushPermit(context, push);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items(l);
    final ready = granted.length == items.length;
    return Scaffold(
      appBar: AppBar(title: Text(l.devicePermissions)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            l.permissionsIntro,
            style: TextStyle(fontSize: 16, color: Dg.ink2, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            l.readyOf(granted.length, items.length),
            style: Dg.ui(size: 13, weight: FontWeight.w600, color: Dg.ink3),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: granted.length / items.length,
              minHeight: 6,
              backgroundColor: Dg.elev,
              valueColor: const AlwaysStoppedAnimation(Dg.primaryGradientStart),
            ),
          ),
          const SizedBox(height: 18),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                onTap: _busy ? null : () => _grantOne(item.$4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: granted.contains(item.$4)
                            ? Dg.violetBg
                            : Dg.elev,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.$1,
                        size: 20,
                        color: granted.contains(item.$4) ? Dg.violet : Dg.ink2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: TextStyle(color: Dg.ink2, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      granted.contains(item.$4)
                          ? LucideIcons.circleCheck
                          : LucideIcons.circle,
                      color: granted.contains(item.$4)
                          ? Dg.primaryGradientStart
                          : Dg.ink3,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          DgButton(
            label: ready ? l.goToShift : l.grantAllThree,
            icon: ready ? LucideIcons.arrowRight : LucideIcons.shield,
            onPressed: _busy
                ? null
                : ready
                ? () => ref.read(sessionProvider).completePermissions()
                : _grantAll,
          ),
        ],
      ),
    );
  }
}
