import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/app.dart';
import 'package:dijigoo_kurye/scan_router.dart';
import 'package:dijigoo_kurye/screens/sube_count_screen.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/training_port.dart';
import 'package:dijigoo_kurye/ui/ui.dart';
import 'package:dijigoo_kurye/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

  /// Hap sekmeye dokunur. Etiket bölmeye sığmazsa (test yazı tipi geniş)
  /// sekmeler yatay kayar; önce görünür kılınır.
  Future<void> tapPill(WidgetTester tester, String label) async {
    final target = find.text(label);
    final pills = find.descendant(
      of: find.byType(DgPillTabs),
      matching: find.byType(Scrollable),
    );
    if (pills.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(target, 80, scrollable: pills.first);
    }
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Listede kaydırıp ortalar (alttaki yüzen menünün ya da bildirim
  /// çubuğunun arkasında kalmasın) ve dokunur.
  Future<void> tapFound(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> openItem(WidgetTester tester, String label) =>
      tapFound(tester, find.text(label));

  testWidgets('ana sayfa iş ortağı özetini ve beş sekmeyi gösterir', (tester) async {
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
    await openItem(tester, 'Kurye dönüş');
    await tester.tap(find.text('Ali Can'));
    await tester.pumpAndSettle();
    expect(find.text('1 gönderi dönüş bekliyor'), findsNothing);
    // Testte kamera yok; elle kod girişi.
    await tester.enterText(find.byType(TextField), 'JL100238553');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('İş ortağına teslim alındı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('return-review')));
    await tester.pumpAndSettle();
    expect(find.text('Teslim alındı (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('return-complete')));
    await tester.pumpAndSettle();
    expect(find.text('1 gönderi iş ortağına alındı'), findsOneWidget);
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

  testWidgets('kurye listesi detaya açılır: genel, kart, evraklar, cihaz', (
    tester,
  ) async {
    await openBranch(tester);
    await tester.tap(find.text('Kuryeler'));
    await tester.pumpAndSettle();
    expect(find.text('Aktif (4)'), findsOneWidget);
    expect(find.text('Pasif (1)'), findsOneWidget);
    // Mert'in iki evrakı eksik: listede uyarı.
    expect(find.text('2 evrak eksik'), findsOneWidget);
    await tester.tap(find.text('Ali Can'));
    await tester.pumpAndSettle();
    expect(find.text('Kurye Detayı'), findsOneWidget);
    expect(find.text('Birincil iş ortağı'), findsOneWidget);
    await tapPill(tester, 'Evraklar');
    expect(find.text('4 / 4 belge onaylı'), findsOneWidget);
    expect(find.text('Ehliyet'), findsOneWidget);
    await tapPill(tester, 'Kart');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('KRY-001'), findsWidgets);
    await tapPill(tester, 'Cihaz');
    // Demo girişte önerilen uç örnek veriyle dolar (docs/15).
    expect(find.text('Samsung Galaxy A54'), findsOneWidget);
    Navigator.of(tester.element(find.text('Kurye Detayı'))).pop();
    await tester.pumpAndSettle();

    await tapPill(tester, 'Pasif (1)');
    expect(find.text('Selin Kara'), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-courier')));
    await tester.pumpAndSettle();
    // Demo girişte davet formu önerilen uçla açılır (docs/15).
    expect(find.byKey(const Key('invite-send')), findsOneWidget);
  });

  testWidgets('performans kurye süzgeci ve gün sonu kilidi', (tester) async {
    await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Performans'));
    await tester.pumpAndSettle();
    expect(find.text('%87,9'), findsOneWidget);
    // Sıralamada kuryeye dokununca halka o kuryenin oranını gösterir.
    await tester.scrollUntilVisible(
      find.text('Mert Demir'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(find.text('Mert Demir'));
    await tester.pumpAndSettle();
    expect(find.text('%85,4'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Gün sonu raporu'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(find.text('Gün sonu raporu'));
    await tester.pumpAndSettle();
    expect(find.text('İş ortağı gün sonu'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('eod-close')),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    // Demo girişte gün sonu kapatma önerilen uçla çalışır (docs/15).
    final close = tester.widget<DgGradientButton>(
      find.byKey(const Key('eod-close')),
    );
    expect(close.onPressed, isNotNull);
  });

  testWidgets('stok merkezi kuyrukları ve sayım mutabakatı', (tester) async {
    final session = await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stok & Zimmet'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dönüş (1)'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tapPill(tester, 'Dönüş (1)');
    expect(find.text('JL100238553'), findsOneWidget);
    expect(find.text('Kurye dönüşü başlat'), findsOneWidget);
    Navigator.of(tester.element(find.text('JL100238553'))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Sayım Mutabakatı'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(find.text('Sayım Mutabakatı'));
    await tester.pumpAndSettle();
    expect(find.text('Bekleyen (1)'), findsOneWidget);
    await tester.tap(find.text('SAY-DEMO-0042'));
    await tester.pumpAndSettle();
    expect(find.text('POS cihazı'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reconcile-send')));
    await tester.pumpAndSettle();
    expect(
      session.branch.counts?.counts
          .firstWhere((c) => c.id == 'demo-count-r')
          .statusCode,
      'POSTED',
    );
    final pills = find
        .descendant(
          of: find.byType(DgPillTabs),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Tamamlanan (3)'),
      80,
      scrollable: pills,
    );
    expect(find.text('Tamamlanan (3)'), findsOneWidget);
  });

  group('eğitim sade görünüm (bayrak kapalı)', () {
    setUp(() => trainingPlayerEnabled = false);
    tearDown(() => trainingPlayerEnabled = kTrainingPlayerDefault);

    testWidgets('eğitim merkezi (sade): içerik açılır, eğitim tamamlanır', (
      tester,
    ) async {
      final session = await openBranch(tester);
      await tester.tap(find.text('İşlemler'));
      await tester.pumpAndSettle();
      await openItem(tester, 'Eğitim Merkezi');
      expect(find.text('1 / 4 tamamlandı'), findsOneWidget);
      expect(find.text('2 zorunlu eğitim bekliyor'), findsOneWidget);
      await tester.tap(find.text('İş ortağı açılış kontrol listesi'));
      await tester.pumpAndSettle();
      final done = find.byKey(const Key('training-complete'));
      // İçerik açılmadan tamamlanamaz.
      expect(tester.widget<DgButton>(done).onPressed, isNull);
      await tester.tap(find.text('İçeriği aç'));
      await tester.pumpAndSettle();
      expect(find.textContaining('demo eğitimidir'), findsOneWidget);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(
        session.branch.trainingTabs['BRANCH']!.learner.first.completed,
        isTrue,
      );
      expect(find.text('2 / 4 tamamlandı'), findsOneWidget);
      // SSS ucu.
      await tester.scrollUntilVisible(
        find.text('Sıkça sorulan sorular'),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      expect(find.text('Sıkça sorulan sorular'), findsOneWidget);
    });
  });

  group('eğitim oynatıcı (bayrak açık)', () {
    setUp(() => trainingPlayerEnabled = true);
    tearDown(() => trainingPlayerEnabled = kTrainingPlayerDefault);

    testWidgets('eğitim merkezi: içerik okunur, eğitim tamamlanır', (
      tester,
    ) async {
      final session = await openBranch(tester);
      await tester.tap(find.text('İşlemler'));
      await tester.pumpAndSettle();
      await openItem(tester, 'Eğitim Merkezi');
      expect(find.text('1 / 5 tamamlandı'), findsOneWidget);
      expect(find.text('2 zorunlu eğitim bekliyor'), findsOneWidget);
      await tester.tap(find.text('İş ortağı açılış kontrol listesi'));
      await tester.pumpAndSettle();
      // Oynatıcı: metin içerik hemen okunur, tamamlanabilir.
      expect(find.textContaining('demo eğitimidir'), findsOneWidget);
      await tester.tap(find.byKey(const Key('training-complete')));
      await tester.pumpAndSettle();
      expect(
        session.branch.trainingTabs['BRANCH']!.learner.first.completed,
        isTrue,
      );
      Navigator.of(tester.element(find.textContaining('demo eğitimidir')))
          .pop();
      await tester.pumpAndSettle();
      expect(find.text('2 / 5 tamamlandı'), findsOneWidget);
      // SSS ucu.
      await tester.scrollUntilVisible(
        find.text('Sıkça sorulan sorular'),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      expect(find.text('Sıkça sorulan sorular'), findsOneWidget);
    });

    testWidgets(
      'dersli eğitim: dersler sırayla, sınav geçilince eğitim biter',
      (tester) async {
        final session = await openBranch(tester);
        await tester.tap(find.text('İşlemler'));
        await tester.pumpAndSettle();
        await openItem(tester, 'Eğitim Merkezi');
        await openItem(tester, 'Zimmet ve teslim akışı');
        expect(find.text('0 / 3 ders tamamlandı'), findsOneWidget);
        // Sıralı: 2. ders 1. bitmeden kilitli.
        expect(find.text('Metin · 2 dk · Kilitli'), findsOneWidget);

        await tester.tap(find.text('1. Zimmetin iki tarafı'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lesson-complete')));
        await tester.pumpAndSettle();
        expect(find.text('1 / 3 ders tamamlandı'), findsOneWidget);

        await tester.tap(find.text('2. Teslimde fotoğraf kuralları'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lesson-complete')));
        await tester.pumpAndSettle();

        // "Ders tamamlandı" bildirimi kapanır (alttaki düğmeyi örtmesin).
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3. Kısa sınav'));
        await tester.pumpAndSettle();
        // Yanlış cevap: geçilmez, tekrar denenir.
        await tapFound(tester, find.text('Gün sonunda'));
        await tapFound(tester, find.text('3 fotoğraf'));
        await tapFound(tester, find.byKey(const Key('quiz-submit')));
        expect(find.text('Geçemediniz'), findsOneWidget);
        await tapFound(tester, find.text('Tekrar dene'));
        await tapFound(
          tester,
          find.text('Kurye gönderiyi okutup kabul edince'),
        );
        await tapFound(tester, find.text('3 fotoğraf'));
        await tapFound(tester, find.text('Konum ve ziyaret anketi'));
        await tapFound(tester, find.byKey(const Key('quiz-submit')));
        expect(find.text('Geçtiniz'), findsOneWidget);
        expect(
          session.branch.trainingTabs['BRANCH']!.learner
              .firstWhere((t) => t.id == 'demo-lt5')
              .completed,
          isTrue,
        );
      },
    );

    testWidgets('kurye eğitimi önizlenir ve düzenlenir', (tester) async {
      final session = await openBranch(tester);
      await tester.tap(find.text('İşlemler'));
      await tester.pumpAndSettle();
      await openItem(tester, 'Eğitim Merkezi');
      await tapPill(tester, 'Kurye');
      await tester.tap(find.text('Önizle'));
      await tester.pumpAndSettle();
      expect(
        find.text('Önizleme: ilerleme kaydedilmez, sınav gönderilmez.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('training-complete')), findsNothing);
      Navigator.of(
        tester.element(
          find.text('Önizleme: ilerleme kaydedilmez, sınav gönderilmez.'),
        ),
      ).pop();
      await tester.pumpAndSettle();
      await openItem(tester, 'Kurye eğitimlerini yönet');
      await tester.tap(find.byKey(const Key('training-edit-demo-tr1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Kimlik kontrolü v2',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(session.branch.trainings!.first.title, 'Kimlik kontrolü v2');
    });
  });

  testWidgets('gönderilerde başlık kayar, durum sekmeleri yapışık kalır', (
    tester,
  ) async {
    await openBranch(tester);
    await tester.tap(find.text('Gönderiler').last);
    await tester.pumpAndSettle();
    final title = find.descendant(
      of: find.byType(DgPageTitle),
      matching: find.text('Gönderiler'),
    );
    expect(title.hitTestable(), findsOneWidget);
    final pills = find.byType(DgPillTabs);
    final pillsTop = tester.getTopLeft(pills).dy;
    await tester.drag(
      find.byType(CustomScrollView).hitTestable().first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    // Başlık yukarı kaydı; sekmeler üst barın hemen altına yapıştı.
    expect(title.hitTestable(), findsNothing);
    final stuck = tester.getTopLeft(pills).dy;
    expect(stuck, lessThan(pillsTop));
    expect(stuck, greaterThan(0));
    await tester.drag(
      find.byType(CustomScrollView).hitTestable().first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(pills).dy, stuck);
  });

  testWidgets('stok merkezinde kurye uyuşmazlıkları görünür', (tester) async {
    await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stok & Zimmet'));
    await tester.pumpAndSettle();
    // Dördüncü hap, dar ekranda yatay kaydırılarak görünür.
    await tester.scrollUntilVisible(
      find.byType(DgPillTabs),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tapPill(tester, 'Uyuşmazlık (2)');
    expect(find.text('Eksik · JD2026102900311'), findsOneWidget);
    expect(find.textContaining('Mert Kaya'), findsWidgets);
    expect(find.text('Yeni'), findsOneWidget);
  });

  testWidgets('fatura, iş ortaklığı evrakları, hızlı gönder ve profil', (
    tester,
  ) async {
    final session = await openBranch(tester);
    await tester.tap(find.text('İşlemler'));
    await tester.pumpAndSettle();
    await openItem(tester, 'Fatura ve hakediş');
    await tester.tap(find.text('DGF-2026-0010'));
    await tester.pumpAndSettle();
    expect(find.text('Fatura Detayı'), findsOneWidget);
    expect(find.text('Kart teslimatı × 410'), findsOneWidget);
    Navigator.of(tester.element(find.text('Fatura Detayı'))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('DGF-2026-0010'))).pop();
    await tester.pumpAndSettle();

    await openItem(tester, 'İş Ortaklığı Evrakları');
    expect(find.text('İş ortaklığı sözleşmesi'), findsOneWidget);
    expect(find.text('İmzalı'), findsWidgets);
    Navigator.of(tester.element(find.text('İş ortaklığı sözleşmesi'))).pop();
    await tester.pumpAndSettle();

    // Kurye dönüşü okutması kuyruğa yazılır ve gönderilir.
    await session.branch.scan(ScanContext.courierReturn, 'JL100238553');
    await openItem(tester, 'Hızlı Gönder');
    expect(find.text('Bekleyen işlem yok'), findsOneWidget);
    expect(find.text('JL100238553'), findsOneWidget);
    expect(find.text('Gönderildi'), findsOneWidget);
    Navigator.of(tester.element(find.text('Bekleyen işlem yok'))).pop();
    await tester.pumpAndSettle();

    // Kaydırınca alt menü küçülüp etiketi gizler; sekmeye ipucuyla dokun.
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profilim'), findsOneWidget);
    await openItem(tester, 'Destek ekibini ara');
    expect(find.text('Merkez bağlantısı bekleniyor'), findsOneWidget);
  });
}
