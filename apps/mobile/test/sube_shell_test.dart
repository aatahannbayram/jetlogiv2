import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/app.dart';
import 'package:dijigoo_kurye/scan_router.dart';
import 'package:dijigoo_kurye/screens/sube_count_screen.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/ui/ui.dart';
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
    expect(find.text('Toplam gönderi'), findsOneWidget);
    expect(find.text('Kurye ataması bekleyen'), findsOneWidget);
    expect(find.text('Canlı operasyon takip'), findsOneWidget);
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
    // Satır detayı açar; kutucuk seçer, toplu işlem çubuğu gelir.
    await tester.tap(find.byKey(const Key('pick-demo-s1')));
    await tester.pumpAndSettle();
    expect(session.branch.picked, {'demo-s1'});
    await tester.tap(find.text('Toplu İşlemler (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bulk-assign')));
    await tester.pumpAndSettle();
    expect(find.text('Kurye Atama'), findsOneWidget);
    expect(find.text('Bölge dışı'), findsOneWidget);
    expect(find.text('Bölgesinde'), findsOneWidget);
    await tester.tap(find.text('Ali Can'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign-confirm')));
    await tester.pumpAndSettle();
    final row = session.branch.rows.firstWhere(
      (r) => r.shipmentId == 'demo-s1',
    );
    // Çift taraflı zimmet: kurye kabul edene kadar dağıtımda sayılmaz.
    expect(row.stage, BranchStage.inQueue);
    expect(row.courierName, 'Ali Can');
    expect(session.branch.picked, isEmpty);
    expect(find.text('Kurye Atama'), findsNothing);
    expect(find.text('Toplu İşlemler (1)'), findsNothing);
  });

  testWidgets('gönderi detayı açılır, kurye dönüşü okutulup tamamlanır', (
    tester,
  ) async {
    final session = await openBranch(tester);
    await tester.tap(find.text('Gönderiler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JL100238547'));
    await tester.pumpAndSettle();
    expect(find.text('Gönderi Detayı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Demo Müşteri A.Ş.'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.scrollUntilVisible(
      find.text('Kurye teslim aldı'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    Navigator.of(tester.element(find.text('Gönderi Detayı'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kurye dönüş'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(find.text('Kurye dönüş'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Can'));
    await tester.pumpAndSettle();
    expect(find.text('1 gönderi dönüş bekliyor'), findsNothing);
    // Testte kamera yok; elle kod girişi.
    await tester.enterText(find.byType(TextField), 'JL100238553');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Şubeye teslim alındı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('return-review')));
    await tester.pumpAndSettle();
    expect(find.text('Teslim alındı (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('return-complete')));
    await tester.pumpAndSettle();
    expect(find.text('1 gönderi şubeye alındı'), findsOneWidget);
    expect(session.branch.pendingScans, 0);
  });

  testWidgets('kurye haritası durum sekmeleriyle açılır', (tester) async {
    await openBranch(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('live-ops-details')),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(find.byKey(const Key('live-ops-details')));
    await tester.pumpAndSettle();
    expect(find.text('Kurye Haritası'), findsOneWidget);
    expect(find.text('Dağıtımda (2)'), findsOneWidget);
    // Ece vardiyada molada (konum yaşı değil); Barış konumsuz.
    final pills = find
        .descendant(
          of: find.byType(DgPillTabs),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Çevrimdışı (1)'),
      120,
      scrollable: pills,
    );
    expect(find.text('Molada (1)'), findsOneWidget);
    // Konumsuz kurye haritanın altında listelenir.
    expect(find.text('Barış Arslan'), findsOneWidget);
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

    await tester.scrollUntilVisible(
      find.text('Bildirimler'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bildirimler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('zimmeti henüz kabul etmedi'), findsOneWidget);
    Navigator.of(
      tester.element(find.textContaining('zimmeti henüz kabul etmedi')),
    ).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Vardiya & İzin'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
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
    await tester.scrollUntilVisible(
      find.text('SMS'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
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
    // Zimmet Bekleyen sekmesi: dağıtımdaki gönderi listede yok.
    expect(find.text('JL100238547'), findsNothing);
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
