import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/theme.dart';
import 'package:dijigoo_kurye/widgets.dart';
import 'package:dijigoo_kurye/screens/activation_screen.dart';
import 'package:dijigoo_kurye/screens/home_screen.dart';
import 'package:dijigoo_kurye/screens/list_screen.dart';
import 'package:dijigoo_kurye/screens/task_detail_screen.dart';
import 'package:dijigoo_kurye/screens/wizard_screen.dart';
import 'package:dijigoo_kurye/screens/menu_screen.dart';
import 'package:dijigoo_kurye/screens/profile_screen.dart';
import 'package:dijigoo_kurye/screens/sube_home_screen.dart';
import 'package:dijigoo_kurye/screens/sube_login_screen.dart';
import 'package:dijigoo_kurye/screens/sube_shell_screen.dart';
import 'package:dijigoo_kurye/screens/sube_shipments_screen.dart';
import 'package:dijigoo_kurye/screens/sube_shipment_detail_screen.dart';
import 'package:dijigoo_kurye/screens/sube_assign_flow.dart';
import 'package:dijigoo_kurye/screens/sube_return_flow.dart';
import 'package:dijigoo_kurye/screens/sube_courier_map_screen.dart';
import 'package:dijigoo_kurye/screens/sube_count_reconcile_screen.dart';
import 'package:dijigoo_kurye/screens/sube_courier_detail_screen.dart';
import 'package:dijigoo_kurye/screens/sube_demo.dart';
import 'package:dijigoo_kurye/screens/sube_couriers_screen.dart';
import 'package:dijigoo_kurye/screens/sube_stock_screen.dart';
import 'package:dijigoo_kurye/screens/sube_count_screen.dart';
import 'package:dijigoo_kurye/screens/sube_dispatch_screen.dart';
import 'package:dijigoo_kurye/screens/sube_eod_screen.dart';
import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/screens/sube_inbox_screen.dart';
import 'package:dijigoo_kurye/screens/sube_incoming_screen.dart';
import 'package:dijigoo_kurye/screens/sube_labels_screen.dart';
import 'package:dijigoo_kurye/screens/sube_manage_screens.dart';
import 'package:dijigoo_kurye/screens/sube_ops_screen.dart';
import 'package:dijigoo_kurye/screens/sube_performance_screen.dart';
import 'package:dijigoo_kurye/screens/sube_shifts_screen.dart';
import 'package:dijigoo_kurye/screens/sube_sms_screen.dart';
import 'package:dijigoo_kurye/screens/depo_screen.dart';
import 'package:dijigoo_kurye/screens/earnings_screen.dart';
import 'package:dijigoo_kurye/screens/envanter_screen.dart';
import 'package:dijigoo_kurye/screens/eod_screen.dart';
import 'package:dijigoo_kurye/screens/kyc_screen.dart';
import 'package:dijigoo_kurye/screens/notif_screen.dart';
import 'package:dijigoo_kurye/screens/onboard_screen.dart';
import 'package:dijigoo_kurye/screens/permissions_screen.dart';
import 'package:dijigoo_kurye/screens/return_screen.dart';
import 'package:dijigoo_kurye/screens/shift_screen.dart';
import 'package:dijigoo_kurye/screens/splash_screen.dart';
import 'package:dijigoo_kurye/screens/support_screen.dart';
import 'package:dijigoo_kurye/screens/sync_screen.dart';
import 'package:dijigoo_kurye/screens/tara_screen.dart';
import 'package:dijigoo_kurye/screens/training_screen.dart';
import 'package:dijigoo_kurye/screens/training_detail_screen.dart';
import 'package:dijigoo_kurye/screens/zimmet_screen.dart';
import 'package:dijigoo_kurye/screens/result_screen.dart';
import 'package:dijigoo_kurye/screens/shell_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List<dynamic>) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    final cache = Directory.systemTemp.createTempSync('jetlogi-map-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cache.path,
        );
  });
  tearDown(() => Dg.dark = true);

  double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
  }

  for (final dark in [true, false]) {
    test('field palette contrast ${dark ? 'dark' : 'light'}', () {
      Dg.dark = dark;
      for (final surface in [Dg.bg, Dg.surface1, Dg.surface2]) {
        for (final ink in [
          Dg.ink,
          Dg.ink2,
          Dg.ink3,
          Dg.brand,
          Dg.warn,
          Dg.ok,
          Dg.bad,
        ]) {
          expect(
            contrast(ink, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$ink on $surface',
          );
        }
        expect(contrast(Dg.rule, surface), greaterThanOrEqualTo(3));
      }
      for (final stop in Dg.emberGradient.colors) {
        expect(contrast(Dg.onAction, stop), greaterThanOrEqualTo(4.5));
      }
      // Marka CTA: yazı ortadaki maviye oturur (≥ 4.5); uçlar dekor (≥ 3).
      final cta = Dg.brandCta.colors;
      expect(contrast(Colors.white, cta[1]), greaterThanOrEqualTo(4.5));
      expect(contrast(Colors.white, cta.first), greaterThanOrEqualTo(3));
      expect(contrast(Colors.white, cta.last), greaterThanOrEqualTo(3));
    });
  }

  final pages = <String, Widget>{
    'login': const ActivationScreen(),
    'brand-splash': const BrandSplash(),
    'home': const HomeScreen(),
    'route': const RouteScreen(),
    'result-success': const SizedBox.shrink(),
    'result-return': const SizedBox.shrink(),
    'list': const ListScreen(),
    'task': const TaskDetailScreen(taskId: 't1'),
    'delivery': const WizardScreen(taskId: 't1'),
    'menu': const MenuScreen(),
    'profile': const ProfileScreen(),
    'branch-home': const SubeHomeScreen(),
    'branch-login': const SubeLoginScreen(),
    'branch-shell': const SubeShellScreen(),
    'branch-shipments': const SubeShipmentsScreen(),
    'branch-shipment-detail': SubeShipmentDetailScreen(
      row: kSubeDemoBoard.rows[1],
    ),
    'branch-assign': SubeAssignFlow(
      mode: AssignMode.assign,
      rows: [kSubeDemoBoard.rows.first],
    ),
    'branch-return': const SubeReturnFlow(),
    'branch-courier-map': const SubeCourierMapScreen(),
    'branch-reconcile': const SubeCountReconcileScreen(),
    'branch-courier-detail': SubeCourierDetailScreen(
      courier: kSubeDemoRoster.first,
    ),
    'branch-couriers': const SubeCouriersScreen(),
    'branch-stock': const SubeStockScreen(),
    'branch-count': const SubeCountScreen(),
    'branch-dispatch': const SubeDispatchScreen(),
    'branch-eod': const SubeEodScreen(),
    'branch-ops': const SubeOpsScreen(),
    'branch-labels': const SubeLabelsScreen(),
    'branch-performance': const SubePerformanceScreen(),
    'branch-sms': const SubeSmsScreen(),
    'branch-shifts': const SubeShiftsScreen(),
    'branch-inbox': const SubeInboxScreen(),
    'branch-incoming': const SubeIncomingScreen(
      transfer: BranchTransfer(
        id: 'demo-in1',
        transferNumber: 'TRF-DEMO-002',
        statusCode: 'DISPATCHED',
        partyName: 'Merkez Depo',
        itemCount: 12,
      ),
    ),
    'branch-training': const SubeTrainingScreen(),
    'branch-compliance': const SubeComplianceScreen(),
    'depot': const DepoScreen(),
    'earnings': const EarningsScreen(),
    'inventory': const EnvanterScreen(),
    'eod': const EodScreen(),
    'kyc': const KycScreen(),
    'notifications': const NotifScreen(),
    'onboard': const OnboardScreen(),
    'permissions': const PermissionsScreen(),
    'return': const ReturnScreen(taskId: 't1'),
    'shift': const ShiftScreen(),
    'splash': const SplashScreen(),
    'support': const SupportScreen(),
    'sync': const SyncScreen(),
    'scan': const TaraScreen(),
    'training': const TrainingScreen(),
    'training-detail': const TrainingDetailScreen(moduleId: 'demo'),
    'custody': const ZimmetScreen(mode: 'sube'),
  };
  for (final dark in [true, false]) {
    for (final config in [
      (375.0, 812.0, 1.0),
      (812.0, 375.0, 1.0),
      (768.0, 1024.0, 1.0),
      (320.0, 568.0, 2.0),
      (430.0, 932.0, 2.0),
    ]) {
      for (final page in pages.entries) {
        final name =
            '${page.key}-${dark ? 'dark' : 'light'}-${config.$1.toInt()}-${config.$3.toInt()}x';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = Size(config.$1, config.$2);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final session = SessionController()..skipToDemo();
          await session.loadTrainingModules();
          if (page.key.startsWith('branch-')) {
            await session.loginAsAgency(
              email: SessionController.agencyDemoEmail,
              password: SessionController.agencyDemoPassword,
            );
          }
          session.darkModeUi = dark;
          Dg.dark = dark;
          Widget screen = page.value;
          if (page.key == 'training-detail') {
            screen = TrainingDetailScreen(
              moduleId: session.trainingModules.first.id,
            );
          }
          if (page.key.startsWith('result-')) {
            screen = DeliveryResultScreen(
              success: page.key == 'result-success',
              task: session.orderedOpenTasks.first,
              who: 'Ahmet Yılmaz',
              online: true,
              next: session.orderedOpenTasks.last,
              onClose: () {},
              onNext: () {},
            );
          }
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [sessionProvider.overrideWith((ref) => session)],
              child: L10nScope(
                l10n: const L10n('tr'),
                child: MaterialApp(
                  theme: Dg.theme(),
                  locale: const Locale('tr'),
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  supportedLocales: const [Locale('tr')],
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(config.$3),
                      disableAnimations: true,
                    ),
                    child: RepaintBoundary(key: boundary, child: child!),
                  ),
                  home: screen,
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.runAsync(() async {
            for (final asset in [
              'assets/brand/wordmark_white.png',
              'assets/brand/wordmark_navy.png',
            ]) {
              await precacheImage(AssetImage(asset), boundary.currentContext!);
            }
          });
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
          final out = Platform.environment['JETLOGI_SCREENSHOTS'];
          if (out != null) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(out).create(recursive: true);
              await File('$out/$name.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 10));
        });
      }
    }
  }
  for (final dark in [true, false]) {
    testWidgets(
      'login remains usable with keyboard ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final session = SessionController()..darkModeUi = dark;
        Dg.dark = dark;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionProvider.overrideWith((ref) => session)],
            child: L10nScope(
              l10n: const L10n('tr'),
              child: MaterialApp(
                theme: Dg.theme(),
                home: const ActivationScreen(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('panel-identifier')),
          'kurye@example.test',
        );
        await tester.ensureVisible(find.byKey(const Key('panel-login')));
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.getRect(find.byKey(const Key('panel-login'))).bottom,
          lessThanOrEqualTo(308),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final dark in [true, false]) {
    testWidgets(
      'support form keeps fields separate with keyboard ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        Dg.dark = dark;
        final session = SessionController()..skipToDemo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionProvider.overrideWith((ref) => session)],
            child: L10nScope(
              l10n: const L10n('tr'),
              child: MaterialApp(
                theme: Dg.theme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: const SupportScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final subject = find.byKey(const Key('support-subject'));
        final body = find.byKey(const Key('support-body'));
        await tester.scrollUntilVisible(
          subject,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(subject, 'Adres bilgisi');
        await tester.ensureVisible(body);
        await tester.enterText(body, 'Bina numarası görünmüyor.');
        await tester.pumpAndSettle();
        expect(
          tester.getRect(body).top - tester.getRect(subject).bottom,
          greaterThanOrEqualTo(16),
        );
        expect(tester.getRect(body).bottom, lessThanOrEqualTo(308));
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        final send = find.byKey(const Key('support-send'));
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(
          session.tickets.any((ticket) => ticket.subject == 'Adres bilgisi'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('text shortcut accepts taps across its full field target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GestureDetector(
              onTap: () => taps++,
              child: const DgTapTarget(child: Text('Ara')),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(DgTapTarget));
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    expect(taps, 1);
  });
  testWidgets('primary action preserves tap and minimum field target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DgButton(label: 'Teslim et', onPressed: () => taps++),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(DgButton)).height,
      greaterThanOrEqualTo(56),
    );
    await tester.tap(find.text('Teslim et'));
    expect(taps, 1);
  });
}
