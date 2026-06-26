# Takip Bildirimleri - Cloud Function Kurulumu

## ✅ Yapılan Değişiklikler

### 1. Cloud Function Eklendi
`functions/index.js` dosyasına `sendFollowNotifications` fonksiyonu eklendi. Bu fonksiyon:
- Deal onaylandığında otomatik olarak tetiklenir
- Sadece kullanıcı tarafından paylaşılan deal'ler için çalışır (`isUserSubmitted: true`)
- Takip eden kullanıcıların `followersWithNotifications` listesini kontrol eder
- Her takipçiye FCM push notification gönderir

### 2. Flutter Kodunda Değişiklikler
- `lib/services/notification_service.dart`: `sendFollowNotification` fonksiyonu deprecated olarak işaretlendi (artık kullanılmıyor)
- `lib/screens/admin_screen.dart`: Takip bildirimi çağrısı kaldırıldı (Cloud Function otomatik yapıyor)
- `lib/screens/deal_detail_screen.dart`: Takip bildirimi çağrısı kaldırıldı (Cloud Function otomatik yapıyor)

## 📋 Deploy Adımları

### 1. Functions Klasörüne Git
```bash
cd functions
```

### 2. Gerekli Paketleri Yükle (Eğer yoksa)
```bash
npm install
```

### 3. Cloud Function'ı Deploy Et
```bash
firebase deploy --only functions
```

veya

```bash
npm run deploy
```

### 4. Deploy Sonrası Kontrol
Firebase Console'da Functions bölümünden deploy edilen fonksiyonları kontrol edin:
- `onDealCreated` - Yeni deal eklendiğinde
- `onDealUpdated` - Deal güncellendiğinde (onaylandığında)

## 🔍 Nasıl Çalışıyor?

1. **Deal Onaylama**: Admin bir deal'i onayladığında, Firestore'da `isApproved: true` olur
2. **Trigger Tetikleme**: `onDealUpdated` Cloud Function otomatik olarak tetiklenir
3. **Kontrol**: Function, deal'in `isUserSubmitted: true` ve `postedBy` alanlarını kontrol eder
4. **Takipçi Listesi**: Deal sahibinin `followersWithNotifications` listesini alır
5. **FCM Token'ları**: Her takipçinin FCM token'ını alır
6. **Bildirim Gönderimi**: Her takipçiye push notification gönderilir

## 📱 Bildirim İçeriği

- **Başlık**: `👤 [Kullanıcı Adı] Yeni Bir Fırsat Paylaştı`
- **İçerik**: Deal başlığı (max 50 karakter)
- **Kanal**: `follow_channel` (Android)
- **Veri**: `type: 'follow'`, `dealId`, `followingUserId`

## ⚠️ Önemli Notlar

1. **Cloud Function Deploy**: Bu özellik çalışması için Cloud Function'ın deploy edilmesi gerekir
2. **FCM Token**: Takipçilerin FCM token'ları olması gerekir (uygulama giriş yaptığında otomatik kaydedilir)
3. **Bildirim İzinleri**: Kullanıcıların bildirim izinlerinin açık olması gerekir
4. **Takip Durumu**: Kullanıcıların "Bildirim Al" butonunun açık olması gerekir

## 🧪 Test Etme

1. İki kullanıcı ile giriş yapın (A ve B)
2. Kullanıcı B, Kullanıcı A'yı takip etsin ve "Bildirim Al" butonunu açsın
3. Kullanıcı A bir fırsat paylaşsın
4. Admin deal'i onaylasın
5. Kullanıcı B'ye bildirim gelmeli

## 🔧 Sorun Giderme

### Bildirimler Gelmiyor?
1. Cloud Function deploy edilmiş mi kontrol edin
2. Firebase Console > Functions > Logs bölümünden logları kontrol edin
3. Takipçinin FCM token'ı var mı kontrol edin (Firestore > users > [userId] > fcmToken)
4. `followersWithNotifications` listesinde takipçi ID'si var mı kontrol edin

### Cloud Function Hatası?
Firebase Console > Functions > Logs bölümünden hata mesajlarını kontrol edin.






