import 'package:dijigoo_kurye/api/courier_tasks.dart';
import 'package:dijigoo_kurye/courier_home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uzak sayaç yoksa yerel sayı kalır', () {
    expect(dashCount(const {}, 'awaitingDelivery', 4), 4);
    expect(dashCount(const {'awaitingDelivery': 0}, 'awaitingDelivery', 4), 0);
    expect(dashCount(const {'overdue': 2}, 'awaitingDelivery', 4), 4);
  });

  test('kart işareti sodexo yemeğini kart saymaz', () {
    expect(
      isCardMarker(productCode: 'CARD_DELIVERY', customerCode: 'SODEXO'),
      isTrue,
    );
    expect(isCardMarker(serviceType: 'KART'), isTrue);
    expect(isCardMarker(customerCode: 'SODEXO'), isFalse);
    expect(isCardMarker(productCode: 'MEAL'), isFalse);
    expect(isCardMarker(), isFalse);
    expect(isNeighborDropOff('NEIGHBOR', 'Komşu'), isTrue);
    expect(isNeighborDropOff('SELF', 'Kendisi'), isFalse);
  });

  test('alıcı numarası köprü diye çevrilmez', () {
    expect(
      bridgeDial(
        phone: '+905321110026',
        telUri: '',
        recipient: '0532 111 00 26',
      ),
      isNull,
    );
    expect(
      bridgeDial(
        phone: '08504808538',
        telUri: '',
        recipient: '05321110026',
      ),
      '08504808538',
    );
    expect(
      bridgeDial(phone: '', telUri: '', recipient: '05321110026'),
      isNull,
    );
  });

  test('ORIGINATED çevirici açmaz, numara varsa arama numarayla başlar', () {
    final originated = planPanelCall(
      mode: 'ORIGINATED',
      message: 'Seni ve alıcıyı arıyoruz, telefonun birazdan çalacak.',
    );
    expect(originated.ringsViaPbx, isTrue);
    expect(originated.target, isNull);
    expect(originated.notice, contains('çalacak'));

    final transition = planPanelCall(
      phone: '05321110026',
      telUri: 'tel:+905321110026',
    );
    expect(transition.ringsViaPbx, isFalse);
    expect(transition.target, 'tel:+905321110026');

    final silent = planPanelCall();
    expect(silent.ringsViaPbx, isTrue);
    expect(silent.notice, isNull);
  });

  test('sesli barkod rakam kelimelerini birleştirir', () {
    expect(barcodeFromSpeech('sekiz sekiz dört dört'), '8844');
    expect(barcodeFromSpeech('barkod DGO 12'), 'DGO12');
    expect(barcodeFromSpeech('seksen sekiz kırk'), '8840');
    expect(barcodeFromSpeech('DGO on iki sıfır'), 'DGO120');
  });

  test('panel alıcının kendi numarasını dönerse çevirici açılmaz', () {
    final leak = planPanelCall(
      phone: '+905321110026',
      telUri: 'tel:+905321110026',
      recipientPhone: '0532 111 00 26',
    );
    expect(leak.blocked, isTrue);
    expect(leak.target, isNull);
    expect(leak.ringsViaPbx, isFalse);

    final bridge = planPanelCall(
      phone: '08504808538',
      recipientPhone: '05321110026',
    );
    expect(bridge.blocked, isFalse);
    expect(bridge.target, '08504808538');
  });

  test('panelde mode yoksa (geçiş dönemi) numara çevrilmez', () {
    final plan = planPanelCall(
      phone: '05321113427',
      telUri: 'tel:+905321113427',
      recipientPhone: '+90 5** *** 34 27',
      requireExchange: true,
    );
    expect(plan.blocked, isTrue);
    expect(plan.target, isNull);
    expect(
      planPanelCall(mode: 'ORIGINATED', requireExchange: true).ringsViaPbx,
      isTrue,
    );
  });

  test('numara maskeli gösterilir', () {
    expect(maskPhone('+905321113427'), '+90 5** *** 34 27');
    expect(maskPhone('0532 111 34 27'), '+90 5** *** 34 27');
    expect(maskPhone('123'), isNull);
    expect(maskPhone(null), isNull);
    expect(maskPhone('+90 5** *** 34 27'), '+90 5** *** 34 27');
  });

  test('panel neden kodu aynen gider, ad üzerinden 9302 olmaz', () {
    const rows = [
      (code: '9310', name: 'Vefat'),
      (code: '9309', name: 'Hasarlı / Sorunlu Gönderi'),
    ];
    expect(panelReasonCodeFor('Vefat', rows), '9310');
    expect(panelReasonCodeFor('Hasarlı / Sorunlu Gönderi', rows), '9309');
    expect(panelReasonCodeFor('Alıcı teslim almadı', rows), '9303');
  });

  test('V3 §4.1 kanıt kuralları', () {
    expect(failureEvidence('Vefat'), (photo: false, note: true));
    expect(failureEvidence('Hasarlı / Sorunlu Gönderi'), (photo: true, note: true));
    expect(failureEvidence('Mücbir / Operasyonel Engel').photo, isFalse);
    expect(failureEvidence('Diğer / Merkez Desteği').note, isTrue);
    expect(failureEvidence('Taşınmış / Tanınmıyor').photo, isTrue);
    expect(failureEvidence('Alıcı adreste yok').photo, isTrue);
  });

  test('geofence konum yoksa karar vermez, 500 m içi uygun', () {
    expect(
      geofenceDistance(
        located: false,
        selfLat: 41,
        selfLng: 29,
        stopLat: 41,
        stopLng: 29,
        stopHasCoordinates: true,
      ),
      isNull,
    );
    final d = geofenceDistance(
      located: true,
      selfLat: 41.0,
      selfLng: 29.0,
      stopLat: 41.003,
      stopLng: 29.0,
      stopHasCoordinates: true,
    )!;
    expect(d, closeTo(333, 5));
    expect(d <= kDefaultGeofenceMeters, isTrue);
    expect(etaLabel(135), '2 sa 15 dk');
    expect(etaLabel(45), '45 dk');
    expect(distanceLabel(18400), '18,4 km');
    expect(distanceLabel(450), '450 m');
  });

  test('ulaşılamadı nedenlerinde arama denemesi istenir', () {
    expect(callRequiredForFailure('Alıcıya Ulaşılamadı'), isTrue);
    expect(callRequiredForFailure('Alıcı adreste yok'), isTrue);
    expect(callRequiredForFailure('Alıcı Kabul Etmedi'), isTrue);
    expect(callRequiredForFailure('Randevu / İleri Tarih'), isTrue);
    expect(callRequiredForFailure('Vefat'), isFalse);
    expect(callRequiredForFailure('Hatalı / Yetersiz Adres'), isFalse);
  });
}
