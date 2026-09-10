import 'package:dijigoo_kurye/alerts.dart';
import 'package:dijigoo_kurye/api/courier_tasks.dart';
import 'package:dijigoo_kurye/api/panel_models.dart';
import 'package:dijigoo_kurye/app.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/screens/return_screen.dart';
import 'package:dijigoo_kurye/screens/sync_screen.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Future<void> bindPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openDemo(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DijigooApp()));
    await tester.pump();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Demoyu aç'));
    await tester.pumpAndSettle();
  }

  Future<void> tapHomeKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    final list = find.byType(ListView);
    for (var i = 0; i < 8; i++) {
      if (finder.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(finder.hitTestable());
        await tester.pumpAndSettle();
        return;
      }
      if (list.evaluate().isEmpty) break;
      await tester.drag(list.first, const Offset(0, -72));
      await tester.pumpAndSettle();
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Onboard girişte görünür', (tester) async {
    await bindPhone(tester);
    await tester.pumpWidget(const ProviderScope(child: DijigooApp()));
    await tester.pump();
    expect(find.text('Atla'), findsOneWidget);
    expect(find.text('Üstteki durak senin.'), findsOneWidget);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.text('Bugünün durakları Güney’de.'), findsOneWidget);
    expect(find.text('Vardiyaya başla'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('aktivasyon panel şifre formunu gösterir', (tester) async {
    await bindPhone(tester);
    await tester.pumpWidget(const ProviderScope(child: DijigooApp()));
    await tester.pump();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Aktivasyonu göster'));
    await tester.pumpAndSettle();
    expect(find.text('Giriş Yap'), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-method-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-identifier')), findsOneWidget);
    expect(find.byKey(const Key('panel-password')), findsOneWidget);
    expect(find.byKey(const Key('panel-login')), findsOneWidget);
    expect(find.byKey(const Key('sms-login')), findsNothing);
    await tester.tap(find.byKey(const Key('login-method-sms')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sms-login')), findsOneWidget);
  });

  testWidgets('görüşme demosu teslimatı bitirir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.text('Güney / Denizli'), findsOneWidget);

    await tapHomeKey(tester, const Key('next-stop-arrived'));
    await tapHomeKey(tester, const Key('next-stop-cta'));
    expect(find.text('Teslim alan'), findsWidgets);

    await tester.tap(find.text('Alıcının kendisi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shutter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shutter')));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullan'));
    await tester.pumpAndSettle();
    expect(find.text('Kodu gönder'), findsOneWidget);

    await tester.tap(find.text('Kodu gönder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '482913');
    await tester.pump();
    await tester.tap(find.text('Doğrula ve teslim et'));
    await tester.pumpAndSettle();
    expect(find.text('Teslim edildi'), findsOneWidget);
  });

  testWidgets('sıradaki durak kartı gönderi ve kuyruğu açar', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);
    expect(find.text('Gönderi ve kuyruk'), findsNothing);
    expect(find.textContaining('Cumhuriyet Cd.'), findsWidgets);
    expect(find.text('Yol tarifi'), findsWidgets);
    expect(find.text('Teslime başla'), findsNothing);
    await tester.tap(find.text('2 kalem').first);
    await tester.pumpAndSettle();
    expect(find.text('Kalemler'), findsOneWidget);
    Navigator.of(tester.element(find.text('Kalemler'))).pop();
    await tester.pumpAndSettle();
    await tapHomeKey(tester, const Key('next-stop-arrived'));
    expect(find.text('Teslime başla'), findsOneWidget);
  });

  testWidgets('rota zaman çizelgesi durakları gösterir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Rotayı gör'));
    await tester.pumpAndSettle();
    expect(find.textContaining('durak kaldı'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(
      find.text('Elif Koç', skipOffstage: false),
      findsWidgets,
    );
  });

  testWidgets('görev detayı rota özeti ve kuryeleri gösterir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);
    await tester.tap(find.text('Rota'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahmet Yılmaz').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('dk'), findsWidgets);
    expect(find.text('Kuryeler'), findsWidgets);
    expect(find.textContaining('#1'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
  });

  testWidgets('dağıtım listesi sekmeleri durak sayısını gösterir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Rota'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.textContaining('Açık '), findsWidgets);
  });

  testWidgets('panel görevi listede ve detayda gönderi no gösterir', (tester) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    session.tasks
      ..clear()
      ..add(
        deliveryTaskFromPanel(
          PanelCourierTaskDto.fromJson({
            'id': 's-9',
            'shipmentNumber': 'JLG-9',
            'statusCode': 'COURIER_ASSIGNED',
            'recipientName': 'Bora Kaya',
            'destination': {
              'address': 'İstiklal 8',
              'latitude': '38.1481',
              'longitude': '29.0558',
            },
            'packageCount': 2,
          }),
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rota'));
    await tester.pumpAndSettle();
    expect(find.text('Bora Kaya'), findsWidgets);
    expect(find.textContaining('#0'), findsNothing);
    await tester.tap(find.text('Bora Kaya').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('JLG-9'), findsWidgets);
    expect(find.textContaining('#0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zimmet taraması kodu listeye yazar', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);
    await tester.tap(find.text('Tara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurye Zimmet'));
    await tester.pumpAndSettle();
    expect(find.text('Barkodu çerçeveye getir'), findsOneWidget);
    expect(find.text('Henüz taranan gönderi yok'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'DGO-9107');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('DGO-9107'), findsOneWidget);
    expect(find.text('1 okundu'), findsOneWidget);
  });

  testWidgets('destek talebi menüden açılır ve kuyruğa yazar', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Destek talebi'));
    await tester.pumpAndSettle();
    expect(find.text('Talep aç'), findsOneWidget);
    expect(find.text('Henüz destek talebin yok.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Kapı yok');
    await tester.enterText(find.byType(TextField).at(1), 'Numara görünmüyor');
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    expect(find.text('Kapı yok'), findsOneWidget);
    expect(find.text('Henüz destek talebin yok.'), findsNothing);
  });

  testWidgets('aktivasyon açık panel oturumunda izinlere geçer', (tester) async {
    await bindPhone(tester);
    final session = SessionController();
    session.finishOnboard();
    session.finishSplash();
    session.panelLoggedIn = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('İzinlere geç'), findsOneWidget);
    expect(find.byKey(const Key('panel-identifier')), findsNothing);
    await tester.tap(find.byKey(const Key('panel-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Cihaz izinleri'), findsOneWidget);
    expect(session.phase, AppPhase.permissions);
  });

  testWidgets('menü panel oturumu kapandı yazar', (tester) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    session.lastPanelError = SessionController.panelSessionExpired;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    expect(find.text('Panel oturumu kapandı'), findsOneWidget);
    expect(find.text('Panel oturumu açık'), findsNothing);
  });

  testWidgets('çıkış panel oturumunu da kapatacağını söyler', (tester) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    session.panelLoggedIn = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruken Turhan'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Çıkış yap'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();
    expect(
      find.text('Panel oturumu da kapanacak. Tekrar giriş yapman gerekecek.'),
      findsOneWidget,
    );
  });

  testWidgets('menü panel oturumu açık yazar', (tester) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    session.panelLoggedIn = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    expect(find.text('Panel oturumu açık'), findsOneWidget);
  });

  testWidgets('menü ekranı yeni bölümlere gider', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Performansım'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Performansım'), findsOneWidget);

    await tester.tap(find.text('Performansım'));
    await tester.pumpAndSettle();
    // Demo courier is fixed-monthly (canSeePricing == false) — sees the
    // monthly-equivalent card, not a per-delivery figure.
    expect(find.text('AYLIK SABİT'), findsOneWidget);
  });

  testWidgets('menü kimlik doğrulamaya gider', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kimlik doğrulama'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Kimlik doğrulama'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belgeyi seç, fotoğrafını çek, çipi oku.'),
      findsOneWidget,
    );
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Yeni kimlik ön yüz'), findsOneWidget);
  });

  testWidgets('profil koduna 5 dokunuş mühendis katmanını açar', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    // Profil artık ayrı bir sekme değil — Menü'nün üst kartından açılıyor.
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ruken Turhan'));
    await tester.pumpAndSettle();
    expect(find.text('Ruken Turhan'), findsWidgets);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('DGC-2026-9CF4875F'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Mühendis'), findsOneWidget);
    expect(find.textContaining('/v1/config'), findsOneWidget);
  });

  testWidgets('bildirimler okundu işaretler ve uyarı filtresi çalışır', (
    tester,
  ) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bildirim'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notif-demo-stop')), findsOneWidget);
    expect(find.byKey(const Key('notif-demo-sync')), findsOneWidget);
    expect(session.unreadNotifCount, greaterThan(0));

    await tester.tap(find.text('Uyarı'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notif-demo-sync')), findsOneWidget);
    expect(find.byKey(const Key('notif-demo-bonus')), findsNothing);

    await tester.tap(find.byKey(const Key('notif-mark-all')));
    await tester.pumpAndSettle();
    expect(session.unreadNotifCount, 0);
    expect(find.text('Hepsi okundu'), findsOneWidget);
  });

  testWidgets('bildirim durak detayına gider, uzun basınca okunmadı olur', (
    tester,
  ) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bildirim'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notif-demo-stop')));
    await tester.pumpAndSettle();
    expect(find.text('Fatma Şahin'), findsWidgets);
    expect(session.isNotifRead('demo-stop'), isTrue);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('notif-demo-stop')));
    await tester.pumpAndSettle();
    expect(session.isNotifRead('demo-stop'), isFalse);
  });

  testWidgets('sistem bildirimi durak kaydını açar', (tester) async {
    await bindPhone(tester);
    addTearDown(() => FieldAlerts.tapId.value = null);
    final session = SessionController();
    session.skipToDemo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    FieldAlerts.tapId.value = 'demo-stop';
    await tester.pumpAndSettle();
    expect(find.text('Fatma Şahin'), findsWidgets);
    expect(session.isNotifRead('demo-stop'), isTrue);
  });

  testWidgets('senkron kuyruğu kurye adını ve hattı gösterir', (tester) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const L10nScope(
          l10n: L10n('tr'),
          child: MaterialApp(home: SyncScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Fatma Şahin'), findsWidgets);
    expect(find.text('Alıcı adreste yok'), findsOneWidget);
    expect(find.textContaining('DGO-8844'), findsOneWidget);
    expect(find.text('TASK_TRANSITION'), findsNothing);
    expect(find.text('t4'), findsNothing);
    expect(find.text('Merkez hattı'), findsOneWidget);
  });

  testWidgets('İngilizce ve açık tema ana ekranda açılır', (tester) async {
    await bindPhone(tester);
    final session = SessionController();
    session.skipToDemo();
    session.localeCode = 'en';
    session.darkModeUi = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Directions'), findsWidgets);
    expect(find.text('Next stop'), findsOneWidget);
    expect(Dg.dark, isFalse);
  });

  testWidgets('şube demo girişi acente ana sayfasını açar', (tester) async {
    await bindPhone(tester);
    await tester.pumpWidget(const ProviderScope(child: DijigooApp()));
    await tester.pump();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Aktivasyonu göster'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sube-login-link')));
    await tester.pumpAndSettle();
    expect(find.text('Şube Girişi'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('sube-email')),
      SessionController.agencyDemoEmail,
    );
    await tester.enterText(
      find.byKey(const Key('sube-password')),
      SessionController.agencyDemoPassword,
    );
    await tester.tap(find.byKey(const Key('sube-login')));
    await tester.pumpAndSettle();
    expect(find.text('Güney Acente'), findsOneWidget);
    expect(find.text('Merkeze Sevk'), findsOneWidget);
  });

  testWidgets('menüde gün sonu açılır', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gün sonu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gün sonu'));
    await tester.pumpAndSettle();
    expect(find.text('Vardiyayı bitir'), findsOneWidget);
  });

  testWidgets('eğitim modülü açılır ve tamamlandı işaretlenir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Eğitim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eğitim'));
    await tester.pumpAndSettle();
    expect(find.text('Trafik güvenliği'), findsOneWidget);
    await tester.tap(find.text('Trafik güvenliği'));
    await tester.pumpAndSettle();
    expect(find.text('Tamamlandı olarak işaretle'), findsOneWidget);
    await tester.tap(find.text('Tamamlandı olarak işaretle'));
    await tester.pumpAndSettle();
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.text('Tamamlandı olarak işaretle'), findsNothing);
  });

  testWidgets(
    'İade/Geri Teslim: sekmeler arası geçer ve şubeye teslimi onaylar',
    (tester) async {
      await bindPhone(tester);
      final session = SessionController();
      session.skipToDemo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith((ref) => session)],
          child: const L10nScope(
            l10n: L10n('tr'),
            child: MaterialApp(home: ReturnScreen(taskId: 't4')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Neden teslim edilemedi?'), findsOneWidget);
      await tester.tap(find.text('Geri Teslim'));
      await tester.pumpAndSettle();
      expect(find.text('Fatma Şahin — Yeni Mah.'), findsOneWidget);
      await tester.tap(find.text('Şubeye teslim ettim'));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.checkCircle2), findsOneWidget);
      expect(find.text('Şubeye teslim ettim'), findsNothing);
    },
  );
}
