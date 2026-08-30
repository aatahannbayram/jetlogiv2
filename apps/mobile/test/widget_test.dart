import 'package:dijigoo_kurye/app.dart';
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
    expect(find.text('Kurye'), findsOneWidget);
    expect(find.text('Vardiyaya başla'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('görüşme demosu teslimatı bitirir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.text('Vardiya açık  ·  Güney / Denizli'), findsOneWidget);

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

  testWidgets('rota zaman çizelgesi durakları gösterir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.byIcon(Icons.near_me_outlined));
    await tester.pumpAndSettle();
    expect(find.text('4 durak kaldı. Durağa basınca yol tarifi açılır.'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.text('Elif Koç'), findsOneWidget);
  });

  testWidgets('dağıtım listesi sekmeleri durak sayısını gösterir', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Dağıtım'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    expect(find.textContaining('Bekleyen ('), findsOneWidget);
  });

  testWidgets('menü ekranı yeni bölümlere gider', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    expect(find.text('Kazanç & Prim'), findsOneWidget);

    await tester.tap(find.text('Kazanç & Prim'));
    await tester.pumpAndSettle();
    expect(find.text('₺842'), findsOneWidget);
  });

  testWidgets('profil koduna 5 dokunuş mühendis katmanını açar', (tester) async {
    await bindPhone(tester);
    await openDemo(tester);

    await tester.tap(find.text('Profil'));
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
}
