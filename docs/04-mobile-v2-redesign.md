# Mobile v2 redesign — 2026-09-01

Uygulama: `apps/mobile` (Flutter). Kaynak: kullanıcının Claude Design'da ürettirdiği "JetLogi Kurye v2" canvas'ı (`claude.ai/design/p/1e8af045-0373-484e-ae35-476a2796fbf9`) + canvas'ın kendi sohbet geçmişindeki revizyonlar. Tam plan: `~/.claude/plans/quizzical-fluttering-iverson.md`.

## Yapılanlar

### Tasarım sistemi (`lib/theme.dart`, `lib/widgets.dart`)
- Koyu `#0C0C0F` / açık `#F4F3F0` gerçek çift tema — `Dg` sınıfının renk alanları `static Color get`, `Dg.dark` bayrağı `app.dart`'ta `session.darkModeUi`'den set ediliyor (Ayarlar'daki koyu/açık anahtarı artık gerçekten çalışıyor).
- Mor gradyan birincil eylem `#8B6BF0→#5B3FBF` (`Dg.primaryGradient`), sage/sand/clay durum renkleri.
- `StatusChip`: dolgulu rozet yerine 6px nokta + nötr metin. `DgCard`: çerçevesiz, katmanlı gölge + üst kenarda 1px ışık.
- Radius skalası: telefon 46 / kart 28 / buton 18 / çip 13.
- Geist + Geist Mono fontları eklendi (`assets/fonts/`, Vercel'in açık kaynak reposundan).
- Tüm Material `Icons.*` kullanımı `lucide_icons_flutter` paketiyle `LucideIcons.*`'a çevrildi (~60 ikon, 15 dosya).

### IA / navigasyon değişikliği
- Alt nav: **Ana sayfa / Rota / Tara / Bildirim / Menü** (eskiden: Ana sayfa/Menü/Dağıtım/Bildirim/Profil).
- **Profil artık sekme değil** — Menü ekranının üst profil kartından açılıyor.
- **Tara**: yeni sekme, kurye/şube zimmet tarama kısayolu (canvas'ta referansı yok, menu'deki mevcut akışın kısayolu olarak eklendi).
- **Rota** sekmesi: liste görünümü + sağ üstteki harita ikonuyla açılan dikey zaman çizelgesi (`RouteScreen`) — eskiden ayrı ayrı erişilen iki ekrandı.

### Ekran bazlı değişiklikler
- **Giriş** (`activation_screen.dart`): mor gradyan zemin + ışık halesi + perspektif ağ (`HeroBackground`), ortada büyük logo kartı, alt sabit cam sheet, "Bu cihazı hatırla", "Doğrulama kodu gönder".
- **Ana sayfa** (`home_screen.dart`): header artık avatar+isim+konum (sol) + bildirim/arama ikonları (sağ); vardiya kartında Teslim/Mesafe pilleri; "Sıradaki durak" bölümü haritalı ETA rozeti + Aralık/Zimmet/Teslim kodu pilleri + "Yol tarifi" butonu.
- **Rota** (`list_screen.dart` + `shell_screen.dart`'taki `RouteScreen`): numaralı rozet + durum + bilgi pilleri; dikey zaman çizelgesinde aktif durak tam mor kart + "Bu durağa git" CTA'sı, teslim edilenler yeşil tik, son durak bayrak ikonu.
- **Görev detayı** (`task_detail_screen.dart`): birleşik ETA rozeti, Zimmet/Teslim penceresi/Teslim kodu ikonlu bilgi kartları, yeni "Foto" aksiyon butonu.
- **Sihirbaz** (`wizard_screen.dart`): her adımda başlık + "Adım X/3" + ilerleme çubuğu; Teslim kodu adımında mor kart + yeniden gönder/kimlik doğrulama satırları; İmza adımında Gönderi no/Alıcı/Tarih bilgi satırları + "İmza kaydı" durumu.
- **Menü** (`menu_screen.dart`): renkli kart grid'i yerine profil özet kartı (avatar, plaka, teslim/açık/iade istatistikleri) + düz liste satırları.
- Bildirim/Senkron/Zimmet ekranları canvas'ta referansı olmadığı için elle yeniden tasarlanmadı — ortak `DgCard`/`StatusChip`/`Dg.*` bileşenlerini kullandıkları için yeni temayı otomatik aldılar.

### Kapıda ödeme (COD) tamamen kaldırıldı
Canvas'ın kendi sohbet geçmişinde bulunan bir revizyon: kurye artık kapıda ödeme almıyor. `task.cod` alanı modelde kaldı (API uyumluluğu için) ama hiçbir yerde render edilmiyor. `Courier.canSeePricing` / `CourierAffiliation` / `CompensationType` **kaldırılmadı** — bunlar kuryenin kendi kazanç görünürlüğünü kontrol ediyor, COD'dan ayrı bir konu.

### Veri modeli (`lib/models.dart`)
`DeliveryTask`'a eklendi: `custodyCount`/`custodyRef` (zimmet), `slaMinutesLeft`/`slaLabel` (teslim penceresi), `signed`, `groupKey` (aynı-adres gruplama — alan var, UI mantığı yok).

### Geri düğmesi düzeltmeleri
`task_detail_screen.dart`, `profile_screen.dart`, `tara_screen.dart` — tema koyu moda geçince `Dg.ink` (temaya bağlı) kullanan sabit-koyu rozetler görünmez oldu; harita üstü rozetler artık temadan bağımsız sabit renk kullanıyor. Push edilebilen ama sekme köküyse de kullanılan ekranlarda (`Profil`, `Tara`) `Navigator.canPop(context)` ile koşullu geri düğmesi var.

## Doğrulama
`flutter analyze` temiz, `flutter test` 18/18 geçiyor (birkaç test yeniden isimlendirilen etiketler için güncellendi). Simulator'da (iPhone SE 3. nesil ve iPhone 15 Pro Max) tekrar tekrar hatasız açıldı.

## Yapılacaklar / bilinen eksikler
- Açık tema hiç canlı kontrol edilmedi (sadece koyu, yeni varsayılan) — canvas'ın "açık tema" sayfası bu oturumda görüntülenemedi (canvas kaydırmada içerik kayboluyordu).
- Aynı-adres gruplama kartı ("Aynı adres · N gönderi") — veri alanı (`groupKey`) var, UI'da hiç kullanılmıyor.
- Harita hâlâ açık renkli OSM tile'ları kullanıyor (koyulaştırılmadı) — overlay'ler bu yüzden temadan bağımsız sabit renkli yapıldı.
- `notif_screen.dart` / `sync_screen.dart` / `zimmet_screen.dart` / `fail_screen.dart` canvas referansı görülmeden sadece token bazlı güncellendi — elle tasarım geçişi yapılmadı.
- Rota/liste ekranından arama kutusu kaldırıldı (canvas referansında yoktu) — istenirse geri eklenebilir.
