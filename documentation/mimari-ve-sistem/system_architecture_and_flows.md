# 🏗️ FırsatKolik — Sistem Mimarisi ve Teknik Veri Akışları (System Architecture & Flows)

Bu doküman, FırsatKolik platformunun (Telegram Userbot, Gemini Yapay Zeka Servisleri, Firebase Altyapısı, Web Yönetim Paneli ve Flutter Mobil Uygulaması) uçtan uca teknik mimarisini, veri modellerini, iletişim protokollerini ve barındırma ortamlarını detaylandırmak amacıyla hazırlanmıştır.

---

## 🗺️ GENEL SİSTEM MİMARİSİ (TOPOLOGY)

Aşağıdaki şemada, sistemin tüm bileşenlerinin birbiriyle nasıl haberleştiği, hangi servislerin nerede barındırıldığı ve veri akış yönleri görselleştirilmiştir.

```mermaid
graph TD
    %% Bileşenler ve Barındırma Ortamları
    subgraph Telegram_Network [Telegram Ağı]
        Channels["Telegram Kanalları<br>(@firsatkolik_canli / @indirimkaplani)"]
    end

    subgraph Google_Cloud_Platform [Google Cloud Platform (GCP)]
        subgraph Compute_Engine_VM [GCP Compute Engine VM (e2-micro)]
            Bot["Telegram Userbot Container<br>(Node.js / GramJS / Always-on Docker)"]
        end
        subgraph Secret_Manager [Google Secret Manager]
            Secrets["API Anahtarları & Session String<br>(GEMINI_API_KEY, TELEGRAM_STRING_SESSION)"]
        end
        subgraph Gemini_API [Google Generative AI]
            Gemini["Gemini-2.5 / 2.0 Flash API<br>(Fırsat Analizi / Görsel & Metin Okuma)"]
        end
    end

    subgraph Firebase_Suite [Firebase Ecosystem]
        subgraph Firestore_DB [Cloud Firestore - Real-time DB]
            DealsCol["'deals' Koleksiyonu<br>(Fırsatlar)"]
            UsersCol["'users' Koleksiyonu<br>(FCM Tokenlar & Tercihler)"]
            KeywordsCol["'keywords' Koleksiyonu<br>(Takip Edilen Kelimeler)"]
        end
        subgraph Fire_Storage [Firebase Storage]
            Images["Fırsat Görselleri Bucket<br>(deals/ klasörü)"]
        end
        subgraph Fire_Hosting [Firebase Hosting]
            AdminPanel["Web Yönetim Paneli<br>(HTML / Vanilla JS)"]
        end
        subgraph Cloud_Functions [Firebase Cloud Functions]
            OnDealUpdated["onDealUpdated Trigger<br>(Onay & Bildirim Motoru)"]
            OnUserMsg["onUserMessageCreated Trigger<br>(Sohbet Bildirimi)"]
            ShortLinkFunc["resolveShortLink HTTP Trigger<br>(Affiliate Link Çözücü)"]
        end
    end

    subgraph Client_Devices [Son Kullanıcı Cihazları]
        MobileApp["FırsatKolik Flutter App<br>(Android / iOS Client)"]
        GMS["Google Play Services (GMS)<br>(FCM Push Gateway)"]
    end

    %% İletişim Akışları (Veri Yolları)
    Channels -->|MTProto Protokolü - Canlı Akış| Bot
    Secrets -.->|GCP IAM Güvenli Bağlantı| Bot
    Bot -->|Görsel/Metin Analiz İstekleri - JSON| Gemini
    Bot -->|Görsel JPEG Yükleme| Images
    Bot -->|Fırsat Belgesi Ekleme (isApproved: false)| DealsCol

    AdminPanel -->|Okuma (Gerçek Zamanlı Dinleyici - snapshots)| DealsCol
    AdminPanel -->|Yazma (isApproved: true)| DealsCol

    DealsCol -->|Firestore onCreate / onUpdate Triggers| Cloud_Functions
    Cloud_Functions -->|Kullanıcı Filtreleme & Arama| UsersCol
    Cloud_Functions -->|Anahtar Kelime Eşleştirme| KeywordsCol
    
    Cloud_Functions -->|FCM Push Gönderimi| GMS
    GMS -->|Sistem Düzeyinde Bildirim Teslimatı| MobileApp
    MobileApp -->|Firestore Okuma/Yazma| Firestore_DB
```

---

## 🔗 MANUEL YÖNETİM VE DENETLEME DİZİNİ (LINKS)

Sistem mimarisindeki bileşenlerin çalışma durumlarını, loglarını ve konfigürasyonlarını manuel olarak incelemek için aşağıdaki bağlantıları kullanabilirsiniz:

### 1. Firebase Konsolları (Veritabanı, Depolama, Bulut Fonksiyonları)
*   **DEV Firebase Konsolu:** [sicak-firsatlar-e6eae](https://console.firebase.google.com/project/sicak-firsatlar-e6eae)
    *   Firestore Verileri: [Firestore Viewer (DEV)](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/firestore)
    *   Cloud Functions Logları: [Functions Logs (DEV)](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions)
    *   Fırsat Görselleri: [Storage Viewer (DEV)](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/storage)
*   **PROD Firebase Konsolu:** [firsatkolik-prod-e6eae](https://console.firebase.google.com/project/firsatkolik-prod-e6eae)
    *   Firestore Verileri: [Firestore Viewer (PROD)](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/firestore)
    *   Cloud Functions Logları: [Functions Logs (PROD)](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/functions)
    *   Fırsat Görselleri: [Storage Viewer (PROD)](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/storage)

### 2. Google Cloud Konsolları (Telegram Botu & Güvenli Anahtarlar)
*   **GCP DEV Cloud Run Bot:** [Cloud Run Console (DEV)](https://console.cloud.google.com/run/detail/us-central1/telegram-bot/metrics?project=sicak-firsatlar-e6eae)
*   **GCP PROD Cloud Run Bot:** [Cloud Run Console (PROD)](https://console.cloud.google.com/run/detail/us-central1/telegram-bot/metrics?project=firsatkolik-prod-e6eae)
*   **GCP Secret Manager (PROD API Anahtarları):** [Secret Manager (PROD)](https://console.cloud.google.com/security/secret-manager?project=firsatkolik-prod-e6eae)

### 3. Web Yönetim (Admin) Panelleri
*   **DEV Admin Arayüzü:** [https://sicak-firsatlar-e6eae.web.app/admin/](https://sicak-firsatlar-e6eae.web.app/admin/)
*   **PROD Admin Arayüzü:** [https://firsatkolik-prod-e6eae.web.app/admin/](https://firsatkolik-prod-e6eae.web.app/admin/)

---

## ⚡ UÇTAN UCA TEKNİK İŞLEMCİ VE VERİ AKIŞLARI (DATA FLOWS)

### 1. Akış A: Telegram Link Paylaşımından Bildirim Gönderimine Kadar Yönetici Paneli Akışı
Bu senaryoda, yöneticinin Telegram kanalına attığı bir linkin yakalanıp yapay zekayla işlenmesi, onaylanması ve tüm kullanıcılara push bildirimi olarak gönderilmesi süreçleri adım adım işletilmektedir:

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Yönetici (Telegram)
    participant Channel as Telegram Kanalı
    participant Bot as Cloud Run Userbot
    participant Gemini as Gemini AI API
    participant Storage as Firebase Storage
    participant Firestore as Cloud Firestore
    participant WebPanel as Web Admin Panel
    participant CloudFunc as Firebase Cloud Functions
    participant FCM as Firebase Cloud Messaging
    participant Mobile as Flutter App (Kullanıcı)

    Admin->>Channel: Fırsat Linki Gönderir (Örn: Trendyol Linki + Fotoğraf)
    Channel->>Bot: MTProto Event (NewMessage) tetiklenir
    Note over Bot: cloud-run-bot/telegram_bot.js<br>Metin/buton linkleri taranır
    Bot->>Bot: downloadMedia() ile görseli sunucu hafızasına (Buffer) indirir
    
    rect rgb(230, 245, 255)
        Note right of Bot: HIZLANDIRILMIŞ PARALEL İŞLEM (Promise.all)
        Bot->>Storage: Görseli yükler (deals/{chatId}_{msgId}.jpg)
        Bot->>Gemini: Görsel + Mesaj Metnini gönderir (analyzeImageWithGemini)
    end
    
    Gemini-->>Bot: JSON Sonucu Döner (Ürün Adı, Fiyat, Kategori, Mağaza)
    Storage-->>Bot: Yükleme Tamam (ImageUrl oluşturulur)
    
    Bot->>Bot: cleanFallbackTitle() ve detectCategoryFromText() ile temizleme/kategori mapping yapar
    Bot->>Firestore: 'deals' koleksiyonuna yeni doküman yazar (isApproved: false)
    
    Note over WebPanel: Real-time Listener (db.collection('deals').where('isApproved','==',false))
    Firestore-->>WebPanel: Yeni Fırsatı Yöneticiye Gösterir (Deals List)
    
    Admin->>WebPanel: Fırsatı inceler ve "ONAYLA" butonuna basar
    WebPanel->>Firestore: Dokümanı günceller (isApproved: true)
    
    Firestore->>CloudFunc: document('deals/{dealId}').onUpdate tetiklenir (onDealUpdated)
    Note over CloudFunc: functions/index.js (onDealUpdated)<br>old.isApproved=false && new.isApproved=true kontrolü
    
    CloudFunc->>FCM: sendUserNotifications() -> Genel bildirim paketi hazırlar ve gönderir
    CloudFunc->>Firestore: Takipçi ve Anahtar Kelime eşleşmelerini sorgular
    CloudFunc->>FCM: sendKeywordNotifications() & sendFollowNotifications() gönderir
    
    FCM->>Mobile: Push Bildirimini İletir
    Note over Mobile: lib/services/notification_service.dart<br>_handleNotificationTap() ile mesajı yakalar
    Mobile->>Mobile: Navigator ile DealDetailScreen sayfasına yönlendirir
```

#### Teknik Detaylar (Kod Seviyesi):
1.  **7/24 Çalışma Altyapısı (Google Cloud Run):**
    *   Bot, Dockerize edilmiş bir Node.js uygulamasıdır ([Dockerfile](file:///d:/firsatkolik/cloud-run-bot/Dockerfile)).
    *   Cloud Run üzerinde `--no-cpu-throttling` (CPU her zaman açık) ve `--min-instances 1` `--max-instances 1` konfigürasyonuyla çalışır. Bu sayede HTTP isteği almasa dahi arka planda Telegram sunucularıyla kurduğu canlı soket (MTProto) bağlantısı kesilmez.
2.  **Mesaj Yakalama ve Doğrulama ([telegram_bot.js:L872](file:///d:/firsatkolik/cloud-run-bot/telegram_bot.js#L872)):**
    *   `GramJS` kütüphanesi kullanılarak Telegram oturumu `StringSession` aracılığıyla açılır (Session string'i Google Secret Manager'dan güvenli bir şekilde çekilir).
    *   `client.addEventHandler` ile belirtilen kanallardan gelen yeni mesajlar anlık yakalanır. Mesajda en az bir adet link (`getAllLinks`) yoksa işlem iptal edilir.
3.  **Hızlı Paralel İşlem Yapısı ([telegram_bot.js:L712](file:///d:/firsatkolik/cloud-run-bot/telegram_bot.js#L712)):**
    *   Sunucunun yanıt hızını artırmak ve veritabanı yazma süresini en aza indirmek için **Firebase Storage'a görsel yükleme** işlem ile **Gemini Vision modeline görsel analiz isteği gönderme** işlemi `Promise.all` yapısıyla asenkron olarak paralel koşturulur.
4.  **Gemini AI Analizi ve Normalizasyon ([telegram_bot.js:L160](file:///d:/firsatkolik/cloud-run-bot/telegram_bot.js#L160)):**
    *   Gemini API'sine (`gemini-1.5-flash`) görsel ve metin verilerek çıktının kesinlikle JSON formatında (`responseSchema`) dönmesi zorlanır.
    *   Yapay zekanın döndürdüğü kategori metni (`Kozmetik & Bakım` vb.) sistemin veri şemasındaki kategori ID'si ile (`kozmetik`) otomatik eşleştirilir (`categoryMap`).
5.  **Veritabanı Şeması ([telegram_bot.js:L821](file:///d:/firsatkolik/cloud-run-bot/telegram_bot.js#L821)):**
    *   Oluşturulan doküman Firestore'a `deals` koleksiyonuna şu ID formatı ile kaydedilir: `telegram_{chatInfo.id}_{messageId}`. Bu ID formatı, aynı Telegram mesajının mükerrer (duplicate) olarak tekrar kaydedilmesini engeller.
    *   Belgenin `isApproved` alanı `false` olarak ayarlanır.
6.  **Web Onay Mekanizması ([web/admin/app.js](file:///d:/firsatkolik/web/admin/app.js)):**
    *   Yönetici paneli Firestore real-time listener kullanarak onay bekleyen fırsatları anlık ekranda listeler.
    *   Yönetici "Onayla" dediğinde, Firestore belgesindeki `isApproved` alanı `true` olarak güncellenir.
7.  **Cloud Functions Tetiklenmesi & Bildirim Dağıtımı ([functions/index.js:L686](file:///d:/firsatkolik/functions/index.js#L686)):**
    *   `exports.onDealUpdated` tetikleyicisi çalışır.
    *   Eğer fırsat onaylandıysa `sendUserNotifications` metodu çağrılır ve `messaging().send()` aracılığıyla tüm cihazlara `general_deals` FCM başlığı (topic) üzerinden bildirim basılır.
    *   Aynı anda `sendKeywordNotifications` metodu çalışarak, fırsat başlığındaki kelimeleri takip eden (`keywords` koleksiyonundaki) kullanıcıların bireysel FCM token'larına kişiselleştirilmiş anlık push bildirimi gönderilir.

---

### 2. Akış B: Kullanıcıların Mobil Uygulama Üzerinden Fırsat Paylaşması Akışı
Kullanıcıların mobil uygulama içerisinden "Fırsat Paylaş" butonunu kullanarak topluluğa fırsat sunması akışıdır:

```mermaid
sequenceDiagram
    autonumber
    actor User as Kullanıcı
    participant App as Flutter Mobil Uygulama
    participant FireAuth as Firebase Authentication
    participant Firestore as Cloud Firestore
    participant Storage as Firebase Storage
    participant AdminPanel as Web Yönetim Paneli

    User->{App}: "Fırsat Paylaş" Ekranını Açar
    App->>FireAuth: Kullanıcı Giriş Durumu Kontrol Edilir (UID alınır)
    
    User->>App: Başlık, Fiyat, Mağaza ve Açıklama yazar, Görsel ekler
    Note over App: lib/services/link_preview_service.dart<br>Kullanıcı link yapıştırdıysa otomatik başlık/fiyat çeker
    
    App->>Storage: Görsel dosyasını yükler (deals/{uuid}.jpg)
    Storage-->>App: ImageUrl döner
    
    App->>Firestore: 'deals' koleksiyonuna belgeyi yazar (isApproved: false, isUserSubmitted: true)
    Note over Firestore: firestore.rules (Deals Security Rules)<br>Yazma izni kuralları çalışır (Giriş yapılmış olmalı)
    
    Note over AdminPanel: Real-time Listener (isApproved == false && isUserSubmitted == true)
    Firestore-->>AdminPanel: Kullanıcı paylaşımları sekmesinde listeler
```

#### Teknik Detaylar (Kod Seviyesi):
1.  **Link Önizleme ve Otomatik Doldurma ([link_preview_service.dart](file:///d:/firsatkolik/lib/services/link_preview_service.dart)):**
    *   Kullanıcı fırsat linkini yapıştırdığında, uygulama arka planda `LinkPreviewService`'i çalıştırır. Servis, hedeflenen web sayfasının HTML içeriğini çeker (`http.get`) ve OpenGraph meta etiketlerini (`og:title`, `og:image`, `og:description`) veya HTML etiketlerini parse ederek başlık, görsel ve fiyat alanlarını otomatik doldurur.
2.  **Veritabanı Güvenlik Kuralları ([firestore.rules](file:///d:/firsatkolik/firestore.rules)):**
    *   Mobil uygulamadan Firestore'a yapılan doğrudan yazma istekleri güvenlik kuralları tarafından denetlenir. Bir kullanıcının fırsat paylaşabilmesi için `request.auth != null` (giriş yapmış olması) ve oluşturduğu belgedeki `postedBy` alanının kendi `auth.uid` değeriyle eşleşmesi zorunludur.
    *   Yazılan belgede `isApproved` alanının varsayılan olarak kesinlikle `false` olması güvenlik kurallarıyla doğrulanır.

---

### 3. Akış C: Kullanıcılar Arası Gerçek Zamanlı Sohbet (Mesajlaşma) Akışı
İki kullanıcının uygulama içerisinde birbirine mesaj atması ve bu mesajların anlık olarak teslim edilerek push bildirimi gönderilmesi akışıdır:

```mermaid
sequenceDiagram
    autonumber
    actor UserA as Gönderici (Kullanıcı A)
    actor UserB as Alıcı (Kullanıcı B)
    participant AppA as Flutter App A
    participant Firestore as Cloud Firestore
    participant CloudFunc as Firebase Cloud Functions
    participant FCM as Firebase Cloud Messaging
    participant AppB as Flutter App B

    UserA->>AppA: Mesaj yazar ve "Gönder" tuşuna basar
    Note over AppA: lib/services/message_service.dart<br>sendMessage() çağrılır
    AppA->>Firestore: 'messages' koleksiyonuna yeni belge yazar
    
    Firestore->>CloudFunc: document('messages/{msgId}').onCreate tetiklenir (onUserMessageCreated)
    Note over CloudFunc: functions/index.js (onUserMessageCreated)<br>Alıcının aktif FCM token'ı 'users/{userId}' belgesinden çekilir
    
    CloudFunc->>FCM: messaging().send() ile push mesajını gönderir (Payload: type: 'message', senderId, senderName)
    FCM->>AppB: Bildirim ulaşır (GMS / NotificationService)
    
    Note over AppB: lib/services/notification_service.dart<br>_handleNotificationTap() tetiklenir
    AppB->>AppB: Sohbet penceresini açar (MessageScreen)
```

#### Teknik Detaylar (Kod Seviyesi):
1.  **Mesaj Gönderme ([message_service.dart:L14](file:///d:/firsatkolik/lib/services/message_service.dart#L14)):**
    *   Mesaj nesnesi alıcı adı, gönderici adı, içerik ve `isRead: false` bayrağı ile Firestore'a eklenir.
2.  **Sohbet Bildirimi Fonksiyonu ([functions/index.js:L908](file:///d:/firsatkolik/functions/index.js#L908)):**
    *   Cloud Functions `onUserMessageCreated` tetikleyicisi Firestore'a yazılan her mesajı dinler.
    *   Alıcı kullanıcının `users` koleksiyonundaki dokümanına giderek güncel `fcmToken` değerini okur.
    *   Eğer alıcı aktif olarak sohbet ekranında değilse (veya uygulama kapalıysa), FCM üzerinden veri (data) öncelikli push bildirimi yollar.
3.  **Yerel Yönlendirme ve Bildirim Yakalama ([notification_service.dart:L1238](file:///d:/firsatkolik/lib/services/notification_service.dart#L1238)):**
    *   Mobil uygulamadaki `NotificationService`, gelen push bildiriminin veri paketini (payload) inceler.
    *   Eğer bildirim `type == 'message'` tipindeyse ve `senderId` doluysa, `_navigateToChat(senderId, senderName)` metodu çağrılarak kullanıcının doğrudan o kişiyle olan `MessageScreen` sohbet arayüzüne geçmesi sağlanır.

---

### 4. Akış D: Anahtar Kelime Takip (Keyword Alerts) Akışı
Kullanıcıların belirli kelimeleri (örneğin "laptop", "PlayStation") takibe alarak, bu kelimelerle eşleşen bir fırsat onaylandığında anında kişiselleştirilmiş bildirim alması akışıdır:

```mermaid
sequenceDiagram
    autonumber
    actor User as Kullanıcı
    participant App as Flutter Mobil Uygulama
    participant Firestore as Cloud Firestore
    participant CloudFunc as Firebase Cloud Functions
    participant FCM as Firebase Cloud Messaging

    User->>App: "laptop" kelimesini takibe ekler
    App->>Firestore: 'keywords' koleksiyonuna kelimeyi yazar ({ userId, keyword: "laptop" })
    
    Note over CloudFunc: Bir admin "HP Laptop Fırsatı" başlıklı fırsatı onaylar
    CloudFunc->>Firestore: 'keywords' koleksiyonundaki tüm belgeleri çeker
    Note over CloudFunc: JavaScript string.includes() veya RegEx ile<br>"laptop" kelimesiyle eşleşen kullanıcıları süzgeçten geçirir
    
    CloudFunc->>Firestore: Eşleşen kullanıcıların FCM Token'larını toplar
    CloudFunc->>FCM: messaging().sendEachForMulticast() ile kişiselleştirilmiş bildirim gönderir
    FCM->>App: Kullanıcı telefonuna "Takip ettiğiniz 'laptop' kelimesiyle ilgili yeni bir fırsat var!" bildirimi düşer
```

#### Teknik Detaylar (Kod Seviyesi):
1.  **Eşleştirme Algoritması ([functions/index.js:L701](file:///d:/firsatkolik/functions/index.js#L701)):**
    *   Cloud Functions içindeki `sendKeywordNotifications` fonksiyonu, onaylanan fırsatın başlığını ve açıklamasını küçük harfe çevirir.
    *   Firestore'daki tüm `keywords` koleksiyonu taranarak kullanıcının kaydettiği kelimelerle eşleşme sorgulanır.
    *   Algoritma, Türkçe karakter duyarlılığını çözmek için kelimeleri normalize ederek (`ı->i`, `ş->s` vb.) karşılaştırır.
2.  **Kişiselleştirilmiş Bildirim Gönderimi:**
    *   Genel bildirimler gibi tek bir kanala (topic) yayın yapmak yerine, her bir eşleşen kullanıcının FCM token listesi toplanır ve `sendEachForMulticast` (veya toplu gönderim paketi) kullanılarak yalnızca o kelimeyi takip eden hedeflenmiş cihazlara bildirim ulaştırılır.
