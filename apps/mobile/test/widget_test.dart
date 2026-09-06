import 'package:dijigoo_kurye/app.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.tap(find.text('Vardiyaya başla'));
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
    expect(find.text('Doğrulama kodu gönder'), findsOneWidget);
    await tester.tap(find.text('Şifre ile gir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-identifier')), findsOneWidget);
    expect(find.byKey(const Key('panel-password')), findsOneWidget);
    expect(find.text('Panele gir'), findsOneWidget);
    expect(find.text('Doğrulama kodu gönder'), findsNothing);
    await tester.tap(find.text('SMS kodu ile gir'));
    await tester.pumpAndSettle();
    expect(find.text('Doğrulama kodu gönder'), findsOneWidget);
  });

  testWidgets('görüşme demosu teslimatı bitirir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.text('Güney / Denizli'), findsOneWidget);

    await tester.tap(find.text('Teslime başla'));
    await tester.pumpAndSettle();
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
    expect(find.text('Gönderi ve kuyruk'), findsOneWidget);
    expect(find.text('Gönderi'), findsNothing);
    await tester.tap(find.text('Gönderi ve kuyruk'));
    await tester.pumpAndSettle();
    expect(find.text('Gönderi'), findsOneWidget);
    expect(find.text('Kuyruk'), findsOneWidget);
    expect(find.text('Teslime başla'), findsOneWidget);
    expect(find.text('Yol tarifi'), findsOneWidget);
  });

  testWidgets('rota zaman çizelgesi durakları gösterir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Rotayı gör'));
    await tester.pumpAndSettle();
    expect(find.text('4 durak kaldı. Durağa basınca yol tarifi açılır.'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.text('Elif Koç'), findsOneWidget);
  });

  testWidgets('dağıtım listesi sekmeleri durak sayısını gösterir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Rota'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.textContaining('Açık '), findsWidgets);
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
    expect(find.text('Start delivery'), findsOneWidget);
    expect(find.text('Next stop'), findsOneWidget);
    expect(Dg.dark, isFalse);
  });
}
