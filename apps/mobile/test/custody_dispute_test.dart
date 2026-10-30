import 'package:dijigoo_kurye/api/models.dart';
import 'package:dijigoo_kurye/screens/zimmet_screen.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<SessionController> openZimmet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = SessionController();
    s.custodyItems = const [
      CustodyItemDto(
        id: 'i1',
        type: 'parcel',
        description: 'Ayşe Yılmaz',
        quantity: 1,
        acquiredAt: '',
        barcode: 'JD-100',
      ),
    ];
    s.zimmetScans.add((code: 'JD-999', time: '10:00'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => s)],
        child: const MaterialApp(home: ZimmetScreen(mode: 'kurye')),
      ),
    );
    await tester.pumpAndSettle();
    return s;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  VoidCallback? sendAction(WidgetTester tester) =>
      tester.widget<DgButton>(find.byKey(const Key('dispute-send'))).onPressed;

  testWidgets('listede olmayan okutma "Fazla" türüyle hazır gelir', (
    tester,
  ) async {
    await openZimmet(tester);
    await tapKey(tester, 'zimmet-dispute');
    final code = tester.widget<TextField>(
      find.byKey(const Key('dispute-code')),
    );
    expect(code.controller!.text, 'JD-999');
    expect(find.text('Elimde var, listede yok'), findsOneWidget);
    expect(sendAction(tester), isNotNull);
  });

  testWidgets('eksik bildirimi kalem seçilmeden gönderilmez', (tester) async {
    final s = await openZimmet(tester);
    await tapKey(tester, 'zimmet-dispute');
    await tapKey(tester, 'dispute-type-MISSING');
    expect(sendAction(tester), isNull);
    await tester.tap(find.text('JD-100'));
    await tester.pumpAndSettle();
    expect(sendAction(tester), isNotNull);
    await tapKey(tester, 'dispute-send');
    expect(find.text('Uyuşmazlık bildirildi'), findsOneWidget);
    // Demo oturumu: destek kaydı olarak gider.
    expect(s.tickets.first.subject, contains('Eksik'));
  });

  testWidgets('"Diğer" açıklamasız gönderilmez', (tester) async {
    await openZimmet(tester);
    await tapKey(tester, 'zimmet-dispute');
    await tapKey(tester, 'dispute-type-OTHER');
    expect(sendAction(tester), isNull);
    await tester.enterText(
      find.byKey(const Key('dispute-note')),
      'Koli bandı açık',
    );
    await tester.pumpAndSettle();
    expect(sendAction(tester), isNotNull);
  });

  testWidgets('fotoğraf eklenir, kaldırılır; "Diğer"de düğme yok', (
    tester,
  ) async {
    await openZimmet(tester);
    await tapKey(tester, 'zimmet-dispute');
    await tapKey(tester, 'dispute-type-DAMAGED');
    await tapKey(tester, 'dispute-photo');
    expect(find.text('Fotoğraf eklendi'), findsOneWidget);
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dispute-photo')), findsOneWidget);
    await tapKey(tester, 'dispute-type-OTHER');
    expect(find.byKey(const Key('dispute-photo')), findsNothing);
  });
}
