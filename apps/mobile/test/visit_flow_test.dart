import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/api/courier_tasks.dart';
import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/api/panel_models.dart';
import 'package:dijigoo_kurye/capture_check.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/notif.dart';
import 'package:dijigoo_kurye/screens/account_screens.dart';
import 'package:dijigoo_kurye/screens/join_screens.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/visit_requirements.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Preprod'dan 2026-10-13'te alınan gerçek `…/requirements` yanıtı
/// (Pluxee sticker ziyareti).
Map<String, dynamic> _requirementsBody() => jsonDecode(
  File('test/fixtures/pluxee_requirements.json').readAsStringSync(),
) as Map<String, dynamic>;

VisitRequirements _pluxee() => VisitRequirements.fromJson(
  Map<String, dynamic>.from(_requirementsBody()['data'] as Map),
);

Uint8List _rgba(int w, int h, int Function(int x, int y) gray) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      final g = gray(x, y);
      out[o] = g;
      out[o + 1] = g;
      out[o + 2] = g;
      out[o + 3] = 255;
    }
  }
  return out;
}

/// Giriş + tek görev döner; diğer istekleri [onRequest] karşılar.
Dio _visitDio(
  Object? Function(RequestOptions options) onRequest, {
  List<RequestOptions>? seen,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        void ok(Map<String, Object?> data) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': data},
          ),
        );
        final path = options.path;
        if (path.contains('/courier-auth/login')) {
          return ok({
            'courier': {'id': 'c-1', 'courierCode': 'DGC-1', 'fullName': 'A'},
          });
        }
        if (options.method == 'GET' && path.endsWith('/courier-tasks')) {
          return ok({
            'tasks': [
              {
                'id': 's-9',
                'shipmentNumber': '323',
                'statusCode': '4020',
                'recipientName': 'Atakule Pide',
                'destination': {
                  'address': 'Oran',
                  'latitude': '39.91',
                  'longitude': '32.859',
                },
              },
            ],
            'summary': {'total': 1, 'created': 0, 'planned': 1, 'today': 1},
          });
        }
        seen?.add(options);
        final custom = onRequest(options);
        if (custom is DioException) return handler.reject(custom);
        if (custom is Map<String, Object?>) return ok(custom);
        ok(const {});
      },
    ),
  );
  return dio;
}

DioException _reject(RequestOptions options, int status, String code) =>
    DioException(
      requestOptions: options,
      response: Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: status,
        data: {
          'success': false,
          'error': {'code': code},
        },
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  group('gereksinimler', () {
    test('Pluxee yanıtı: fotoğraflar, kontrol listesi, anket', () {
      final r = _pluxee();
      expect(r.guided, isTrue);
      expect(r.locationRequired, isTrue);
      expect(r.photosFor(delivered: true).map((p) => p.code), [
        'STOREFRONT',
        'STICKER_CLOSEUP',
        'STICKER_PLACEMENT',
      ]);
      expect(r.photos.first.checklist, hasLength(3));
      // Yapılamadı'da ayrı tek fotoğraf istenir.
      expect(r.photosFor(delivered: false).map((p) => p.code), ['VISIT_PROOF']);
      expect(r.formNeeded(delivered: true), isTrue);
      expect(r.formNeeded(delivered: false), isTrue);
      expect(r.form!.fields.map((f) => f.code).last, 'NOTE');
    });

    test('kontrol listesi ve anket yoksa klasik akış kalır', () {
      final r = VisitRequirements.fromJson({
        'deliveryRequirements': {
          'photos': [
            {'code': 'DELIVERY', 'label': 'Teslim fotoğrafı', 'minCount': 1},
          ],
          'appliesTo': 'DELIVERED',
        },
      });
      expect(r.guided, isFalse);
      expect(r.photosFor(delivered: false), isEmpty);
      expect(r.formNeeded(delivered: true), isFalse);
    });

    test(
      'iptal nedeni yalnız sticker yapıştırılmadıysa görünür ve zorunlu',
      () {
        final form = _pluxee().form!;
        bool shown(Map<String, Object?> v) =>
            form.visibleFields(v).any((f) => f.code == 'CANCEL_REASON');

        expect(shown({}), isFalse);
        expect(shown({'STICKER_APPLIED': true}), isFalse);
        expect(shown({'STICKER_APPLIED': false}), isTrue);

        // Zorunlu tek soru yanıtlanmadan anket eksik sayılır.
        expect(form.missing({}).map((f) => f.code), ['STICKER_APPLIED']);
        expect(form.missing({'STICKER_APPLIED': true}), isEmpty);
        // Tamamlanan ziyarette metin dışındaki her soru yanıtlanmalı.
        expect(
          form
              .missing({'STICKER_APPLIED': true}, everyQuestion: true)
              .map((f) => f.code),
          [
            'PLUXEE_MEMBER',
            'OTHER_MEAL_CARD',
            'APPLICATION_DONE',
            'STICKER_EXISTS',
          ],
        );
        expect(form.missing({'STICKER_APPLIED': false}).map((f) => f.code), [
          'CANCEL_REASON',
        ]);

        // Gizli alanın değeri ve boş yanıtlar sunucuya gitmez.
        expect(
          form.cleanValues({
            'STICKER_APPLIED': true,
            'CANCEL_REASON': 'MOVED',
            'NOTE': '  ',
          }),
          {'STICKER_APPLIED': true},
        );
      },
    );

    test('seçilen neden ankete taşınır', () {
      final form = _pluxee().form!;
      expect(form.prefillForReason('Kalıcı Olarak Kapalı'), {
        'CANCEL_REASON': 'PERMANENTLY_CLOSED',
        'STICKER_APPLIED': false,
      });
      // Türkçe büyük/küçük harf: "i" → "İ".
      expect(
        form.prefillForReason(
          'Sticker Asılmasını Kabul Etmiyor',
        )['CANCEL_REASON'],
        'STICKER_REFUSED',
      );
      expect(form.prefillForReason('Alıcı Adreste Yok'), isEmpty);
    });

    test('koşul operatörleri rehberdeki gibi', () {
      bool? t(String op, Object? rule, Object? value) => FormCondition(
        fieldCode: 'A',
        operatorCode: op,
        value: rule,
      ).test({'A': value});
      expect(t('EQ', 'x', ' x '), isTrue);
      expect(t('EQ', 5, '5'), isFalse);
      expect(t('EQ', 'x', null), isFalse);
      expect(t('NEQ', 'x', null), isTrue);
      expect(t('CONTAINS', 'b', ['a', 'b']), isTrue);
      expect(t('IS_EMPTY', null, const <String>[]), isTrue);
      expect(t('NOT_EMPTY', null, false), isTrue);
      expect(t('BILINMEYEN', null, 1), isNull);
    });
  });

  group('çekim kontrolü', () {
    test('karanlık, parlak, bulanık ve iyi fotoğraf ayrılır', () {
      expect(gradeRgba(_rgba(64, 48, (_, _) => 10), 64, 48).quality, 'DARK');
      expect(gradeRgba(_rgba(64, 48, (_, _) => 250), 64, 48).quality, 'BRIGHT');
      // Düz gri: kenar yok.
      expect(gradeRgba(_rgba(64, 48, (_, _) => 128), 64, 48).quality, 'BLURRY');
      final sharp = gradeRgba(
        _rgba(64, 48, (x, y) => ((x ~/ 4) + (y ~/ 4)).isEven ? 60 : 200),
        64,
        48,
      );
      expect(sharp.quality, 'GOOD');
      expect(sharp.ok, isTrue);
    });

    test('neden yalnız kontrolden geçmeyen fotoğrafta gider', () {
      const bad = CaptureQuality(
        quality: 'DARK',
        brightness: 12,
        sharpness: 80,
      );
      expect(
        captureCheckJson(
          quality: bad,
          selfChecked: true,
          overrideReason: 'LIGHTING',
          distanceMeters: 240,
        ),
        {
          'source': 'CAMERA',
          'quality': 'DARK',
          'brightness': 12.0,
          'sharpness': 80.0,
          'overrideReason': 'LIGHTING',
          'distanceMeters': 240,
          'selfChecked': true,
        },
      );
      const good = CaptureQuality(
        quality: 'GOOD',
        brightness: 120,
        sharpness: 300,
      );
      expect(
        captureCheckJson(
          quality: good,
          selfChecked: true,
          overrideReason: 'OTHER',
        ).containsKey('overrideReason'),
        isFalse,
      );
    });
  });

  group('istekler', () {
    test(
      'fotoğraf yüklemesi captureCheck ve gereksinim koduyla gider',
      () async {
        final seen = <RequestOptions>[];
        final api = PanelApi(
          _visitDio(
            (_) => {
              // Gerçek yanıt biçimi: data.evidence.id.
              'evidence': {'id': 'e-1', 'evidenceType': 'PHOTO'},
            },
            seen: seen,
          ),
        );
        final id = await api.uploadTaskEvidence(
          shipmentId: 's-9',
          bytes: const [1, 2, 3],
          filename: 'photo.jpg',
          evidenceType: 'PHOTO',
          requirementCode: 'STOREFRONT',
          category: 'DELIVERY',
          captureCheck: const {'source': 'CAMERA', 'selfChecked': true},
          latitude: 39.91,
          longitude: 32.85,
        );
        expect(id, 'e-1');
        final req = seen.single;
        expect(req.path, '/courier-tasks/s-9/evidence');
        expect(req.headers['Idempotency-Key'], hasLength(36));
        final fields = {
          for (final f in (req.data as FormData).fields) f.key: f.value,
        };
        expect(fields['requirementCode'], 'STOREFRONT');
        expect(fields['category'], 'DELIVERY');
        expect(jsonDecode(fields['captureCheck']!), {
          'source': 'CAMERA',
          'selfChecked': true,
        });
        expect(fields['latitude'], '39.91');
      },
    );

    test(
      'anket PUT ile SUBMITTED gider; nedenler gönderiye göre istenir',
      () async {
        final seen = <RequestOptions>[];
        final api = PanelApi(
          _visitDio(
            (o) => o.path.contains('delivery-reasons')
                ? {
                    'failed': [
                      {'code': '9335', 'name': 'Kalıcı Olarak Kapalı'},
                    ],
                  }
                : null,
            seen: seen,
          ),
        );
        await api.saveTaskForm(
          's-9',
          formVersionId: 'v-1',
          values: const {'STICKER_APPLIED': true},
        );
        expect(seen.single.method, 'PUT');
        expect(seen.single.data, {
          'formVersionId': 'v-1',
          'status': 'SUBMITTED',
          'values': {'STICKER_APPLIED': true},
        });

        final reasons = await api.fetchDeliveryReasons(shipmentId: 's-9');
        expect(reasons.single.code, '9335');
        expect(seen.last.queryParameters['shipmentId'], 's-9');
      },
    );

    test('Hatalarım yanıtı: puan yokken UNRATED', () async {
      final api = PanelApi(
        _visitDio(
          (_) => {
            'items': [
              {
                'evidenceId': 'e-1',
                'shipmentNumber': '323',
                'requirementLabel': 'İşletme dış cephe ve tabela',
                'reasonCode': 'BLURRY',
                'reason': 'Tabela okunmuyor',
                'capturedAt': '2026-10-13T09:00:00.000Z',
                'acknowledgedAt': null,
              },
            ],
            'unacknowledged': 1,
            'score': {
              'photos': 4,
              'rejected': 1,
              'score': null,
              'band': 'UNRATED',
              'minPhotos': 10,
              'windowDays': 30,
            },
          },
        ),
      );
      final m = await api.fetchPhotoMistakes();
      expect(m.unacknowledged, 1);
      expect(m.score, isNull);
      expect(m.band, 'UNRATED');
      expect(m.photos, 4);
      expect(m.items.single.reasonCode, 'BLURRY');
      expect(m.items.single.acknowledgedAt, isNull);
    });
  });

  group('ziyareti kapatma', () {
    Future<SessionController> login(Dio dio) async {
      final s = SessionController(
        panel: PanelApi(dio),
        api: MobileApi(dio: dio),
      );
      expect(
        await s.loginWithPanel(identifier: 'a@b.com', password: 'x'),
        isTrue,
      );
      return s;
    }

    test('yapılamadı: önce anket, sonra nedenle kapatma', () async {
      final seen = <RequestOptions>[];
      final s = await login(
        _visitDio(
          (o) => o.path.endsWith('/requirements')
              ? Map<String, Object?>.from(_requirementsBody()['data'] as Map)
              : null,
          seen: seen,
        ),
      );
      await s.loadTaskRequirements('s-9');
      final form = s.visitRequirements('s-9')!.form!;
      expect(s.visitRequirements('baska'), isNull);
      seen.clear();

      await s.finalizeVisit(
        's-9',
        delivered: false,
        reasonCode: '9335',
        note: 'Kepenk kapalı',
        form: form,
        formValues: form.prefillForReason('Kalıcı Olarak Kapalı'),
      );

      final writes = [
        for (final o in seen)
          if (o.method != 'GET') o,
      ];
      expect(writes.map((o) => o.path.split('/').last), ['form', 'finalize']);
      expect((writes[0].data as Map)['values'], {
        'STICKER_APPLIED': false,
        'CANCEL_REASON': 'PERMANENTLY_CLOSED',
      });
      final body = writes[1].data as Map;
      expect(body['resultCode'], 'DELIVERY_FAILED');
      expect(body['reasonCode'], '9335');
      expect(body['note'], 'Kepenk kapalı');
      expect(s.taskById('s-9').status, TaskStatus.failed);
    });

    test(
      'sunucu reddederse görev açık kalır, hata kuryeye anlatılır',
      () async {
        final s = await login(
          _visitDio(
            (o) => o.path.endsWith('/finalize')
                ? _reject(o, 422, 'PX_STICKER_TOO_FAR_FROM_ADDRESS:812m')
                : null,
          ),
        );
        final before = s.taskById('s-9').status;
        PanelApiException? error;
        try {
          await s.finalizeVisit('s-9', delivered: true);
        } on PanelApiException catch (e) {
          error = e;
        }
        expect(error!.code, 'PX_STICKER_TOO_FAR_FROM_ADDRESS:812m');
        expect(s.taskById('s-9').status, before);
        expect(
          const L10n('tr').visitError(error.code),
          'Adrese uzak görünüyorsun. Adrese yaklaşıp tekrar dene.',
        );
      },
    );

    test('daha önce gönderilmiş anket kapatmayı engellemez', () async {
      final s = await login(
        _visitDio(
          (o) => o.path.endsWith('/form')
              ? _reject(o, 409, 'FORM_ALREADY_SUBMITTED')
              : null,
        ),
      );
      await s.finalizeVisit(
        's-9',
        delivered: true,
        form: _pluxee().form,
        formValues: const {'STICKER_APPLIED': true},
      );
      expect(s.taskById('s-9').status, TaskStatus.delivered);
    });

    test(
      'sayısal durum kodları: 4020 dağıtımda, 5010 teslim, 5110 edilemedi',
      () {
        expect(taskStatusFromPanel('4010'), TaskStatus.assigned);
        expect(taskStatusFromPanel('4020'), TaskStatus.inProgress);
        expect(taskStatusFromPanel('5010'), TaskStatus.delivered);
        expect(taskStatusFromPanel('5110'), TaskStatus.failed);
        expect(taskStatusFromPanel('8010'), TaskStatus.cancelled);
      },
    );

    test('reddedilen fotoğraf bildirimi Hatalarım\'ı açar', () {
      expect(notifKindFromPush('EVIDENCE_REJECTED'), NotifKind.photoRejected);
      expect(
        notifOpenTarget(NotifKind.photoRejected),
        NotifOpenTarget.mistakes,
      );
      expect(notifIsAlert(NotifKind.photoRejected), isTrue);
    });

    test('eksik gereksinim listesi sade dille yazılır', () {
      expect(
        const L10n('tr').visitError(
          'DELIVERY_REQUIREMENTS_MISSING',
          missing: ['PHOTO', 'FORM', 'PHOTO'],
        ),
        'Eksik: fotoğraf, anket.',
      );
    });
  });

  group('SMS ile giriş', () {
    test('kod JetDiji\'den istenir, doğrulanınca oturum açılır', () async {
      final seen = <RequestOptions>[];
      final s = SessionController(
        panel: PanelApi(
          _visitDio(
            (o) => o.path.endsWith('/sms/request')
                ? {'challengeId': 'ch-1', 'resendAfterSeconds': 60}
                : o.path.endsWith('/sms/verify')
                ? {
                    'accessToken': 'tok',
                    'courier': {
                      'id': 'c-1',
                      'courierCode': 'DGC-1',
                      'fullName': 'Ayşe Kurye',
                    },
                  }
                : null,
            seen: seen,
          ),
        ),
      );
      expect(await s.requestActivationCode(' 0500 000 06 11 '), isTrue);
      expect(seen.single.path, '/courier-auth/sms/request');
      expect(seen.single.data, {'identifier': '0500 000 06 11'});
      expect(s.challengeId, 'ch-1');

      expect(await s.verifyLoginOtp('482913'), isTrue);
      final verify = seen.firstWhere((o) => o.path.endsWith('/sms/verify'));
      expect(verify.data, {'challengeId': 'ch-1', 'code': '482913'});
      expect(s.panelLoggedIn, isTrue);
      expect(s.tasks.single.id, 's-9');
    });

    test('yanlış kodda kalan deneme hakkı söylenir', () async {
      final s = SessionController(
        panel: PanelApi(
          _visitDio(
            (o) => o.path.endsWith('/sms/request')
                ? {'challengeId': 'ch-1'}
                : o.path.endsWith('/sms/verify')
                ? DioException(
                    requestOptions: o,
                    response: Response<Map<String, dynamic>>(
                      requestOptions: o,
                      statusCode: 401,
                      data: {
                        'success': false,
                        'error': {
                          'code': 'SMS_CODE_INVALID',
                          'remainingAttempts': 4,
                        },
                      },
                    ),
                    type: DioExceptionType.badResponse,
                  )
                : null,
          ),
        ),
      );
      await s.requestActivationCode('05000000611');
      expect(await s.verifyLoginOtp('000000'), isFalse);
      expect(s.panelLoggedIn, isFalse);
      expect(
        const L10n('tr')
            .smsLoginError(s.lastActivationError, s.loginRemainingAttempts),
        'Kod yanlış. 4 deneme hakkın kaldı.',
      );
    });
  });

  group('tutanak, zimmet geçmişi, duyuru onayı', () {
    test('tutanak iki imza ve karşı taraf adıyla gider', () async {
      final seen = <RequestOptions>[];
      final api = PanelApi(_visitDio((_) => null, seen: seen));
      await api.createReport(
        's-9',
        reportType: 'DAMAGE',
        courierSignature: 'data:image/png;base64,AA==',
        courierName: 'Ayşe Kurye',
        counterpartSignature: 'data:image/png;base64,BB==',
        counterpartName: 'Bora Kaya',
        note: 'Koli ezik',
        idempotencyKey: 'key-12345678',
      );
      final req = seen.single;
      expect(req.path, '/courier-tasks/s-9/reports');
      expect(req.headers['Idempotency-Key'], 'key-12345678');
      expect(req.data, {
        'reportType': 'DAMAGE',
        'status': 'SUBMITTED',
        'note': 'Koli ezik',
        'courierSignature': {
          'dataUrl': 'data:image/png;base64,AA==',
          'signerName': 'Ayşe Kurye',
        },
        'counterpartSignature': {
          'dataUrl': 'data:image/png;base64,BB==',
          'signerName': 'Bora Kaya',
        },
      });
    });

    test('zimmet geçmişi: yön, karşı taraf ve durum', () async {
      final api = PanelApi(
        _visitDio(
          (_) => {
            'items': [
              {
                'direction': 'IN',
                'shipmentNumber': '334',
                'recipientName': 'Ulus Kafe',
                'counterparty': {'type': 'UNIT', 'name': 'DEMO-ANKARA'},
                'status': 'ACCEPTED',
                'completedAt': '2026-10-13T11:10:00.000Z',
              },
              {
                'direction': 'OUT',
                'shipmentNumber': '342',
                'status': 'PENDING',
              },
            ],
          },
        ),
      );
      final rows = await api.fetchCustodyHistory();
      expect(rows.first.incoming, isTrue);
      expect(rows.first.counterparty, 'DEMO-ANKARA');
      expect(rows.first.at, isNotNull);
      expect(rows.last.incoming, isFalse);
      expect(const L10n('tr').custodyMoveStatus(rows.last.status), 'Bekliyor');
    });

    test('onay isteyen duyuru "okudum" denince onaylanır', () async {
      final seen = <RequestOptions>[];
      final dio = _visitDio(
        (o) => o.path.endsWith('/courier-notifications')
            ? {
                'items': [
                  {
                    'id': 'n-1',
                    'category': 'ANNOUNCEMENT',
                    'severity': 'INFO',
                    'title': 'Yeni çekim kuralı',
                    'body': 'Tabela mutlaka kadrajda olsun.',
                    'read': false,
                    'createdAt': '2026-10-13T09:00:00.000Z',
                    'announcement': {
                      'id': 'a-1',
                      'requiresAck': true,
                      'acknowledgedAt': null,
                    },
                  },
                ],
              }
            : null,
        seen: seen,
      );
      final s = SessionController(
        panel: PanelApi(dio),
        api: MobileApi(dio: dio),
      );
      await s.loginWithPanel(identifier: 'a@b.com', password: 'x');
      await s.loadCourierNotifications();
      final n = s.notifications.firstWhere((n) => n.announcementId == 'a-1');
      expect(n.title, 'Yeni çekim kuralı');
      expect(n.needsAck, isTrue);

      expect(await s.acknowledgeAnnouncement(n.id), isTrue);
      expect(
        seen.any(
          (o) => o.path == '/courier-notifications/announcements/a-1/ack',
        ),
        isTrue,
      );
      expect(s.notifications.firstWhere((x) => x.id == n.id).needsAck, isFalse);
    });
  });

  group('şifre ve müsaitlik', () {
    test('şifre kuralı sunucununkiyle aynı', () {
      expect(passwordStrongEnough('JetDemo06.Ankara'), isTrue);
      expect(passwordStrongEnough('Kısa1.'), isFalse);
      expect(passwordStrongEnough('hepkucukharf1.'), isFalse);
      expect(passwordStrongEnough('IsaretYok12345'), isFalse);
      expect(passwordStrongEnough('RakamYok.....a'), isFalse);
    });

    test('şifre değişince yeni token kullanılır', () async {
      final seen = <RequestOptions>[];
      final api = PanelApi(
        _visitDio(
          (o) => o.path.endsWith('/change-password')
              ? {
                  'passwordChangedAt': '2026-10-13T12:00:00.000Z',
                  'accessToken': 'yeni',
                }
              : null,
          seen: seen,
        ),
      );
      await api.changePassword(
        currentPassword: 'eski',
        newPassword: 'Yeni.Sifre.123',
      );
      expect(seen.single.data, {
        'currentPassword': 'eski',
        'newPassword': 'Yeni.Sifre.123',
        'newPasswordConfirmation': 'Yeni.Sifre.123',
      });
      await api.fetchAvailability();
      expect(seen.last.headers['Authorization'], 'Bearer yeni');
    });

    test('müsaitlik: eksik günler kapalı tamamlanır, istisnalar korunur', () {
      final plan = AvailabilityDto.fromJson({
        'days': [
          {
            'dayIndex': 1,
            'enabled': true,
            'ranges': [
              {'id': 'r1', 'start': '09:00', 'end': '18:00', 'sortOrder': 0},
            ],
          },
        ],
        'exceptions': [
          {
            'id': 'x1',
            'date': '2026-10-29',
            'type': 'HOLIDAY',
            'startTime': null,
            'endTime': null,
            'note': '',
            'updatedAt': '2026-10-01T00:00:00.000Z',
          },
        ],
      });
      expect(plan.days, hasLength(7));
      expect(plan.days[1].enabled, isTrue);
      expect(plan.days[0].enabled, isFalse);
      final json = plan.toJson();
      expect((json['days'] as List), hasLength(7));
      expect((json['days'] as List)[1], {
        'dayIndex': 1,
        'enabled': true,
        'ranges': [
          {'start': '09:00', 'end': '18:00'},
        ],
      });
      // Sunucu tam değiştirir; istisna geri gönderilmezse silinir.
      expect(json['exceptions'], [
        {'date': '2026-10-29', 'type': 'HOLIDAY'},
      ]);
      // Boş yanıt (hiç plan yok) da 7 kapalı gün verir.
      expect(
        AvailabilityDto.fromJson(const {}).days.every((d) => !d.enabled),
        isTrue,
      );
    });
  });

  group('kurye ol, hesap açma, evrak', () {
    test('e-posta bağlantısından token ve kimlik çıkarılır', () {
      final doc = parseJoinLink(
        ' https://jetdiji.com/kurye-belgeleri/pub_123?token=abc.def ',
      );
      expect(doc.publicId, 'pub_123');
      expect(doc.token, 'abc.def');
      expect(
        parseJoinLink('https://jetdiji.com/aktivasyon?token=T1').token,
        'T1',
      );
      // Yalnız token yapıştırılmışsa da olur; boşluklu metin bağlantı değildir.
      expect(parseJoinLink('T1').token, 'T1');
      expect(parseJoinLink('bu bir bağlantı değil').token, isNull);
      expect(parseJoinLink('https://jetdiji.com/x').token, isNull);
    });

    test('ilk şifre kuralı: 8 karakter, büyük, küçük, rakam', () {
      expect(activationPasswordOk('Kurye123'), isTrue);
      expect(activationPasswordOk('kurye123'), isFalse);
      expect(activationPasswordOk('Kurye12'), isFalse);
      expect(activationPasswordOk('KuryeKurye'), isFalse);
    });

    test('aktivasyon, başvuru ve evrak istekleri doğru yere gider', () async {
      final seen = <RequestOptions>[];
      final api = PanelApi(
        _visitDio(
          (o) => o.path.endsWith('/check-phone')
              ? {'canApply': false}
              : o.path.endsWith('/courier-applications')
              ? {'applicationNumber': 'DGO-1'}
              : null,
          seen: seen,
        ),
      );
      await api.activateAccount(token: 'T1', password: 'Kurye123');
      expect(seen.last.path, '/courier-auth/activate');
      expect(seen.last.data, {
        'token': 'T1',
        'password': 'Kurye123',
        'passwordConfirmation': 'Kurye123',
      });

      expect(await api.checkApplicationPhone('05000000611'), isFalse);
      expect(
        await api.submitApplication(const {'fullName': 'Ali Can'}),
        'DGO-1',
      );

      await api.uploadPortalDocument(
        publicId: 'pub_1',
        token: 'tok',
        documentRequestId: 'd-1',
        side: 'FRONT',
        bytes: const [1, 2],
        expiresAt: '2030-01-01',
      );
      expect(seen.last.path, '/courier-documents/pub_1/requests/d-1/upload');
      expect(seen.last.queryParameters, {'token': 'tok', 'side': 'FRONT'});
      expect(
        {for (final f in (seen.last.data as FormData).fields) f.key: f.value},
        {'expiresAt': '2030-01-01'},
      );

      await api.submitPortalDocuments(publicId: 'pub_1', token: 'tok');
      expect(seen.last.path, '/courier-documents/pub_1/submit');
      expect(seen.last.queryParameters, {'token': 'tok'});
    });
  });
}
