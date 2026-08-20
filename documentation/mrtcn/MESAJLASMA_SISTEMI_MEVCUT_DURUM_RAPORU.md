# 📬 FırsatKolik — Mesajlaşma Sistemi Kapsamlı Teknik Durum ve Mimari Analiz Raporu

**Rapor Tarihi:** 13 Ağustos 2026  
**Kapsam:** Dart / Flutter (Mobil & Web UI), Cloud Functions (Backend), Firebase Firestore (Veritabanı & Güvenlik Kuralları), Firebase Cloud Messaging (FCM Push Bildirimleri), Web Admin Paneli, Veri Senkronizasyonu ve Yaşam Döngüsü.

---

## 1. Giriş, Felsefe ve Genel Mimari Mantığı

### 1.1. Mesajlaşma Sisteminin Felsefesi ve Amacı
FırsatKolik platformunda mesajlaşma altyapısı, fırsat paylaşan topluluk üyeleri (alıcılar, satıcılar ve fırsat avcıları) arasında doğrudan ve güvenli bir iletişim kanalı kurmak; aynı zamanda sistem yöneticileri ile kullanıcılar arasında resmi ve tek yönlü bilgilendirme/destek trafiğini yürütmek üzere kurgulanmıştır.

Sistem temelde **3 ana mesajlaşma katmanından** oluşur:
1. **Kullanıcılar Arası Birebir Sohbet (P2P User-to-User Chat):** İki üyenin fırsatlar, ürünler veya alışveriş detayları hakkında karşılıklı sohbet ettiği çift yönlü mesajlaşma kanalı.
2. **Yönetimden Kullanıcıya Resmi Bildirim/Mesaj (Admin-to-User Message):** Admin panelinden seçilen belirli bir kullanıcıya iletilen, yanıt verilemeyen (read-only), tek yönlü resmi bilgilendirme kanalı.
3. **Admin Moderasyon Mesajları (System/Moderation Alerts):** Küfür/uygunsuz içerik tespiti yapıldığında Cloud Functions tarafından otomatik oluşturulan ve web admin paneline düşen denetim mesajları.

---

## 2. Firestore Veri Modelleri ve Şema Yapısı

### 2.1. `messages` Koleksiyonu (Kullanıcılar Arası Mesajlar)
Kullanıcılar arası mesajlar düz (flat) bir Firestore koleksiyonunda (`messages/{messageId}`) tutulur. Konuşmalar (thread) ayrı bir koleksiyon olarak saklanmaz; mesaj dokümanlarının `senderId` ve `receiverId` alanları üzerinden istemci tarafında dinamik olarak gruplanır.

```json
// messages/{messageId}
{
  "senderId": "UID_KULLANICI_A",
  "senderName": "Ahmet Yılmaz",
  "senderImageUrl": "https://.../avatar_a.jpg",
  "receiverId": "UID_KULLANICI_B",
  "receiverName": "Mehmet Demir",
  "receiverImageUrl": "https://.../avatar_b.jpg",
  "text": "Merhaba, paylaştığınız laptop fırsatı hangi mağazada geçerli?",
  "createdAt": "Timestamp (2026-08-13T10:00:00Z)",
  "isRead": false,
  "isReadByAdmin": false
}
```

#### Denormalizasyon Stratejisi:
- Mesaj dokümanlarında `senderName`, `senderImageUrl`, `receiverName` ve `receiverImageUrl` alanları performans ve hızlı UI render amacıyla denormalize (gömülü) olarak saklanır.
- Profil güncellemelerinde (`users/{userId}` değişikliğinde), `onUserUpdated` Cloud Function tetikleyicisi geçmiş tüm mesajlardaki, yorumlardaki ve paylaşılan fırsatlardaki (`postedByName` / `postedByAvatar`) isim ve görsel URL'lerini batch write ile senkronize eder.

---

### 2.2. `adminToUserMessages` Koleksiyonu (Admin -> Kullanıcı)
Admin panelinden veya sistem yöneticisi tarafından belirli bir kullanıcıya iletilen tek yönlü mesajlardır.

```json
// adminToUserMessages/{messageId}
{
  "id": "MSG_AUTO_ID",
  "userId": "TARGET_USER_UID",
  "adminId": "ADMIN_UID",
  "adminName": "FırsatKolik Yönetim",
  "title": "Hesap Doğrulama Bildirimi",
  "content": "Profiliniz başarıyla onaylandı.",
  "isRead": false,
  "createdAt": "Timestamp"
}
```

---

### 2.3. `adminMessages` Koleksiyonu (Moderasyon Logları)
Otomatik küfür ve kural ihlali algılandığında sistem tarafından admin paneline oluşturulan bildirim kayıtlarıdır.

```json
// adminMessages/{messageId}
{
  "id": "MSG_AUTO_ID",
  "type": "deal", // veya "comment"
  "userId": "AUTHOR_UID",
  "userName": "Kullanıcı Adı",
  "content": "İhlal içeren fırsat/yorum içeriği...",
  "dealId": "DEAL_ID",
  "commentId": null,
  "reason": "Uygunsuz içerik tespit edildi",
  "isRead": false,
  "createdAt": "Timestamp"
}
```

---

## 3. Güvenlik Kuralları (Firestore Security Rules)

[firestore.rules](file:///d:/firsatkolik/firestore.rules#L121-L168) dosyasındaki mesajlaşma yetkilendirme mantığı:

```javascript
// ========================================
// MESSAGES COLLECTION (User-to-User)
// ========================================
match /messages/{messageId} {
  // Sadece gönderen, alıcı veya admin okuyabilir
  allow read: if isAuthenticated() && 
              (resource.data.senderId == userId() || 
               resource.data.receiverId == userId() ||
               isAdmin());
  
  // Giriş yapmış ve engellenmemiş kullanıcı sadece kendi adına mesaj oluşturabilir
  allow create: if canWrite() && request.resource.data.senderId == userId();
  
  // Sadece alıcı mesajı okundu işaretleyebilir
  allow update: if isAuthenticated() && 
                resource.data.receiverId == userId();
  
  // Sadece gönderen veya admin silebilir
  allow delete: if isAuthenticated() && 
                (resource.data.senderId == userId() || isAdmin());
}

// ========================================
// ADMIN TO USER MESSAGES
// ========================================
match /adminToUserMessages/{messageId} {
  allow read: if isAuthenticated() && 
              (resource.data.userId == userId() || isAdmin());
  allow create: if isAdmin();
  allow update: if isAuthenticated() && 
                (resource.data.userId == userId() || isAdmin());
  allow delete: if isAuthenticated() && 
                (resource.data.userId == userId() || isAdmin());
}

// ========================================
// ADMIN MESSAGES (Moderasyon)
// ========================================
match /adminMessages/{messageId} {
  allow read, write: if isAdmin();
}
```

---

## 4. İndeksler (Firestore Indexes)

[firestore.indexes.json](file:///d:/firsatkolik/firestore.indexes.json#L69-L81) dosyasında mesajlar için tanımlı birleşik (composite) indeks:

```json
{
  "collectionGroup": "messages",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "receiverId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

---

## 5. Cloud Functions ve Backend Altyapısı

[functions/index.js](file:///d:/firsatkolik/functions/index.js) dosyasında mesajlaşma ile doğrudan ilişkili 4 adet tetikleyici ve fonksiyon yer almaktadır:

### 5.1. `onUserMessageCreated` (FCM Push Bildirim Tetikleyicisi)
- **Tetikleyici:** `messages/{messageId}` `.onCreate`
- **İşlev:**
  1. `senderId` ile `receiverId` aynı ise işlem yapmaz.
  2. `getUserDeviceTokens(receiverId)` ile alıcının `userDevices` koleksiyonundaki tüm aktif FCM token'larını çeker.
  3. `messages_channel_v3` Android bildirim kanalı ve APNs `USER_MESSAGE` kategorisi üzerinden yüksek öncelikli (`high` priority) push bildirimi gönderir.
  4. Gönderim başarısız olursa geçersiz token'ları `handleSendFailure` ile ayıklar.

### 5.2. `onAdminMessageCreated` (Admin Bildirimi Tetikleyicisi — Tek Sorumluluk Mimarisi)
- **Tetikleyici:** `adminToUserMessages/{messageId}` `.onCreate`
- **Mimari Prensip:** Tek Sorumluluk (Single Responsibility). Bu fonksiyon **sadece bildirim dokümanı oluşturur**, FCM push gönderimi yapmaz.
- **İşlev:**
  1. Alıcının `users/{userId}/notifications/admin_msg_{messageId}` dokümanına bildirim kaydı yazar.
  2. Doküman içerisine `senderId: 'admin'`, `senderName`, `messageId` gibi FCM push için gerekli ek alanları ekler.
  3. Bu kayıt `onNotificationCreated` birleşik bildirim motorunu tetikler; `pushMasterEnabled` denetlenerek FCM push bildirimi `admin_messages_channel_v3` kanalı ve `🛡️` emoji başlığıyla iletilir.
  4. Admin mesajları sessiz saatlere ve grup tercihlerine tabi **değildir** (resmi/acil nitelikli bildirimler).

### 5.3. `onUserUpdated` (Denormalize Profil Senkronizasyonu)
- **Tetikleyici:** `users/{userId}` `.onUpdate`
- **İşlev:**
  1. Kullanıcı kullanıcı adını (`username`) veya profil fotoğrafını (`profileImageUrl`) değiştirdiğinde tetiklenir.
  2. `messages` koleksiyonunda `senderId == userId` olan tüm dokümanların `senderName` ve `senderImageUrl` alanlarını günceller.
  3. `messages` koleksiyonunda `receiverId == userId` olan tüm dokümanların `receiverName` ve `receiverImageUrl` alanlarını günceller (Batch write, 400 operasyonda bir commit).

### 5.4. `onUserDeleted` (Hesap Silme Veri Temizliği)
- **Tetikleyici:** `functions.auth.user().onDelete`
- **İşlev:**
  1. Kullanıcı silindiğinde `messages` koleksiyonundaki gönderdiği (`senderId == userId`) ve aldığı (`receiverId == userId`) tüm mesaj dokümanlarını kalıcı olarak siler.

---

## 6. Mobil / Flutter İstemci Katmanı

### 6.1. Dart Veri Modelleri
- **`Message` ([lib/models/message.dart](file:///d:/firsatkolik/lib/models/message.dart)):**
  - Alanlar: `id`, `senderId`, `senderName`, `senderImageUrl`, `receiverId`, `receiverName`, `receiverImageUrl`, `text`, `createdAt`, `isRead`, `isReadByAdmin`, `isAdminMessage`.
  - Fabrika Metotları: `Message.fromFirestore(doc)` (kullanıcı mesajları) ve `Message.fromAdminFirestore(doc)` (admin mesajları tek modelde birleştirme).
  - Metotlar: `toFirestore()`, `copyWith(...)`.
- **`AdminToUserMessage` ([lib/models/admin_to_user_message.dart](file:///d:/firsatkolik/lib/models/admin_to_user_message.dart)):**
  - Alanlar: `id`, `userId`, `adminId`, `adminName`, `title`, `content`, `createdAt`, `isRead`.

---

### 6.2. Servis Katmanı
- **`MessageService` ([lib/services/message_service.dart](file:///d:/firsatkolik/lib/services/message_service.dart)):**
  - `sendMessage(senderId, receiverId, text)`: Gönderici ve alıcı profillerini anlık sorgular, `Message` nesnesi oluşturup Firestore `messages` koleksiyonuna ekler.
  - `getConversationStream(userId1, userId2)`: İki kullanıcı arasındaki mesajları çeken stream. *(Not: Mevcut koddaki teknik akış ve eksiklik aşağıda detaylandırılmıştır)*.
  - `markMessageAsRead(messageId)`: `messages/{id}` dokümanında `isRead: true` günceller.
  - `getUnreadMessageCount(userId)`: `receiverId == userId && isRead == false` sorgusu ile okunmamış mesaj sayısını döner.
  - `deleteUserMessage(messageId)`: Mesaj dokümanını siler.
  - `getAdminToUserMessagesStream(userId)`: Admin bildirimlerini listeler.
  - `getUnreadAdminToUserMessageCount(userId)`: Okunmamış admin mesajlarını sayar.
- **`FirestoreService` ([lib/services/firestore_service.dart](file:///d:/firsatkolik/lib/services/firestore_service.dart)):**
  - `getUserMessagesStream(userId)`: Kullanıcının gönderdiği (`senderId == userId`), aldığı (`receiverId == userId`) ve aldığı admin mesajlarını (`adminToUserMessages`) 3 ayrı Firestore stream'i olarak dinleyip tek bir reaktif stream'de birleştiren `StreamController` mimarisi.
- **`NotificationService` ([lib/services/notification_service.dart](file:///d:/firsatkolik/lib/services/notification_service.dart)):**
  - `messages_channel_v3` ve `admin_messages_channel_v3` kanallarını yönetir.
  - Gelen bildirim tıklandığında (`type == 'message'`), `_navigateToChat(senderId, senderName)` çağırarak doğrudan sohbet ekranına yönlendirir.

---

### 6.3. Kullanıcı Arayüzü (UI Screens & Navigation)

#### 1. `MessagesListScreen` ([lib/screens/messages_list_screen.dart](file:///d:/firsatkolik/lib/screens/messages_list_screen.dart)):
- **Konuşma Listesi:** Kullanıcının tüm gelen ve giden mesajlarını karşı kullanıcı bazında gruplar (`Map<String, Message> conversations`). Her kullanıcı ile olan en son mesajı ve tarihini gösterir.
- **Arama Çubuğu:** Mesaj metni veya kullanıcı adı üzerinden dinamik yerel filtreleme yapar.
- **Okunmamış Rozetleri:** Okunmamış mesajı olan sohbetleri renk vurgusu, kalın yazı tipi ve rozet noktası ile öne çıkarır.
- **Canlı Profil Senkronizasyonu:** Liste elemanları `users/{otherUserId}` dokümanını reaktif dinler, böylece karşı tarafın avatarı veya adı anlık güncellenir.
- **Sohbet Silme:** Uzun basıldığında (`onLongPress`) kullanıcı ile olan tüm mesajları Firestore'dan silmek için onay diyaloğu açar.

#### 2. `MessageScreen` ([lib/screens/message_screen.dart](file:///d:/firsatkolik/lib/screens/message_screen.dart)):
- **Sohbet Balonları:** Gönderen sağda (Primary renk), alıcı solda (Surface rengi) yer alır.
- **Okundu Bilgisi:** Gönderilen mesajlarda tek tık (`check_rounded`) veya çift tık (`done_all_rounded`) ikonları ile iletildi/okundu durumu gösterilir.
- **Otomatik Okundu İşaretleme:** Mesajlar yüklendiğinde `_markMessagesAsRead` fonksiyonu alıcı olunan tüm mesajları `isRead: true` yapar.
- **Tarih Ayraçları:** Gün değişimlerinde "Bugün", "Dün" veya tam tarih rozetleri yerleştirilir.
- **Admin Mesaj Modu:** `isAdminMessage: true` olduğunda alt kısımdaki mesaj yazma çubuğu gizlenir, yerine kilitli "Resmi Yönetici Bildirimi (Yanıt verilemez)" bilgisi gösterilir.

#### 3. Bildirim & Rozet Entegrasyonları:
- **`HomeScreen` Alt Gezinme Barı ([lib/screens/home_screen.dart](file:///d:/firsatkolik/lib/screens/home_screen.dart)):** "Profil" sekmesi üzerinde `_unreadMessageCount + _unreadAdminMessageCount` toplam rozetini dinamik olarak gösterir.
- **`ProfileScreen` Menüsü ([lib/screens/profile_screen.dart](file:///d:/firsatkolik/lib/screens/profile_screen.dart)):** Profil menüsündeki "Mesajlar" satırında okunmamış sayaç rozeti yer alır. Başka bir kullanıcının profili ziyaret edildiğinde `_OtherUserActionBarWidget` altında doğrudan "Mesaj" butonu bulunur.

---

## 7. Web & Admin Paneli Katmanı

[web/admin/app.js](file:///d:/firsatkolik/web/admin/app.js) ve [web/admin/index.html](file:///d:/firsatkolik/web/admin/index.html):
1. **Moderasyon Mesajları Tablosu (`#messagesView`):**
   - Firestore `adminMessages` koleksiyonunu `createdAt desc` sıralamasıyla canlı dinler (`onSnapshot`).
   - Küfür veya ihlal içeren fırsat/yorum içeriklerini, yazarı ve tespit nedenini listeler.
2. **Kullanıcıya Özel Admin Mesajı Gönderme Modalı (`#adminMessageModal`):**
   - Admin kullanıcı listesinden bir kullanıcı seçip "Mesaj Gönder" butonuna bastığında açılır.
   - Form gönderildiğinde `adminToUserMessages` koleksiyonuna başlık ve içerikle yeni kayıt yazar. Bu kayıt Cloud Functions `onAdminMessageCreated` fonksiyonunu tetikleyerek kullanıcıya anlık bildirim düşürür.

---

## 8. Uygulanan Düzeltmeler, Geliştirmeler ve Yeni UI/UX Mimarisi

Tüm kritik aksaklıklar çözülmüş ve talep edilen tüm UI/UX senaryoları mevcut mimariyle tam uyumlu olarak sisteme kazandırılmıştır:

### 🔔 1. Bildirim & Derin Bağlantı (Deep Link) & In-App Toast
- **In-App Toast/Banner ([lib/widgets/in_app_message_banner.dart](file:///d:/firsatkolik/lib/widgets/in_app_message_banner.dart)):** Uygulama açıkken başka bir ekrandayken mesaj veya admin mesajı geldiğinde ekranın üstünden kayarak inen şık bir toast gösterilir; tıklandığında sohbete yönlendirir, yukarı kaydırılarak kapatılabilir.
- **Admin Mesajı Yönlendirmesi ([notification_service.dart](file:///d:/firsatkolik/lib/services/notification_service.dart) & [admin_notifications_screen.dart](file:///d:/firsatkolik/lib/screens/admin_notifications_screen.dart)):** Admin panelinden kullanıcıya doğrudan mesaj gönderildiğinde, kullanıcı dışarıdan bildirime tıkladığında veya Bildirim Merkezi'ndeki admin mesajına dokunduğunda popup yerine doğrudan mesaj kutusundaki resmi **Admin Sohbet Odasına** (`MessageScreen(isAdminMessage: true)`) yönlendirilir.
- **Akıllı Bildirim Bastırma ([notification_service.dart](file:///d:/firsatkolik/lib/services/notification_service.dart)):** Kullanıcı zaten o kişiyle veya admin sohbet ekranındaysa (`activeChatUserId == senderId`), push ve in-app bildirimleri bastırılır; mesaj doğrudan akışa yansır.
- **Derin Bağlantı & Scroll-to-Bottom:** Dış bildirim tıklandığında sohbet açılır, otomatik olarak en son mesaja yumuşakça kaydırılır ve okunmamış mesajlar okunmuş işaretlenir.

---

### 💬 2. Sohbet Odası & Akış (Chat Room UX)
- **📌 Sticky / Pinned Fırsat Kartı ([lib/screens/message_screen.dart](file:///d:/firsatkolik/lib/screens/message_screen.dart)):** Fırsat detayından başlatılan sohbetlerde ekranın tepesine sabitlenen zengin kart (Görsel, Başlık, Fiyat, Mağaza ve Detaya Git). Fırsat silinmişse *"Bu fırsat yayından kaldırılmıştır"* uyarısı verir.
- **👋 Boş Sohbet Karşılama Kartı:** İlk defa mesajlaşırken avatar, kullanıcı adı, karşılama mesajı ve tek dokunuşla gönderilebilen hızlı başlangıç çipleri (*"Merhaba 👋"*, *"Hâlâ geçerli mi? 🛍️"*).
- **⚡ Optimistic UI:** Mesaj gönderildiği an beklemeden ekrana `🕒 Gönderiliyor` durumuyla eklenir, sunucuya iletildiğinde `✔️` olur. İnternet kesilirse `⚠️ Hata` gösterilir.
- **📝 Otomatik Büyüyen Metin Kutusu:** 1 satırdan 5 satıra kadar dikeyde akıcı büyüyen, ardından kendi içinde kayan ergonomik giriş çubuğu.
- **🔗 Rich Link Preview (Zengin Bağlantı Önizleme):** Mesaj içinde web bağlantısı geçtiğinde `LinkPreviewService` ile otomatik tespit edilip balonun altında görsel ve başlıkla tıklanabilir önizleme kartı render edilir.
- **💬 Yazıyor Göstergesi (Typing Indicator):** Karşı taraf yazarken `typingStatus` koleksiyonu üzerinden dinlenen animasyonlu 3 nokta bubble (*"Ahmet yazıyor..."*).
- **⬇️ "1 Yeni Mesaj ↓" Yüzen Butonu:** Kullanıcı yukarıdaki eski mesajları okurken yeni mesaj geldiğinde okuması bölünmez; sağ altta beliren rozetli floating buton ile istenirse en sona inilir.
- **🎛️ Mesaj Balonu Basılı Tutma Menüsü:** Metni Kopyala, Yanıtla (Alıntı yap), Benden Sil (Soft delete), Herkesten Sil (ilk 15 dakika içinde), Şikayet Et (`ReportDialog`).

---

### 📥 3. Gelen Kutusu (Inbox UI/UX)
- **📋 Listeleme Sıralaması:** En son mesajlaşılan sohbet her zaman en üstte (`lastMessageAt DESC`).
- **🔵 Okunmamış Vurgusu:** Kalın yazı tipi, hafif renkli kart arka planı ve canlı okunmamış sayaç rozeti (`badgeCount`).
- **↔️ Kaydırma Aksiyonları (Swipe / Dismissible):** Sohbet kartı sola kaydırıldığında Sil 🗑️, Sessize Al 🔕, Okundu Olarak İşaretle ✉️ seçenekleri.
- **🔒 Misafir (Guest) Kullanıcı Koruması:** Giriş yapmamış misafir kullanıcı mesajlar sekmesine veya fırsattaki mesaj butonuna bastığında `showGuestLoginBottomSheet` açılır.

---

### 🛡️ 4. Güvenlik, Engel & Hata Senaryoları
- **🚫 Kullanıcı Engelleme:** Bir kullanıcı engellendiğinde giriş alanı kapanır ve *"Bu kullanıcıyı engellediniz. [Engeli Kaldır]"* barı çıkar. Engellenen kişiden gelen mesajlar karşı tarafa iletilmez.
- **👤 Silinmiş Kullanıcılar:** Hesabını silmiş kullanıcılar sohbet listesinde *"Silinmiş Kullanıcı"* ve varsayılan gri avatar ile güvenle gösterilir.

---

## 9. Özet Tablo: Katmanlar ve Bileşen Matrisi (Güncel Durum)

| Katman | Dosya / Modül | Sorumluluk / İşlev | Durum |
| :--- | :--- | :--- | :--- |
| **Model** | [lib/models/message.dart](file:///d:/firsatkolik/lib/models/message.dart) | Fırsat kartı, yanıt/alıntı, soft delete ve optimistik durum alanları | ✅ Genişletildi & Kararlı |
| **Model** | [lib/models/admin_to_user_message.dart](file:///d:/firsatkolik/lib/models/admin_to_user_message.dart) | Admin resmi duyuru/mesaj modeli | ✅ Aktif & Kararlı |
| **Servis** | [lib/services/message_service.dart](file:///d:/firsatkolik/lib/services/message_service.dart) | Çift yönlü reaktif stream, typing, block, mute, soft delete, 15 dk geri alma | ✅ Zenginleştirildi |
| **Servis** | [lib/services/firestore_service.dart](file:///d:/firsatkolik/lib/services/firestore_service.dart) | 3'lü StreamController ile birleşik mesaj akışı ve chat yardımcıları | ✅ Aktif & Tam Uyumlu |
| **Bildirim** | [lib/widgets/in_app_message_banner.dart](file:///d:/firsatkolik/lib/widgets/in_app_message_banner.dart) | Uygulama açıkken üstten kayan modern In-App Toast/Banner | ✅ Yeni Eklendi |
| **Bildirim** | [lib/services/notification_service.dart](file:///d:/firsatkolik/lib/services/notification_service.dart) | `activeChatUserId` denetimi ve In-App Banner entegrasyonu | ✅ Güncellendi |
| **Mobil UI** | [lib/screens/messages_list_screen.dart](file:///d:/firsatkolik/lib/screens/messages_list_screen.dart) | Sayaç rozetleri, swipe silme/sessize alma, misafir koruması | ✅ Yenilendi |
| **Mobil UI** | [lib/screens/message_screen.dart](file:///d:/firsatkolik/lib/screens/message_screen.dart) | Pinned Fırsat Kartı, Optimistic UI, Link Preview, Typing, Alıntı, "Yeni Mesaj ↓" butonu | ✅ Eksiksiz Yenilendi |
| **Mobil UI** | [lib/screens/deal_detail_screen.dart](file:///d:/firsatkolik/lib/screens/deal_detail_screen.dart) | Fırsat sahibine tüm fırsat kartı verileriyle doğrudan mesaj başlatma | ✅ Entegre Edildi |
| **Güvenlik** | [firestore.rules](file:///d:/firsatkolik/firestore.rules) | `messages` (gönderen + alıcı silme izni), `adminToUserMessages`, `adminMessages` | ✅ Güvenli & Aktif |
