import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/screens/menu_screen.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/theme.dart';
import 'package:dijigoo_kurye/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  tearDown(() => Dg.dark = false);

  for (final dark in [false, true]) {
    for (final config in [
      (375.0, 812.0, 1.0),
      (812.0, 375.0, 1.0),
      (320.0, 568.0, 2.0),
      (430.0, 932.0, 2.0),
    ]) {
      final name =
          'menu-dock-${dark ? 'dark' : 'light'}-${config.$1.toInt()}-${config.$3.toInt()}x';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = Size(config.$1, config.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Dg.dark = dark;
        final session = SessionController()..skipToDemo();
        final boundary = GlobalKey();
        var index = 4;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionProvider.overrideWith((ref) => session)],
            child: L10nScope(
              l10n: const L10n('tr'),
              child: MaterialApp(
                theme: Dg.theme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(config.$3),
                    disableAnimations: true,
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                  ),
                  child: RepaintBoundary(key: boundary, child: child!),
                ),
                home: StatefulBuilder(
                  builder: (context, setState) => Scaffold(
                    body: const MenuScreen(),
                    bottomNavigationBar: DgPillNav(
                      primaryIndex: 2,
                      index: index,
                      onChanged: (value) => setState(() => index = value),
                      badges: const [0, 0, 0, 12, 0],
                      items: const [
                        (LucideIcons.house, LucideIcons.house, 'Ana sayfa'),
                        (LucideIcons.truck, LucideIcons.truck, 'Rota'),
                        (LucideIcons.qrCode, LucideIcons.qrCode, 'Tara'),
                        (LucideIcons.bell, LucideIcons.bell, 'Bildirim'),
                        (LucideIcons.menu, LucideIcons.menu, 'Menü'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        final nav = find.byType(DgPillNav);
        if (config.$3 == 1) {
          // The dock stays compact and leaves the page its full reading area.
          expect(tester.getSize(nav).height, lessThanOrEqualTo(110));
        }
        final route = find.descendant(of: nav, matching: find.text('Rota'));
        final target = find
            .ancestor(of: route, matching: find.byType(InkWell))
            .first;
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
        expect(
          tester.getRect(target).bottom,
          lessThanOrEqualTo(config.$2 - 24),
        );
        final out = Platform.environment['JETLOGI_SCREENSHOTS'];
        if (out != null) {
          await tester.runAsync(() async {
            await precacheImage(
              const AssetImage('assets/brand/wordmark_navy.png'),
              boundary.currentContext!,
            );
            await precacheImage(
              const AssetImage('assets/brand/wordmark_white.png'),
              boundary.currentContext!,
            );
          });
          await tester.pump();
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(out).create(recursive: true);
            await File('$out/$name.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(route);
        await tester.pump();
        expect(index, 1);
        await tester.tap(
          find.descendant(of: nav, matching: find.byTooltip('Tara')),
        );
        await tester.pump();
        expect(index, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
