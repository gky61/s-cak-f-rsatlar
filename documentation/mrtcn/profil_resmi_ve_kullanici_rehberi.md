# 📸 FırsatKolik - Profil Resmi ve Kullanıcı Bilgileri Master Referans Rehberi

> **Bu dokümanın amacı:** Proje genelinde profil fotoğraflarının, avatarların ve kullanıcı adlarının tanımlandığı, işlendiği, depolandığı, senkronize edildiği ve render edildiği **istisnasız tüm noktaları** kayıt altına almaktır. Profil resmi veya kullanıcı adı altyapısında herhangi bir değişiklik, yeni avatar ekleme veya görsel formatı güncellemesi yapılacağında bu doküman doğrudan referans alınmalıdır.

---

## 📑 İçindekiler
1. [Temel Mimari İlkeler ve Fallback Zinciri](#1-temel-mimari-ilkeler-ve-fallback-zinciri)
2. [Asset Dosyaları ve Yerel Avatarlar](#2-asset-dosyaları-ve-yerel-avatarlar)
3. [Veritabanı Şemaları ve Alan Eşleşmeleri (Firestore)](#3-veritabanı-şemaları-ve-alan-eşleşmeleri-firestore)
4. [Yardımcı Fonksiyonlar & Migrasyon Katmanı](#4-yardımcı-fonksiyonlar--migrasyon-katmanı)
5. [Mobil Uygulama (Flutter Dart) Bileşenleri](#5-mobil-uygulama-flutter-dart-bileşenleri)
   - [5.1. Veri Modelleri (Models)](#51-veri-modelleri-models)
   - [5.2. Servis Katmanı (Services)](#52-servis-katmanı-services)
   - [5.3. Ekranlar (Screens)](#53-ekranlar-screens)
   - [5.4. Bileşenler ve Kartlar (Widgets)](#54-bileşenler-ve-kartlar-widgets)
6. [Web Admin Paneli (`web/admin/app.js`)](#6-web-admin-paneli-webadminappjs)
7. [Cloud Functions Arka Plan Senkronizasyonu (`functions/index.js`)](#7-cloud-functions-arka-plan-senkronizasyonu-functionsindexjs)
8. [Gelecekteki Değişiklikler İçin Kontrol Listesi (Checklist)](#8-gelecekteki-değişiklikler-için-kontrol-listesi-checklist)

---

## 1. Temel Mimari İlkeler ve Fallback Zinciri

### 🔄 4 Kademeli Görsel Render Zinciri
Profil resimleri UI'da render edilirken aşağıdaki katı kural sırası işletilir:
```
1. Görsel Yolu Temizleme (migrateAssetPath):
   - `.jpg`, `.jpeg`, `.png` uzantıları otomatik `.webp` uzantısına normalize edilir.
   - Boş string veya null kontrolleri yapılır.

2. Yerel Asset Görseli (assets/ ile başlayan yollar):
   - `Image.asset(cleanUrl, fit: BoxFit.cover, errorBuilder: ...)`
   - Hata durumunda asla çökmez/taşmaz; `errorBuilder` devreye girerek harf veya `Icons.person` gösterir.

3. Uzak URL Görseli (http:// veya https:// ile başlayan yollar):
   - `CachedNetworkImage(imageUrl: cleanUrl, placeholder: ..., errorWidget: ...)`
   - Hızlı bellek ve disk önbelleklemesi yapılır. Hata durumunda `errorWidget` devreye girer.

4. Boş / Tanımsız / Hatalı Durum (Fallback):
   - Kullanıcının baş harfi (örn: `comment.userName[0].toUpperCase()`) veya temaya uygun şık arka planlı `Icons.person` ikonu çizilir.
```

### ⚡ Denormalizasyon ve Çift Yönlü Senkronizasyon
Firestore okuma maliyetlerini ve sayfa açılış gecikmelerini sıfıra indirmek amacıyla:
- Fırsatlar (`deals`), Yorumlar (`comments`) ve Mesajlar (`messages`) yazarın profil resmi ve kullanıcı adını kendi dokümanı üzerinde (**denormalize**) saklar.
- Kullanıcı profil resmini veya kullanıcı adını değiştirdiğinde `onUserUpdated` Cloud Function'ı arka planda otomatik olarak tüm bu dokümanları **batch update** ile günceller.
- Kullanıcı oturumu açıkken yapılan işlemler anında `CachedNetworkImage.evictFromCache` ile önbellekten temizlenir.

---

## 2. Asset Dosyaları ve Yerel Avatarlar

Yerel avatarlar doğrudan `assets/` klasöründe yer alır ve tamamı optimize `.webp` formatındadır:

| Dosya Yolu | Açıklama | Kullanım Yeri |
|---|---|---|
| `assets/kullanıcı pp.webp` | Erkek varsayılan profil avatarı | Profil Seçici, Kullanıcı Profili |
| `assets/kkpp.webp` | Kadın varsayılan profil avatarı | Profil Seçici, Kullanıcı Profili |
| `assets/botkolik.webp` | Botkolik otonom bot avatarı | Botkolik fırsat kartları, Botkolik profil sayfası, İletişim |
| `assets/logo.webp` | FırsatKolik marka logosu | Splash, Giriş, Bildirimler, Yönetim |

> **Önemli Kural:** Projeye yeni bir varsayılan profil resmi ekleneceğinde görsel `.webp` formatında kaydedilmeli, `pubspec.yaml` altına eklenmeli ve `ProfileScreen`'deki `profileImages` listesine tanımlanmalıdır.

---

## 3. Veritabanı Şemaları ve Alan Eşleşmeleri (Firestore)

| Koleksiyon / Alt Koleksiyon | Alan Adı | Tip | Açıklama |
|---|---|---|---|
| `users/{userId}` | `profileImageUrl` | `String` | Ana profil görseli URL'si veya `assets/...` yolu |
| `users/{userId}` | `photoURL` | `String` | Firebase Auth ile senkron tutulan yedek görsel alanı |
| `users/{userId}` | `username` | `String` | Kullanıcı adı |
| `users/{userId}` | `displayName` | `String` | Firebase Auth ile senkron görünen ad |
| `users/{userId}` | `nickname` | `String?` | İsteğe bağlı takma ad (Varsa öncelikli kullanılır) |
| `deals/{dealId}` | `postedByAvatar` | `String?` | Fırsat yazarının profil görseli yolu |
| `deals/{dealId}` | `postedByName` | `String?` | Fırsat yazarının kullanıcı adı |
| `deals/{dealId}` | `postedBy` | `String` | Fırsat yazarının `userId`'si |
| `deals/{dealId}` | `isUserSubmitted` | `bool` | Kullanıcı paylaşımı mı yoksa bot mu ayrımı |
| `deals/{dealId}/comments/{commentId}` | `userProfileImageUrl` | `String` | Yorum sahibinin profil görseli |
| `deals/{dealId}/comments/{commentId}` | `userName` | `String` | Yorum sahibinin kullanıcı adı |
| `deals/{dealId}/comments/{commentId}` | `userId` | `String` | Yorum sahibinin `userId`'si |
| `messages/{messageId}` | `senderImageUrl` | `String` | Mesajı gönderenin profil görseli |
| `messages/{messageId}` | `senderName` | `String` | Mesajı gönderenin kullanıcı adı |
| `messages/{messageId}` | `receiverImageUrl` | `String` | Mesajı alanın profil görseli |
| `messages/{messageId}` | `receiverName` | `String` | Mesajı alanın kullanıcı adı |

---

## 4. Yardımcı Fonksiyonlar & Migrasyon Katmanı

### 📁 `lib/utils/asset_path_migration.dart`
Tüm görsel yollarını standartlaştıran merkezi yardımcı fonksiyondur:
```dart
String migrateAssetPath(String? path) {
  if (path == null) return '';
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('assets/')) {
    return trimmed.replaceAllMapped(
      RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false),
      (match) => '.webp',
    );
  }
  return trimmed;
}
```
*Kullanım:* Herhangi bir model, servis veya UI bileşeni avatar URL'sini kullanmadan önce `migrateAssetPath(rawUrl)` çağrısı yapar.

---

## 5. Mobil Uygulama (Flutter Dart) Bileşenleri

### 5.1. Veri Modelleri (Models)

#### 📄 `lib/models/user.dart` (`AppUser`)
- **`fromFirestore`**: `profileImageUrl` ve `photoURL` fallback'lerini okur, `migrateAssetPath` ile korur. `username`, `displayName` ve `nickname` alanlarını çözer.
- **`displayName` Getter:** `(nickname.isNotEmpty ? nickname : (username.isNotEmpty ? username : 'Kullanıcı'))` hiyerarşisiyle çalışır.

#### 📄 `lib/models/deal.dart` (`Deal`)
- **`fromFirestore`**: `postedByAvatar` alanını `migrateAssetPath` ile normalize eder.
- **`isBotkolik` Getter:** `!isUserSubmitted || postedBy == 'botkolik' || postedBy.startsWith('telegram_') || postedBy.isEmpty` mantığı ile bot mu yoksa gerçek kullanıcı mı olduğunu belirler.

#### 📄 `lib/models/comment.dart` (`Comment`)
- **`fromFirestore`**: `userProfileImageUrl: migrateAssetPath(data['userProfileImageUrl'] ?? '')` ile yorum yazarının görselini parse eder.

#### 📄 `lib/models/message.dart` (`Message`)
- **`fromFirestore`**: `senderImageUrl` ve `receiverImageUrl` alanlarını `migrateAssetPath` süzgecinden geçirir.

---

### 5.2. Servis Katmanı (Services)

#### 📄 `lib/services/auth_service.dart`
- **`signUpWithEmail`**: Kullanıcı kayıt olurken `user.updateDisplayName(username)` çağırır ve Firestore'a `username` + `displayName` yazar.
- **`signInWithGoogle`**: Google girişinde `firebaseUser.photoURL` ve `displayName` değerlerini Firestore'daki `profileImageUrl`, `photoURL`, `username` ve `displayName` alanlarına eşitler.
- **`_createDefaultUser`**: Yeni kullanıcı oluştururken `profileImageUrl` ve `photoURL` alanlarını tam doldurur.

#### 📄 `lib/services/deal_service.dart`
- **`createDeal`**: Fırsat paylaşılırken yazarın `finalPosterName` ve `finalPosterAvatar` değerleri `null` veya boş string ise doğrudan `users/{userId}` dokümanından `username`/`displayName` ve `profileImageUrl`/`photoURL` çekip fırsata yazar.

#### 📄 `lib/services/comment_service.dart`
- **`addComment`**: Yorum kaydedilirken `userProfileImageUrl` parametresini `migrateAssetPath` ile normalize ederek Firestore'a yazar.

#### 📄 `lib/services/message_service.dart`
- **`sendMessage`**: Gönderici ve alıcının isim/avatar bilgilerini `users/{id}` dokümanlarından fallback zinciri ile (`username ?? displayName ?? nickname`) ve (`profileImageUrl ?? photoURL`) eksiksiz çeker.

---

### 5.3. Ekranlar (Screens)

#### 📄 `lib/screens/profile_screen.dart`
- **Ana Avatar Renderı:** `migrateAssetPath(user?.profileImageUrl)` ile `Builder` içerisinde `Image.asset` (`errorBuilder`) veya `CachedNetworkImage` (`errorWidget`) render eder.
- **`_showProfileImagePicker`**: Kullanıcıya `assets/kullanıcı pp.webp` ve `assets/kkpp.webp` avatarlarını sunan diyalog penceresi.
- **`_updateProfileImage`**: Seçilen görseli Firebase Auth (`user.updatePhotoURL`), Firestore (`profileImageUrl` ve `photoURL`), `CachedNetworkImage.evictFromCache` ve yerel State (`AppUser`) üzerinde anında günceller.
- **`_showEditUsernameDialog` & `_updateUsername`**: Kullanıcı adını Firebase Auth (`updateDisplayName`) ve Firestore (`username`, `nickname`) üzerinde günceller.

#### 📄 `lib/screens/deal_detail_screen.dart`
- **`_buildCompactDealAuthorCard`**: Fırsat detayında yer alan yazar avatarı, canlı online yeşil noktası, yazar kullanıcı adı, rozeti ve mesaj butonu (`otherUserImageUrl: profileImageUrl`).

#### 📄 `lib/screens/submit_deal_screen.dart`
- Yeni fırsat oluştururken oturum açmış kullanıcının `user.displayName` ve `user.photoURL` bilgilerini `migrateAssetPath` ile paketleyip `createDeal` servisine iletir.

#### 📄 `lib/screens/following_users_screen.dart`
- Takip edilen kullanıcılar listesinde her bir kullanıcının avatarını `migrateAssetPath` ve `errorBuilder` korumalı olarak listeler.

#### 📄 `lib/screens/messages_list_screen.dart`
- **`_buildAvatar`**: Mesajlar listesinde konuşulan kullanıcının profil resmini `migrateAssetPath` ve `errorBuilder` ile çizer.

#### 📄 `lib/screens/message_screen.dart`
- **AppBar Başlığı:** Konuşulan kişinin anlık canlı avatarı (`_otherUserStream`) ve profil linki.
- **`_sendMessage`**: Optimistic mesaj gönderiminde `senderImageUrl: migrateAssetPath(_authService.currentUser?.photoURL ?? '')` kullanımı.
- **`_buildAvatar`**: Sohbet içi mesaj baloncuklarındaki avatar gösterimi.

#### 📄 `lib/screens/botkolik_profile_screen.dart`
- Botkolik özel profil sayfasında `assets/botkolik.webp` avatarının ve canlı online göstergesinin renderı.

#### 📄 `lib/screens/admin_screen.dart`
- Mobil admin panelinde kullanıcılar sekmesinde `CircleAvatar` (`migrateAssetPath` + `onBackgroundImageError`) ile kullanıcı adı ve avatar gösterimi.

---

### 5.4. Bileşenler ve Kartlar (Widgets)

#### 📄 `lib/widgets/deal_card/vertical_deal_card.dart`
- Dikey fırsat kartı alt barında yazar avatarı gösterimi (`deal.isBotkolik` -> `assets/botkolik.webp`, `deal.isUserSubmitted` -> `postedByAvatar` + `migrateAssetPath` + `errorBuilder`).

#### 📄 `lib/widgets/deal_card/horizontal_deal_card.dart`
- Yatay fırsat kartında yazar avatarı ve kullanıcı profili yönlendirmesi.

#### 📄 `lib/widgets/comments_bottom_sheet.dart`
- Yorum satırlarında `CircleAvatar` (`migrateAssetPath` + `CachedNetworkImageProvider` / `AssetImage` + `onBackgroundImageError` + harf fallback).

#### 📄 `lib/widgets/in_app_message_banner.dart`
- **`_buildAvatar`**: Uygulama açıkken gelen yeni mesaj bildirim banner'ındaki avatar renderı.

#### 📄 `lib/widgets/deal_forward_bottom_sheet.dart`
- **`_buildAvatar`**: Fırsatı arkadaşına iletme modalındaki kullanıcı listesi avatarları.

#### 📄 `lib/widgets/admin_reports_list.dart`
- Şikayet edilen kullanıcı raporlarında `ProfileScreen(userId: report.reportedId)` profiline yönlendirme.

---

## 6. Web Admin Paneli (`web/admin/app.js`)

Web admin panelinde profil resimlerinin yönetimi için aşağıdaki fonksiyonlar ve bileşenler bulunur:

- **`cleanProfileImageUrl(url)`**: Yerel asset yollarını web uyumlu hale getirir ve `.jpg`/`.png` uzantılarını `.webp`'ye dönüştürür:
  ```javascript
  function cleanProfileImageUrl(url) {
      if (typeof url !== 'string') return '';
      const trimmed = url.trim();
      if (trimmed.startsWith('assets/')) {
          const webpPath = trimmed.replace(/\.(jpg|jpeg|png)$/i, '.webp');
          return '/' + webpPath;
      }
      return trimmed;
  }
  ```
- **UI-Avatars Fallback:** Web panelinde görseli olmayan kullanıcılar için otomatik `https://ui-avatars.com/api/?name=...` renkli harf avatarları üretilir.
- **Kullanıcılar Tablosu & Moderasyon:** Kullanıcı listesi, yorumlar ve şikayetlerde `cleanProfileImageUrl` ile güvenli render yapılır.

---

## 7. Cloud Functions Arka Plan Senkronizasyonu (`functions/index.js`)

### ⚡ `onUserUpdated` Trigger'ı
Kullanıcı profil resmini veya kullanıcı adını değiştirdiğinde çalışan merkezi arka plan fonksiyonudur.

```javascript
exports.onUserUpdated = functions.firestore
  .document('users/{userId}')
  .onUpdate(wrapTrigger('onUserUpdated', async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    const oldPhoto = before.profileImageUrl || before.photoURL || '';
    let newPhoto = after.profileImageUrl || after.photoURL || '';
    if (newPhoto.startsWith('assets/') && /\.(jpg|jpeg|png)$/i.test(newPhoto)) {
      newPhoto = newPhoto.replace(/\.(jpg|jpeg|png)$/i, '.webp');
    }
    const oldName = before.username || before.displayName || before.nickname || '';
    const newName = after.username || after.displayName || after.nickname || '';

    const photoChanged = oldPhoto !== newPhoto;
    const nameChanged = oldName !== newName;

    if (!photoChanged && !nameChanged) return null;

    // 1. Yorumları Senkronize Et (Collection Group: comments) -> userProfileImageUrl, userName
    // 2. Gönderilen Mesajları Senkronize Et (messages where senderId == userId) -> senderImageUrl, senderName
    // 3. Alınan Mesajları Senkronize Et (messages where receiverId == userId) -> receiverImageUrl, receiverName
    // 4. Paylaşılan Fırsatları Senkronize Et (deals where postedBy == userId) -> postedByAvatar, postedByName
  }));
```

---

## 8. Gelecekteki Değişiklikler İçin Kontrol Listesi (Checklist)

Projeye yeni bir profil avatarı eklemek veya görsel altyapısında değişiklik yapmak istediğinizde aşağıdaki kontrol listesini uygulayınız:

- [ ] **1. Asset Ekleme:** Yeni görseli `assets/` klasörüne `.webp` formatında ekleyin ve `pubspec.yaml` dosyasında tanımlı olduğundan emin olun.
- [ ] **2. Profil Seçici:** `lib/screens/profile_screen.dart` içerisindeki `profileImages` listesine yeni görsel yolunu ekleyin.
- [ ] **3. Migrasyon Kontrolü:** `lib/utils/asset_path_migration.dart` ve `web/admin/app.js` içerisindeki regex kurallarının yeni yolu doğru işlediğini doğrulayın.
- [ ] **4. Cloud Function:** `functions/index.js` içindeki `onUserUpdated` fonksiyonunun Dev ve Prod ortamlarında güncel ve deploy edilmiş olduğunu kontrol edin.
- [ ] **5. Test & Doğrulama:**
  - Yeni kayıt olan kullanıcının profil adı ve görselini test edin.
  - Profil resmi değiştirildiğinde fırsat kartlarında, yorumlarda ve mesajlarda anında güncellendiğini doğrulayın.
  - `flutter analyze` çalıştırarak 0 hata olduğunu teyit edin.
