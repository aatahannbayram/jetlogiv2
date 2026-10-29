import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/app.dart';
import 'package:dijigoo_kurye/scan_router.dart';
import 'package:dijigoo_kurye/screens/sube_count_screen.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<SessionController> openBranch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SessionController();
    final ok = await session.loginAsAgency(
      email: SessionController.agencyDemoEmail,
      password: SessionController.agencyDemoPassword,
    );
    expect(ok, isTrue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('ana sayfa şube özetini ve beş sekmeyi gösterir', (tester) async {
    await openBranch(tester);
    expect(find.text('Güney Acente'), findsOneWidget);
    expect(find.text('Bugün dağıtılacak'), findsOneWidget);
    expect(find.text('Kurye ataması bekleyen'), findsOneWidget);
    for (final tab in [
      'Ana Sayfa',
      'Gönderiler',
      'Kuryeler',
      'İşlemler',
      'Profil',
    ]) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
    expect(find.text('Barkod Okut'), findsOneWidget);
  });

  testWidgets('gönderi seçilip kuryeye zimmetlenir, kabul bekler', (
    tester,
  ) async {
    final session = await openBranch(tester);
    await tester.tap(find.text('Gönderiler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JL100238546'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Kuryeye zimmetle'));
    await tester.pumpAndSettle();
    expect(find.text('Kurye seç'), findsOneWidget);
    expect(find.text('Bölge dışı'), findsOneWidget);
    // Liste satırlarında da kurye adı var; seçim sayfasındaki en üstteki.
    await tester.tap(find.text('Ali Can').last);
    await tester.pumpAndSettle();
    final row = session.branch.rows.firstWhere(
      (r) => r.shipmentId == 'demo-s1',
    );
    // Çift taraflı zimmet: kurye kabul edene kadar dağıtımda sayılmaz.
    expect(row.stage, BranchStage.inQueue);
    expect(row.courierName, 'Ali Can');
    expect(session.branch.picked, isEmpty);
    expect(find.textContaining('Kuryeye zimmetle'), findsNothing);
  });

  testWidgets('sayım başlatılır, mükerrer barkod ikinci kez sayılmaz', (
    tester,
  ) async {
    final session = await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();
    expect(find.text('Merkeze transfer'), findsOneWidget);
    expect(find.text('Etiket'), findsOneWidget);
    expect(find.text('Performans'), findsOneWidget);
    await tester.ensureVisible(find.text('Sayım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sayım'));
    await tester.pumpAndSettle();
    expect(find.text('Depo seç'), findsOneWidget);
    await tester.tap(find.text('Sayımı başlat'));
    await tester.pumpAndSettle();
    expect(find.text('SAY-DEMO-001'), findsOneWidget);

    final first = await session.branch.scan(ScanContext.count, 'SERI-1');
    final again = await session.branch.scan(ScanContext.count, 'SERI-1');
    expect(first.ok, isTrue);
    expect(again.title, 'Daha önce sayıldı');
    await tester.pumpAndSettle();
    expect(find.text('Son okutmalar'), findsOneWidget);
    // Liste tembel kurulur; düğme ekranın altında kalabilir.
    await tester.scrollUntilVisible(
      find.text('Sayımı tamamla'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SubeCountScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Sayımı tamamla'), findsOneWidget);
  });

  testWidgets('etiket ve performans ekranları açılır', (tester) async {
    await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Performans'));
    await tester.pumpAndSettle();
    expect(find.text('Teslim oranı'), findsOneWidget);
    expect(find.text('%87,9'), findsOneWidget);
    Navigator.of(tester.element(find.text('Teslim oranı'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Etiket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etiket'));
    await tester.pumpAndSettle();
    expect(find.text('Etiket üret'), findsOneWidget);
    await tester.ensureVisible(find.text('Etiket üret'));
    await tester.tap(find.text('Etiket üret'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni etiketler'), findsOneWidget);
  });

  testWidgets('bildirim, vardiya ve SMS ekranları açılır', (tester) async {
    await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bildirimler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bildirimler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('zimmeti henüz kabul etmedi'), findsOneWidget);
    Navigator.of(
      tester.element(find.textContaining('zimmeti henüz kabul etmedi')),
    ).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Vardiya & İzin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vardiya & İzin'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Can'), findsOneWidget);
    await tester.tap(find.text('İzin istekleri'));
    await tester.pumpAndSettle();
    expect(find.text('Ece Yılmaz'), findsOneWidget);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(find.text('İzin onaylandı'), findsWidgets);
    Navigator.of(tester.element(find.text('Ece Yılmaz'))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('SMS ekranı şablonu ve alıcıları gösterir', (tester) async {
    await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SMS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SMS'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün teslimat'), findsOneWidget);
    expect(find.text('Önizle'), findsOneWidget);
  });

  testWidgets('dashboard kartı Gönderiler\'i filtreli açar, çıkış Profil\'de', (
    tester,
  ) async {
    await openBranch(tester);
    await tester.ensureVisible(find.text('Kurye ataması bekleyen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurye ataması bekleyen'));
    await tester.pumpAndSettle();
    expect(find.text('JL100238546'), findsOneWidget);
    final chip = tester.widget<FilterChip>(
      find.ancestor(
        of: find.text('Zimmet Bekleyen'),
        matching: find.byType(FilterChip),
      ),
    );
    expect(chip.selected, isTrue);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Çıkış yap'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    expect(find.text('Çıkış yap'), findsOneWidget);
  });
}
