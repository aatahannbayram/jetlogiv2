import 'package:flutter/widgets.dart';

import 'models.dart';

class L10n {
  const L10n(this.code);

  final String code;

  bool get isEn => code == 'en';

  String _t(String tr, String en) => isEn ? en : tr;

  static L10n of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<L10nScope>()?.l10n ??
        const L10n('tr');
  }

  String greeting(int hour) {
    if (hour < 6) return _t('İyi geceler', 'Good night');
    if (hour < 12) return _t('Günaydın', 'Good morning');
    if (hour < 18) return _t('İyi günler', 'Good afternoon');
    return _t('İyi akşamlar', 'Good evening');
  }

  String stepOf(int current, int total) =>
      _t('Adım $current/$total', 'Step $current/$total');
  String get skip => _t('Atla', 'Skip');
  String get continueLabel => _t('Devam', 'Continue');
  String get done => _t('Tamam', 'Done');
  String get cancel => _t('Vazgeç', 'Cancel');
  String get send => _t('Gönder', 'Send');
  String get usePhoto => _t('Kullan', 'Use');
  String get retake => _t('Tekrar çek', 'Retake');
  String get clear => _t('Temizle', 'Clear');
  String get call => _t('Ara', 'Call');
  String get photo => _t('Foto', 'Photo');
  String get signature => _t('İmza', 'Signature');
  String get all => _t('Tümü', 'All');

  String get onboard1Kicker => _t('Liste', 'List');
  String get onboard1Title => _t('Üstteki durak senin.', 'The top stop is yours.');
  String get onboard1Body => _t('Numara, adres, saat kartta.', 'Number, address and window are on the card.');
  String get onboard2Kicker => _t('Yol', 'Route');
  String get onboard2Title => _t('Durağa bas, harita açılsın.', 'Tap a stop to open the map.');
  String get onboard2Body => _t('Sıra Güney. Mola üstte. Yol tarifi telefonda açılır.', 'Order is Güney. Break is on top. Directions open on the phone.');
  String get onboard3Kicker => _t('Kapanış', 'Close-out');
  String get onboard3Title => _t('Foto ve kod yoksa bitmez.', 'No photo or code, no close.');
  String get onboard3Body => _t('Kim aldı, kapı, kod. Sözleşme panele kalır.', 'Who took it, door, code. The contract stays on the panel.');
  String get inQueue => _t('Sırada', 'Queued');
  String get fourStops => _t('4 durak', '4 stops');
  String get doorPhoto => _t('Kapı fotoğrafı', 'Door photo');

  String get startShiftCta => _t('Vardiyaya başla', 'Start shift');
  String get showActivation => _t('Aktivasyonu göster', 'Show activation');
  String get openDemo => _t('Demoyu aç', 'Open demo');
  String get updateApp => _t('Uygulamayı güncelle', 'Update the app');
  String get todayStopsGuney => _t('Bugünün durakları Güney’de.', 'Today’s stops are in Güney.');
  String get todayFieldHint => _t(
    'Telefonunu doğrula; bugünün durakları sunucudan gelir.',
    'Verify your phone; today’s stops come from the server.',
  );
  String openStops(int n) => _t('$n açık durak', '$n open stops');
  String openInQueue(int n, String name) =>
      _t('$n açık · sırada $name', '$n open · next $name');
  String get panelSessionOn => _t('Panel oturumu açık', 'Panel session is on');
  String get panelSessionOff => _t('Panel oturumu kapandı', 'Panel session ended');
  String get retryNow => _t('Yeniden dene', 'Try again');
  String get panelTasksFailed =>
      _t('Görevler alınamadı.', 'Could not load tasks.');
  String get stopGone => _t('Bu durak artık listede yok.', 'This stop is no longer on the list.');

  String get welcomeShift => _t('Vardiyana hoş geldin', 'Welcome to your shift');
  String get welcomeBody => _t(
    'Telefonunla giriş yap, vardiyayı aç ve rotan hazır olsun.',
    'Sign in with your phone, open the shift, and your route is ready.',
  );
  String get smsLogin => _t('SMS kodu ile gir', 'Sign in with SMS');
  String get passwordLogin => _t('Şifre ile gir', 'Sign in with password');
  String get goToPermissions => _t('İzinlere geç', 'Continue to permissions');
  String get otherAccount => _t('Başka hesapla gir', 'Use another account');
  String get enterPanel => _t('Panele gir', 'Sign in to panel');
  String get signingIn => _t('Giriş…', 'Signing in…');
  String get sendCode => _t('Doğrulama kodu gönder', 'Send verification code');
  String get verifyCode => _t('Kodu doğrula', 'Verify code');
  String get phoneNumber => _t('Telefon numarası', 'Phone number');
  String get rememberDevice => _t('Bu cihazı hatırla', 'Remember this device');
  String get askFourDigit =>
      _t('Alıcıdan 6 haneli kodu isteyin', 'Ask the recipient for the 6-digit code');
  String get signHere => _t('Parmağınla imzala', 'Sign with your finger');
  String get codeNotDelivery => _t('Kod sizin telefonunuza gider. Teslim kodu değil.', 'The code goes to your phone. It is not the delivery code.');
  String get panelReadyHint => _t('İzinlere geç, sonra vardiyayı aç.', 'Continue to permissions, then open the shift.');
  String get loginFailed => _t('Giriş olmadı. Bilgileri kontrol et.', 'Sign-in failed. Check the details.');
  String get panelUnavailable => _t('Panel şu an ulaşılmıyor.', 'The panel is unavailable right now.');
  String get codeMismatch => _t('Kod eşleşmedi. Yeniden deneyin.', 'Code did not match. Try again.');
  String get activationSendFailed => _t('Kod gönderilemedi. Numarayı kontrol et.', 'Could not send the code. Check the number.');
  String get waitToResend => _t('Yeni kod için biraz bekle.', 'Wait a moment before requesting a new code.');
  String get proofPhotoRequired => _t('Bu gerekçe için kapı fotoğrafı zorunlu.', 'A door photo is required for this reason.');
  String get supportHint => _t('Sorun mu var? Şube yöneticine ulaş', 'Need help? Contact the branch manager');

  String get devicePermissions => _t('Cihaz izinleri', 'Device permissions');
  String get permissionsIntro => _t('Vardiya ancak bunlar tamamsa açılır.', 'The shift opens only when these are ready.');
  String readyOf(int n, int total) => _t('$n / $total hazır', '$n / $total ready');
  String get permLocation => _t('Konum', 'Location');
  String get permLocationHint => _t('Adrese vardığınızı doğrulamak için.', 'To confirm you arrived at the address.');
  String get permCamera => _t('Kamera', 'Camera');
  String get permCameraHint => _t('Barkod, teslim ve vardiya kanıtı. Galeri kapalı.', 'Barcode, delivery and shift proof. Gallery stays off.');
  String get permPush => _t('Bildirim', 'Notifications');
  String get permPushHint => _t('Yeni görev ve zorunlu güncelleme.', 'New tasks and required updates.');
  String get grantAllThree => _t('Üç izni de ver', 'Allow all three');
  String get goToShift => _t('Vardiyaya geç', 'Go to shift');
  String get noRecipientPhone =>
      _t('Alıcı telefonu yok.', 'Recipient phone is missing.');
  String get callOpening => _t('Aranıyor…', 'Calling…');

  String get startShiftTitle => _t('Vardiya başlat', 'Start shift');
  String get shiftSelfieHint => _t('Bu fotoğraf yalnız vardiya kanıtı. Yüz aranmaz.', 'This photo is shift proof only. Faces are not searched.');
  String get faceInFrame => _t('Yüzünüz kadrajda olsun.', 'Keep your face in frame.');
  String get proofTaken => _t('Kanıt alındı', 'Proof captured');
  String get openShift => _t('Vardiyayı aç', 'Open shift');
  String get takePhoto => _t('Fotoğraf çek', 'Take photo');
  String get selfieIntro => _t(
    'Kimlik kontrolü için tek selfie. Fotoğraf sadece vardiya kaydına eklenir.',
    'One selfie for identity check. The photo is added only to the shift record.',
  );
  String get faceAlign => _t('Yüzünü çerçeveye ortala, gözlük ve kask çıkarılmalı.', 'Center your face. Remove glasses and helmet.');
  String get faceOk => _t('Yüz doğrulandı. Vardiyayı başlatabilirsin.', 'Face confirmed. You can start the shift.');

  String get home => _t('Ana sayfa', 'Home');
  String get route => _t('Rota', 'Route');
  String get scan => _t('Tara', 'Scan');
  String get notifications => _t('Bildirimler', 'Notifications');
  String get menu => _t('Menü', 'Menu');
  String get nextStop => _t('Sıradaki durak', 'Next stop');
  String get seeRoute => _t('Rotayı gör', 'See route');
  String get youOnMap => _t('Sen', 'You');
  String get fleetOnMap => _t('Kuryeler', 'Couriers');
  String get optimizedRoute => _t('Optimize rota', 'Optimized route');
  String get approxRoute => _t('Yaklaşık rota', 'Approximate route');
  String get recenterRoute => _t('Rotayı ortala', 'Center route');
  String get routeComputing => _t('Rota hesaplanıyor', 'Calculating route');
  String get youToNext => _t('Konumundan', 'From you');
  String get routeFinished => _t('Rota bitti', 'Route finished');
  String etaMinutesLabel(int n) => _t('$n dk', '$n min');
  String routeKmMin(String km, int minutes) =>
      _t('$km km · $minutes dk', '$km km · $minutes min');
  String get startDelivery => _t('Teslime başla', 'Start delivery');
  String get directions => _t('Yol tarifi', 'Directions');
  String get shipment => _t('Gönderi', 'Shipment');
  String get shipmentNo => _t('Gönderi no', 'Shipment no');
  String get type => _t('Tür', 'Type');
  String get deliveryWindow => _t('Teslim aralığı', 'Delivery window');
  String get custody => _t('Zimmet', 'Custody');
  String itemsCount(int n) => _t('$n kalem', '$n items');
  String get deliveryCode => _t('Teslim kodu', 'Delivery code');
  String get required => _t('Gerekli', 'Required');
  String get cashOnDelivery => _t('Kapıda ödeme', 'Cash on delivery');
  String get note => _t('Not', 'Note');
  String get queue => _t('Kuyruk', 'Queue');
  String get order => _t('Sıra', 'Order');
  String get openStop => _t('Açık durak', 'Open stops');
  String get next => _t('Sonraki', 'Next');
  String get none => _t('Yok', 'None');
  String get sync => _t('Senkron', 'Sync');
  String get clean => _t('Temiz', 'Clean');
  String pendingRecords(int n) => _t('$n kayıt bekliyor', '$n records waiting');
  String get shipmentAndQueue => _t('Gönderi ve kuyruk', 'Shipment and queue');
  String get fieldOn => _t('Sahada', 'On duty');
  String get onBreak => _t('Mola', 'Break');
  String get syncTitle => _t('Senkronizasyon', 'Sync');
  String get syncCleanBody => _t('Tüm kayıtlar merkeze iletildi.', 'All records were sent to the hub.');
  String syncPendingBody(int n) => _t(
    '$n kayıt çevrimdışı kuyrukta, çevrimiçi olunca gönderilir.',
    '$n records are queued offline and will send when you are online.',
  );
  String pendingChip(int n) => _t('$n bekliyor', '$n waiting');
  String get noNotifications => _t('Yeni bildirim yok', 'No new notifications');
  String get markAllRead => _t('Tümü okundu', 'Mark all read');
  String get notifUnread => _t('Yeni', 'New');
  String get notifAlerts => _t('Uyarı', 'Alerts');
  String unreadLeft(int n) => _t('$n okunmamış', '$n unread');
  String get allCaughtUp => _t('Hepsi okundu', 'You\'re all caught up');
  String get noUnreadTitle => _t('Okunmamış yok', 'Nothing unread');
  String get noUnreadBody =>
      _t('Yeni bildirim kalmadı.', 'No unread notifications.');
  String get noAlertNotifs => _t('Uyarı yok', 'No alerts');
  String get noAlertNotifsBody => _t(
    'Başarısız gönderim ve iptaller burada.',
    'Failed sends and cancellations show here.',
  );
  String get notifHide => _t('Gizle', 'Hide');
  String get notifMarkedRead => _t('Okundu', 'Read');
  String get notifMarkedUnread => _t('Okunmadı', 'Unread');
  String get notifHidden => _t('Bildirim gizlendi', 'Notification hidden');
  String get undo => _t('Geri al', 'Undo');
  String get today => _t('Bugün', 'Today');
  String get earlier => _t('Daha eski', 'Earlier');
  String get notifStopGone =>
      _t('Bu durak artık listede yok.', 'That stop is no longer on your list.');
  String get shiftStatus => _t('VARDİYA DURUMU', 'SHIFT STATUS');
  String get closed => _t('Kapalı', 'Closed');
  String get shiftSelfieNeeded => _t('Vardiyayı başlatmak için selfie doğrulaması gerekir.', 'A selfie check is required to start the shift.');
  String get shiftOpen => _t('Vardiya açık', 'Shift open');
  String get shiftClosed => _t('Vardiya kapalı', 'Shift closed');
  String get endShiftTitle => _t('Vardiyayı kapat', 'End shift');
  String get endShiftBody =>
      _t('Vardiya kapanınca sıradaki durak gizlenir.', 'Ending the shift hides the next stop.');
  String sinceFrom(String time) => _t("$time’dan beri", 'since $time');
  String shiftDayLine(String time, String km) =>
      _t('$time’dan beri · $km km', 'since $time · $km km');
  String get delivered => _t('Teslim', 'Delivered');
  String get distance => _t('Mesafe', 'Distance');
  String get noNextStop => _t('Sıradaki durak yok', 'No next stop');
  String get window => _t('Aralık', 'Window');
  String get time => _t('Saat', 'Time');

  String get distribution => _t('Dağıtım', 'Dispatch');
  String openTab(int n) => _t('Açık $n', 'Open $n');
  String deliveredTab(int n) => _t('Teslim $n', 'Delivered $n');
  String returnedTab(int n) => _t('İade $n', 'Returned $n');
  String sameAddressCount(int n) =>
      _t('Aynı adres · $n gönderi', 'Same address · $n shipments');
  String get deliverTogether => _t('Birlikte teslim', 'Deliver together');

  String get myCustody => _t('Zimmetim', 'My custody');
  String get branchHandover => _t('Şubeye teslim', 'Branch handover');
  String get depotPickup => _t('Depodan alım', 'Depot pickup');
  String get supportTicket => _t('Destek talebi', 'Support ticket');
  String get sendData => _t('Verileri gönder', 'Send data');
  String get myInventory => _t('Ürün envanterim', 'My inventory');
  String get myPerformance => _t('Performansım', 'My performance');
  String get identityCheck => _t('Kimlik doğrulama', 'Identity check');
  String get fieldWork => _t('SAHA İŞLERİ', 'FIELD');
  String get account => _t('HESAP', 'ACCOUNT');
  String get deliveredShort => _t('teslim', 'done');
  String get openShort => _t('açık', 'open');
  String get returnShort => _t('iade', 'return');

  String get scanHint => _t('Zimmet almak veya teslim etmek için barkod okut.', 'Scan a barcode to take or hand over custody.');
  String get courierCustody => _t('Kurye Zimmet', 'Courier custody');
  String get courierCustodyHint => _t('Şubeden üzerine alacağın paketleri okut', 'Scan parcels you are taking from the branch');
  String get branchCustody => _t('Şube Zimmet', 'Branch custody');
  String get branchCustodyHint => _t('Şubeye teslim ettiğin paketleri okut', 'Scan parcels you are handing to the branch');
  String get courier => _t('Kurye', 'Courier');
  String get branch => _t('Şube', 'Branch');
  String get bringBarcode => _t('Barkodu çerçeveye getir', 'Bring the barcode into the frame');
  String get typeCode => _t('Kodu yaz', 'Type the code');
  String get typeCodeSend => _t('Kodu yaz ve gönder', 'Type the code and send');
  String get cameraFailed => _t('Kamera açılamadı. Kodu yazabilirsin.', 'Camera failed. You can type the code.');
  String get openCameraHint => _t('Kamerayı açıp barkodu çerçeveye getir.', 'Open the camera and bring the barcode into the frame.');
  String readCount(int n) => _t('$n okundu', '$n read');
  String get beep => _t('Bip', 'Beep');
  String get noScansYet => _t('Henüz taranan gönderi yok', 'No scanned shipments yet');
  String get complete => _t('Tamamla', 'Complete');
  String get handoverFailed => _t('Devir gönderilemedi, tekrar deneyin.', 'Handover failed. Try again.');

  String get support => _t('Destek', 'Support');
  String get openTicket => _t('Talep aç', 'Open a ticket');
  String get subject => _t('Konu', 'Subject');
  String get whatHappened => _t('Ne oldu?', 'What happened?');
  String get myRecords => _t('Kayıtlarım', 'My records');
  String get noTickets => _t('Henüz destek talebin yok.', 'You have no support tickets yet.');

  String get earnings => _t('Kazanç & Prim', 'Earnings & bonus');
  String get thisWeek => _t('Bu hafta', 'This week');
  String get deliveredCaps => _t('TESLİM', 'DONE');
  String get openCaps => _t('AÇIK', 'OPEN');
  String get returnCaps => _t('İADE', 'RETURN');
  String get pendingCaps => _t('BEKLEYEN', 'PENDING');
  String get failedCaps => _t('BAŞARISIZ', 'FAILED');

  String get inventoryTitle => _t('Ürün Envanterim', 'My inventory');
  String get addByCode => _t('Kod ile ekle', 'Add by code');

  String get depotTitle => _t('Depodan Alım', 'Depot pickup');
  String get iPickedUp => _t('Teslim aldım', 'I picked them up');

  String get waiting => _t('Bekliyor', 'Waiting');
  String get sending => _t('Gönderiliyor…', 'Sending…');
  String get queueEmpty => _t('Kuyruk boş', 'Queue is empty');
  String get pushData => _t('Verileri gönder', 'Send data');

  String get whoReceived => _t('Paketi kim aldı?', 'Who received the package?');
  String get recipientSelf => _t('Alıcının kendisi', 'The recipient');
  String get familyMember => _t('Aile bireyi', 'Family member');
  String get neighbor => _t('Komşu', 'Neighbor');
  String get workplace => _t('İş yeri / resepsiyon', 'Workplace / reception');
  String get recipient => _t('Teslim alan', 'Received by');
  String get pickRecipient => _t('Teslim alan kişiyi seçin.', 'Choose who received it.');
  String get proofNeeded => _t('Kapı fotoğrafı veya alıcı imzası gerekli.', 'A door photo or recipient signature is required.');
  String get sendCodeCta => _t('Kodu gönder', 'Send code');
  String get verifyAndDeliver => _t('Doğrula ve teslim et', 'Verify and deliver');
  String get couldNotDeliver => _t('Teslim edemedim', 'Could not deliver');
  String get deliveredOk => _t('Teslim edildi', 'Delivered');
  String get returnRecorded => _t('İade kaydedildi', 'Return recorded');
  String get nextStopCta => _t('Sıradaki durak', 'Next stop');
  String get backToList => _t('Listeye dön', 'Back to list');
  String get declaration => _t(
    'Yukarıda belirtilen gönderiyi eksiksiz ve hasarsız teslim aldığımı beyan ederim.',
    'I confirm I received the shipment above complete and undamaged.',
  );
  String get doorAndParcel => _t('Kapıyı ve paketi kadraja alın.', 'Frame the door and the parcel.');
  String get doorProof => _t('Kapı / teslim kanıtı', 'Door / delivery proof');
  String get codeRequired => _t('Kod gerekli', 'Code required');

  String get whyFailed => _t('Neden teslim edilemedi?', 'Why could it not be delivered?');
  String get whyFailedBody => _t(
    'Seçtiğin neden merkeze anında iletilir, gönderi iadeye düşer.',
    'The reason is sent to the hub immediately and the shipment is returned.',
  );
  String get optionalNote => _t('İsteğe bağlı açıklama', 'Optional note');
  String get closeAsReturn => _t('İade olarak kapat', 'Close as return');
  String get reasonAddressNotFound => _t('Adres bulunamadı', 'Address not found');
  String get reasonRecipientAbsent => _t('Alıcı adreste yok', 'Recipient not home');
  String get reasonRefused => _t('Alıcı teslim almadı', 'Recipient refused');
  String get reasonNoPayment => _t('Ödeme alınamadı', 'Payment not collected');
  String get reasonWrongAddress => _t('Adres hatalı', 'Wrong address');
  String get reasonNoAccess => _t('Siteye giriş izni yok', 'No site access');

  String get goToThisStop => _t('Bu durağa git', 'Go to this stop');
  String remainingStopsHint(int n) =>
      _t('$n durak kaldı', '$n stops left');
  String stopsCount(int n) => _t('$n durak', '$n stops');
  String get slideToDeliver => _t('Teslim etmek için kaydır', 'Slide to deliver');
  String get deliveryWindowLeft => _t('Teslim penceresi', 'Delivery window');
  String get callShort => _t('Ara', 'Call');
  String get routeShort => _t('Yol', 'Map');

  String get appearance => _t('Görünüm', 'Appearance');
  String get darkTheme => _t('Koyu tema', 'Dark theme');
  String get lightTheme => _t('Açık tema', 'Light theme');
  String get language => _t('Dil', 'Language');
  String get languageTr => _t('Türkçe', 'Turkish');
  String get languageEn => _t('İngilizce', 'English');
  String get appSection => _t('Uygulama', 'App');
  String get barcodeBeep => _t('Sesli barkod onayı', 'Barcode beep');
  String get onBeep => _t('Açık · bip + titreşim', 'On · beep + haptic');
  String get off => _t('Kapalı', 'Off');
  String get newStopAlerts => _t('Yeni durak bildirimi', 'New stop alerts');
  String get onNotify => _t('Açık · titreşim + ses', 'On · haptic + sound');
  String get notifyDenied =>
      _t('Bildirim izni verilmedi.', 'Notification permission was denied.');
  String get notifyBlocked => _t(
    'Bildirim izni kapalı. Sistem ayarlarından aç.',
    'Notifications are blocked. Enable them in system settings.',
  );
  String get notifyNeedOs =>
      _t('İzin kapalı · Ayarlardan aç', 'Permission off · Open settings');
  String get openSettings => _t('Ayarlar', 'Settings');
  String get logout => _t('Çıkış yap', 'Sign out');
  String get logoutPanelBody => _t(
    'Panel oturumu da kapanacak. Tekrar giriş yapman gerekecek.',
    'The panel session will also close. You will need to sign in again.',
  );
  String get logoutBody => _t(
    'Oturumun kapatılacak, tekrar giriş yapman gerekecek.',
    'Your session will close and you will need to sign in again.',
  );
  String shiftCityHint(String district, String city, bool open) => open
      ? _t('$district / $city · açık', '$district / $city · open')
      : _t('$district / $city · yeni durak atanmaz', '$district / $city · no new stops');
  String get plate => _t('PLAKA', 'PLATE');

  String get statusDelivered => _t('Teslim', 'Delivered');
  String get statusFailed => _t('İade', 'Returned');
  String get statusQueued => _t('Kuyrukta', 'Queued');
  String get statusInProgress => _t('İşlemde', 'In progress');
  String get statusAssigned => _t('Bekliyor', 'Waiting');
  String get statusCancelled => _t('İptal', 'Cancelled');

  String get kindDelivery => _t('Teslimat', 'Delivery');
  String get kindPickup => _t('Alım', 'Pickup');
  String get kindDocument => _t('Evrak', 'Document');

  String get weekdayMon => _t('Pzt', 'Mon');
  String get weekdayTue => _t('Sal', 'Tue');
  String get weekdayWed => _t('Çar', 'Wed');
  String get weekdayThu => _t('Per', 'Thu');
  String get weekdayFri => _t('Cum', 'Fri');
  String get weekdaySat => _t('Cmt', 'Sat');
  String get weekdaySun => _t('Paz', 'Sun');

  String get nfcRead => _t('NFC ile oku', 'Read with NFC');
  String get verified => _t('Doğrulandı', 'Verified');
  String get calling => _t('Aranıyor…', 'Calling…');
  String get openingDirections => _t('Yol tarifi açılıyor…', 'Opening directions…');
  String get kycTitle => _t('Kimlik doğrulama', 'Identity check');
  String get kycLead => _t(
    'Belgeyi seç, fotoğrafını çek, çipi oku.',
    'Pick a document, take a photo, then read the chip.',
  );
  String get kycDocsKicker => _t('BELGE', 'DOCUMENT');
  String get kycPhotoKicker => _t('FOTOĞRAF', 'PHOTO');
  String get kycChipKicker => _t('ÇİP', 'CHIP');
  String get kycMrzKicker => _t('MRZ', 'MRZ');
  String get kycPhotoHint =>
      _t('Belgeyi çerçeveye al', 'Frame the document');
  String get kycPhotoTaken => _t('Fotoğraf alındı', 'Photo captured');
  String get kycScanning => _t('Çip okunuyor…', 'Reading chip…');
  String kycDocAt(int i) => switch (i) {
    0 => _t('Yeni kimlik ön yüz', 'New ID front'),
    1 => _t('Yeni kimlik arka yüz', 'New ID back'),
    2 => _t('Eski kimlik', 'Old ID'),
    3 => _t('Pasaport', 'Passport'),
    4 => _t('Yabancı kimlik', 'Foreign ID'),
    _ => '',
  };

  String get notifNewStop => _t('Yeni durak atandı', 'New stop assigned');
  String get notifCustody => _t('Zimmet onaylandı', 'Custody confirmed');
  String get notifCustodyTaken => _t('Zimmet size geçti', 'Custody transferred to you');
  String get notifSyncFail => _t('Gönderim başarısız', 'Send failed');
  String get notifBonus => _t('Prim güncellendi', 'Bonus updated');
  String get notifShift => _t('Vardiya hatırlatması', 'Shift reminder');
  String get notifShiftBody =>
      _t('Yarın 09:00 vardiyası atanmıştır.', 'A 09:00 shift is assigned tomorrow.');
  String get notifStopPulled => _t('Durak çekildi', 'Stop pulled');
  String get notifStopCancelled => _t('Durak iptal', 'Stop cancelled');
  String get notifSlaRisk => _t('SLA riskte', 'SLA at risk');
  String get notifSlaExtended => _t('SLA uzatıldı', 'SLA extended');
  String get yesterday => _t('Dün', 'Yesterday');

  String get proof => _t('Kanıt', 'Proof');
  String get photoFull => _t('Fotoğraf', 'Photo');
  String get recipientName => _t('Alıcı', 'Recipient');
  String get date => _t('Tarih', 'Date');
  String get signedOnField =>
      _t('İmza kaydı · Sahada imzalandı', 'Signed on site');
  String get otpSentToRecipient => _t(
    'Kod, alıcının telefonuna SMS ile gönderildi. Kodu görmeden teslim etme.',
    'The code was sent to the recipient by SMS. Do not deliver without seeing it.',
  );
  String get otpWillSend => _t(
    'Alıcının telefonuna tek kullanımlık bir kod göndereceğiz.',
    'We will send a one-time code to the recipient.',
  );
  String get resendCode => _t('Kod gelmedi mi? Yeniden gönder', 'No code? Send again');
  String get verifyWithId =>
      _t('Kod alınamıyor · kimlik ile doğrula', 'No code · verify with ID');
  String whoTook(String who) => _t('Kim aldı: $who', 'Received by: $who');
  String get sent => _t('Gönderildi', 'Sent');
  String get waitingOnDevice => _t('Cihazda bekliyor', 'Waiting on device');
  String get deliveryRecordSent =>
      _t('Teslim kaydı gönderildi.', 'Delivery record sent.');
  String get returnRecordSent =>
      _t('İade kaydı merkeze gönderildi.', 'Return record sent to the hub.');
  String get recordOnDevice => _t(
    'Kayıt cihazda. İnternet gelince gönderilecek.',
    'Saved on the device. It will send when you are online.',
  );
  String get extraNote => _t('EK NOT', 'NOTE');
  String get emailOrPhone => _t('E-posta veya telefon', 'Email or phone');
  String get password => _t('Şifre', 'Password');
  String get openProfile => _t('Profili aç', 'Open profile');
  String get fieldAppVersion =>
      _t('v1.0.0 · JetLogi Saha', 'v1.0.0 · JetLogi Field');
  String get demoCodesHint =>
      _t('Giriş 123456  ·  Teslim 482913', 'Login 123456  ·  Delivery 482913');
  String get storageLockedTitle =>
      _t('Güvenli depo açılamadı', 'Secure storage could not be opened');
  String get storageLockedBody => _t(
    'Saha verisi bu cihazda şifrelenemiyor. Cihazı yeniden başlatıp tekrar deneyin. Sorun sürerse operasyona bildirin.',
    'Field data cannot be encrypted on this device. Restart the device and try again. If it continues, contact operations.',
  );
  String get otpMismatchAsk =>
      _t('Kod eşleşmedi. Alıcıya yeniden sorun.', 'Code did not match. Ask the recipient again.');
  String get noNotifBody =>
      _t('Atama ve iptaller burada görünür.', 'Assignments and cancellations show up here.');
  String get ticketsEmptyBody =>
      _t('Konu ve açıklama yazıp gönder.', 'Write a subject and a note, then send.');
  String get categoryCaps => _t('KATEGORİ', 'CATEGORY');
  String get emptyOpenTitle =>
      _t('Bekleyen görev yok — hepsi tamam.', 'No open stops — all done.');
  String get emptyOpenBody =>
      _t('Yeni durak gelince burada görünür.', 'New stops will appear here.');
  String get emptyDeliveredTitle =>
      _t('Henüz teslimat yapılmadı.', 'No deliveries yet.');
  String get emptyDeliveredBody =>
      _t('Teslim ettiğin duraklar bu sekmede.', 'Delivered stops show in this tab.');
  String get emptyReturnTitle => _t('İade kaydı yok.', 'No returns.');
  String get emptyReturnBody =>
      _t('İade ve iptaller burada durur.', 'Returns and cancellations stay here.');
  String get codeShort => _t('Kod', 'Code');
  String get noOpenTasksLeft => _t(
    'Açık göreviniz kalmadı — yeni bir durak atandığında burada görünecek.',
    'No open tasks left — a new stop will show up here.',
  );
  String slaLeft(String label) => _t('$label kaldı', '$label left');
  String get askRecipient => _t('Alıcıdan istenecek', 'Ask the recipient');
  String get couldNotDeliverShort => _t('Teslim edilemedi', 'Could not deliver');
  String get userSection => _t('Kullanıcı', 'User');
  String get editFieldsHint =>
      _t('Her alanı ayrı ayrı düzenleyebilirsin.', 'You can edit each field separately.');
  String get phoneCaps => _t('TELEFON', 'PHONE');
  String get todayCaps => _t('BUGÜN', 'TODAY');
  String get weekly => _t('Haftalık', 'Weekly');
  String get bonuses => _t('Primler', 'Bonuses');
  String get monthlyFixed => _t('AYLIK SABİT', 'MONTHLY FIXED');
  String get agencyMonthly =>
      _t('ACENTA · AYLIK KARŞILIK', 'AGENCY · MONTHLY EQUIV.');
  String get agencyPricingHint => _t(
    'Fiyatlandırma acenta tarafından yönetilir.',
    'Pricing is managed by the agency.',
  );
  String get fixedMonthlyHint => _t(
    'Sabit aylık ücretlisiniz, teslimat başına tutar gösterilmez.',
    'You are on a fixed monthly rate. Per-delivery amounts are hidden.',
  );
  String get pickDepot => _t('Teslim alacağın depoyu seç.', 'Pick the depot you will collect from.');
  String get depotShipments => _t('Bu depodaki gönderiler', 'Shipments at this depot');
  String get backgroundSend => _t('Otomatik gönderim', 'Auto send');
  String get workerOn => _t('Hat açık — kuyruk kendi gider', 'Line open — queue sends itself');
  String get workerOff => _t('Hat kapalı — sen gönderirsin', 'Line closed — you send');
  String get queueEmptyAllSent =>
      _t('Kuyruk boş, tüm kayıtlar merkeze iletildi.', 'Queue is empty. All records were sent.');
  String get hubLine => _t('Merkez hattı', 'Hub line');
  String get hubLinked => _t('Bağlı', 'Linked');
  String get hubOffline => _t('Hat yok', 'No line');
  String get hubFlushing => _t('Kuyruk merkeze gidiyor', 'Queue going to hub');
  String get hubQueuedOnPhone =>
      _t('Kayıtlar telefonda bekliyor', 'Records waiting on the phone');
  String hubQueuedCount(int n) =>
      _t('$n kayıt sırada', '$n records in line');
  String get phoneEnd => _t('Telefon', 'Phone');
  String get hubEnd => _t('Merkez', 'Hub');
  String get inLine => _t('Sırada', 'In line');
  String get queuedRecord => _t('Kayıt', 'Record');
  String get shiftRecord => _t('Vardiya', 'Shift');
  String get syncShiftStart => _t('Vardiya açıldı', 'Shift started');
  String get syncShiftEnd => _t('Vardiya kapandı', 'Shift ended');
  String get syncCustodyHandover => _t('Zimmet teslimi', 'Custody handover');
  String get syncSupportTicket => _t('Destek kaydı', 'Support ticket');
  String get syncAccepted => _t('Görevi aldı', 'Accepted the stop');
  String get syncEnRoute => _t('Yola çıktı', 'On the way');
  String get syncArrived => _t('Kapıya vardı', 'Arrived at the door');
  String get syncStarted => _t('Teslime başladı', 'Started the delivery');
  String get syncFailedStop => _t('Teslim edilemedi', 'Could not deliver');
  String get syncDelivered => _t('Teslim edildi', 'Delivered');
  String get syncStepGeneric => _t('Teslim adımı', 'Delivery step');
  String get syncStepArrive => _t('Varış kontrolü', 'Arrival check');
  String get syncStepBarcode => _t('Barkod okutuldu', 'Barcode scanned');
  String get syncStepWho => _t('Teslim alan seçildi', 'Recipient chosen');
  String get syncStepPhoto => _t('Teslim fotoğrafı', 'Delivery photo');
  String get syncStepSign => _t('İmza alındı', 'Signature taken');
  String get syncStepOtp => _t('Teslim kodu', 'Delivery code');
  String get syncStepAbsentNote => _t('Alıcı yok notu', 'Recipient-absent note');
  String get syncStepDoorPhoto => _t('Kapı fotoğrafı', 'Door photo');
  String get syncStepAddressPhoto => _t('Adres fotoğrafı', 'Address photo');
  String get syncStepRefuse => _t('Teslim reddi', 'Delivery refused');

  String syncTransitionOf(String to) => switch (to) {
    'ACCEPTED' => syncAccepted,
    'EN_ROUTE' => syncEnRoute,
    'ARRIVED' => syncArrived,
    'IN_PROGRESS' => syncStarted,
    'FAILED' => syncFailedStop,
    _ => syncStarted,
  };

  String syncOutcomeOf(String code) => switch (code) {
    'DELIVERED' => syncDelivered,
    'RECIPIENT_ABSENT' || 'ALICI_YOK' => reasonRecipientAbsent,
    'ADDRESS_NOT_FOUND' => reasonAddressNotFound,
    'REFUSED' => reasonRefused,
    'TESLIM_EDILEMEDI' || 'FAILED' => syncFailedStop,
    _ => code.isEmpty ? queuedRecord : code,
  };

  String syncStepOf(String key) => switch (key) {
    'varis_kontrolu' => syncStepArrive,
    'barkod_okut' => syncStepBarcode,
    'alici_kim' => syncStepWho,
    'teslim_fotografi' => syncStepPhoto,
    'alici_imza' => syncStepSign,
    'otp_dogrula' => syncStepOtp,
    'yok_notu' => syncStepAbsentNote,
    'yok_kanit_fotografi' => syncStepDoorPhoto,
    'adres_kanit_fotografi' => syncStepAddressPhoto,
    'ret_nedeni' => syncStepRefuse,
    _ => syncStepGeneric,
  };
  String get failed => _t('Başarısız', 'Failed');
  String get pickDocType =>
      _t('Doğrulanacak belge türünü seç.', 'Choose the document type to verify.');
  String get chipRead => _t('Çip okundu', 'Chip read');
  String get nfcReady => _t('NFC hazır', 'NFC ready');
  String get mrzVerified =>
      _t('MRZ ile şifre çözüldü · doğrulandı', 'Decrypted with MRZ · verified');
  String get holdIdBack =>
      _t('Kimliği telefonun arkasına yaklaştır', 'Hold the ID to the back of the phone');
  String get docNo => _t('BELGE NO', 'DOC NO');
  String get dobYymmdd => _t('DOĞUM TARİHİ (YYMMDD)', 'DATE OF BIRTH (YYMMDD)');
  String itemsWithRef(int n, String? ref) => ref == null
      ? itemsCount(n)
      : _t('$n kalem · $ref', '$n items · $ref');
  String listSummary(int total, int open, String? km) => km == null
      ? _t('$total durak · $open açık', '$total stops · $open open')
      : _t('$total durak · $open açık · $km km', '$total stops · $open open · $km km');

  String weekdayAt(int i) => switch (i) {
    0 => weekdayMon,
    1 => weekdayTue,
    2 => weekdayWed,
    3 => weekdayThu,
    4 => weekdayFri,
    5 => weekdaySat,
    _ => weekdaySun,
  };

  String failReasonOf(String r) => switch (r) {
    'Adres bulunamadı' => reasonAddressNotFound,
    'Alıcı adreste yok' => reasonRecipientAbsent,
    'Alıcı teslim almadı' => reasonRefused,
    'Ödeme alınamadı' => reasonNoPayment,
    'Adres hatalı' => reasonWrongAddress,
    'Siteye giriş izni yok' => reasonNoAccess,
    _ => r,
  };

  String categoryOf(String code) => switch (code) {
    'APP_ISSUE' => appSection,
    'ADDRESS_PROBLEM' => _t('Adres', 'Address'),
    'RECIPIENT_UNREACHABLE' =>
      _t('Alıcıya ulaşılamıyor', 'Recipient unreachable'),
    'VEHICLE' => _t('Araç', 'Vehicle'),
    'ACCIDENT' => _t('Kaza', 'Accident'),
    'SECURITY' => _t('Güvenlik', 'Security'),
    'PAYMENT' => _t('Ödeme', 'Payment'),
    'OTHER' => _t('Diğer', 'Other'),
    _ => code,
  };

  String statusOf(TaskStatus s) => switch (s) {
    TaskStatus.delivered => statusDelivered,
    TaskStatus.failed => statusFailed,
    TaskStatus.queued => statusQueued,
    TaskStatus.inProgress => statusInProgress,
    TaskStatus.assigned => statusAssigned,
    TaskStatus.cancelled => statusCancelled,
  };

  String kindOf(TaskKind k) => switch (k) {
    TaskKind.delivery => kindDelivery,
    TaskKind.pickup => kindPickup,
    TaskKind.document => kindDocument,
  };

  String notifTitle(String title) => switch (title) {
    'Yeni durak atandı' => notifNewStop,
    'Zimmet onaylandı' => notifCustody,
    'Zimmet size geçti' => notifCustodyTaken,
    'Gönderim başarısız' => notifSyncFail,
    'Prim güncellendi' => notifBonus,
    'Vardiya hatırlatması' => notifShift,
    'Durak çekildi' => notifStopPulled,
    'Durak iptal' => notifStopCancelled,
    'SLA riskte' => notifSlaRisk,
    'SLA uzatıldı' => notifSlaExtended,
    _ => title,
  };
}

class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.l10n, required super.child});

  final L10n l10n;

  @override
  bool updateShouldNotify(L10nScope oldWidget) => oldWidget.l10n.code != l10n.code;
}

extension L10nX on BuildContext {
  L10n get l10n => L10n.of(this);
}
