# Bildirimler: Uygulama Arka Planda / Kapalıyken

## Yapılan İyileştirmeler

### 1. Backend (Cloud Functions)
- **Admin mesaj** ve **kullanıcı mesaj** payload'larına `notification_title` ve `notification_body` data alanları eklendi. Böylece arka planda gelen mesajda Flutter tarafı kendi bildirimini gösterebiliyor.
- Admin mesaj payload'ına `ttl: 86400000` (24 saat) eklendi; teslim süresi uzatıldı.

### 2. Arka plan handler (Flutter)
- **admin_deal**, **admin_message** ve **message** tipleri artık her zaman yerel bildirimle de gösteriliyor (sistem göstermese bile).
- Doğru kanal kullanılıyor: `admin_channel`, `admin_messages_channel`, `messages_channel`. Her biri arka planda oluşturuluyor.
- Admin mesaj için `data['title']` fallback eklendi.

### 3. Android native (MainActivity.kt)
- Uygulama **ilk açılmadan önce** üç bildirim kanalı oluşturuluyor: `admin_channel`, `admin_messages_channel`, `messages_channel`.
- Böylece uygulama **tamamen kapalıyken** gelen FCM bildirimleri, kanal bulunamadığı için kaybolmuyor; sistem bu kanallarla bildirimi gösterebiliyor.

## Davranış Özeti

| Uygulama durumu | Kim gösterir? |
|-----------------|----------------|
| **Ön planda** | Flutter `onMessage` + local notification |
| **Arka planda** | 1) Sistem (FCM notification payload) 2) Flutter background handler da local notification gösteriyor (yedek) |
| **Tamamen kapalı** | Sadece **sistem** (FCM notification payload). Kanal native’de oluşturulduğu için kanal kaynaklı kaybolma azalır. |

## Hâlâ Gelmezse Kontrol Listesi

1. **Cihaz ayarları:** Uygulama bildirimleri açık mı? (Ayarlar → Uygulamalar → FIRSATKOLİK → Bildirimler)
2. **Pil optimizasyonu:** Bazı cihazlarda “Pil tasarrufu” veya “Arka planda kısıtlama” FCM’i geciktirebilir. Uygulamayı optimizasyondan çıkarın.
3. **Google Play Services:** Güncel ve çalışıyor olmalı (FCM buna bağlı).
4. **Admin topic:** Admin kullanıcı uygulamayı en az bir kez açıp giriş yapmış olmalı; böylece `admin_deals` topic’ine abone olunur.
5. **FCM token:** Mesaj bildirimleri için kullanıcı dokümanında `fcmToken` kayıtlı olmalı (uygulama açıldığında kaydediliyor).

## Deploy

- **Functions:** `firebase deploy --only functions`
- **Uygulama:** Android için yeniden derleyip yükleyin (MainActivity ve Flutter değişiklikleri için).
