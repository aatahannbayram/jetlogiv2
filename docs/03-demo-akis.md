# Yarınki görüşme — demo akışı (~8 dk)

Uygulama: `apps/mobile` · mock veri · canlı API yok  
Kurye kimliği canlı panelden: **Ruken Turhan · DGC-2026-9CF4875F · Güney/Denizli**

Başlatma:

```bash
cd apps/mobile
flutter run -d "iPhone 16 Pro"
```

Mac’te açılırsa telefon çerçevesinde görünür. **Görüşme demosuna atla** ile 30 saniyede listeye inersiniz; **Aktivasyonu göster** ile tam hikâyeyi anlatırsınız.

## Kodlar
- Kurye login OTP: `123456`
- Teslim OTP (ayrı havuz): `482913`

## Konuşma sırası

1. **Splash** — `GET /config`. Zorunlu güncelleme. `shiftFaceMatch=false`.
2. **Aktivasyon** — Cookie yok. Token + cihaz. Login OTP ≠ teslim OTP.
3. **İzinler** — Konum / kamera / bildirim. Vardiya bunlarsız açılmaz.
4. **Vardiya fotoğrafı** — Yalnız kanıt. Yüz eşleştirme yok (KVKK m.6).
5. **Dashboard** — Müsaitlik web’den `GET /v1/me/availability`. Pzt–Cum 09–18.
6. **Görev DGO-8841** — Maskeli ara (CPaaS), harici navigasyon.
7. **Sihirbaz** — `select` → fotoğraf → teslim OTP `482913`. Snapshot v3 kilitli.
8. **Edilemedi** — Offline kuyruk. Sağ üst **online** rozetine basınca outbox boşalır.
9. **Profil** — Web onboarding kimliği; başvuru web’de kalır.

## Söyleme
- Flutter kilit. Ayrı Fastify ürün değil; `/api/mobile/v1` aynı Next.js.
- Pilot 16 modül / ~4 ay. Bu demo o çekirdeğin dikey kesiti.
- Ruken reposu gelince mock düşer, token BFF bağlanır.

PDF master plan hâlâ: `~/Downloads/dijigoo-kurye-master-plan.pdf`
