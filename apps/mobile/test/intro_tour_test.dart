import 'package:dijigoo_kurye/intro_tour.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpTour(
    WidgetTester tester, {
    required bool show,
    required VoidCallback onDone,
    bool branch = false,
  }) async {
    const l = L10n('tr');
    await tester.pumpWidget(
      MaterialApp(
        theme: Dg.theme(),
        home: Scaffold(
          body: IntroTourTrigger(
            show: show,
            steps: branch ? branchIntroSteps(l) : courierIntroSteps(l),
            onDone: onDone,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tanıtım bir kez açılır, adım adım ilerler, bitince bildirir', (
    tester,
  ) async {
    var done = 0;
    await pumpTour(tester, show: true, onDone: () => done++);
    expect(find.text('Sıradaki durağın'), findsOneWidget);

    for (final title in [
      'Teslim et',
      'Barkod okut',
      'İnternet yoksa da çalış',
    ]) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    // Son adımda "Geç" yok, düğme "Başla".
    expect(find.text('Geç'), findsNothing);
    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(find.text('İnternet yoksa da çalış'), findsNothing);
  });

  testWidgets('"Geç" tanıtımı kapatır; görülmüşse hiç açılmaz', (tester) async {
    var done = 0;
    await pumpTour(tester, show: true, branch: true, onDone: () => done++);
    expect(find.text('Günün özeti'), findsOneWidget);
    await tester.tap(find.text('Geç'));
    await tester.pumpAndSettle();
    expect(done, 1);

    await pumpTour(tester, show: false, onDone: () => done++);
    expect(find.text('Sıradaki durağın'), findsNothing);
    expect(done, 1);
  });
}
