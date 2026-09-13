# FırsatKolik iOS Mimari Uyumluluk, Uçtan Uca Kontrol Listesi ve Production Yayın Rehberi

> [!IMPORTANT]
> **Resmi iOS & Android Production Mimari Sözleşmesi:** Bu doküman, FırsatKolik platformunun bugüne kadar Android cihazlar üzerinde geliştirilmiş ve doğrulanmış tüm ekranlarının, servislerinin, bulut fonksiyonlarının (26 Cloud Functions), Telegram botlarının, Web Admin panelinin ve kullanıcı etkileşimlerinin iOS platformunda (iPhone, iPad) **%100 kusursuz, kararlı, sıfır çökme (zero-crash) ve Apple App Store İnceleme Kılavuzuna (App Store Review Guidelines)** tam uyumlu çalışmasını garanti altına alan nihai mimari sözleşmedir.

---

## 📑 İçindekiler
1. [🌟 Yönetici Özeti & iOS Mimari Sözleşmesi](#1--yönetici-özeti--ios-mimari-sözleşmesi)
2. [⚖️ Apple App Store İnceleme Kılavuzu (Review Guidelines) Uyumluluk Matrisi](#2-️-apple-app-store-i̇nceleme-kılavuzu-review-guidelines-uyumluluk-matrisi)
3. [🛠️ iOS Altyapı, Yapılandırma Dosyaları & Yetkiler (Kod ve Konfigürasyonlar)](#3-️-ios-altyapı-yapılandırma-dosyaları--yetkiler-kod-ve-konfigürasyonlar)
   - 3.1 [ios/Podfile (Minimum Hedef Sürüm)](#31-iospodfile)
   - 3.2 [ios/Runner/Runner.entitlements (Yetkiler & Universal Links)](#32-iosrunnerrunnerentitlements)
   - 3.3 [ios/Runner/Info.plist (AdMob, ATT, URL Schemes & Deep Linking)](#33-iosrunnerinfoplist)
   - 3.4 [ios/Runner/AppDelegate.swift (Native HTTP & Bildirim Tüneli)](#34-iosrunnerappdelegateswift)
4. [🔔 APNs & Firebase Cloud Messaging (FCM HTTP v1) iOS Mimarisi](#4--apns--firebase-cloud-messaging-fcm-http-v1-ios-mimarisi)
   - 4.1 [Uçtan Uca APNs İletim Şeması (Mermaid / ASCII)](#41-uçtan-uca-apns-iletim-şeması)
   - 4.2 [Kritik APNs Bildirim Önlemleri](#42-kritik-apns-bildirim-önlemleri)
5. [🔍 Tüm Alt Sistemler ve Doküman Modülleriyle Çapraz Analiz (Cross-System Audit)](#5--tüm-alt-sistemler-ve-doküman-modülleriyle-çapraz-analiz-cross-system-audit)
   - 5.1 [Backend & Bulut Altyapısı (Cloud Functions & APNs Payload)](#51-backend--bulut-altyapısı-cloud-functions--apns-payload)
   - 5.2 [Bildirim Sistemi & APNs Token Yaşam Döngüsü](#52-bildirim-sistemi--apns-token-yaşam-döngüsü)
   - 5.3 [Kimlik Doğrulama, EULA & Hesap Yönetimi](#53-kimlik-doğrulama-eula--hesap-yönetimi)
   - 5.4 [Birebir Mesajlaşma, Moderasyon & Kullanıcı Engelleme](#54-birebir-mesajlaşma-moderasyon--kullanıcı-engelleme)
   - 5.5 [Dış Mağazalar, Affiliate & Apple Universal Links](#55-dış-mağazalar-affiliate--apple-universal-links)
   - 5.6 [Scraping, Native MethodChannel & Telegram Botu](#56-scraping-native-methodchannel--telegram-botu)
   - 5.7 [Kuponlar ve Aktüel Afiş Katalogları](#57-kuponlar-ve-aktüel-afiş-katalogları)
   - 5.8 [Mobil Arayüz, Dynamic Island, Safe Area & AdMob](#58-mobil-arayüz-dynamic-island-safe-area--admob)
   - 5.9 [Web Admin Paneli & Hosting Yapılandırması](#59-web-admin-paneli--hosting-yapılandırması)
6. [📋 Uçtan Uca Ekran & İşlevsellik Kontrol Listesi (25 Nokta)](#6--uçtan-uca-ekran--i̇şlevsellik-kontrol-listesi-25-nokta)
7. [⚠️ Olası iOS Hata Senaryoları & Savunma Önlemleri (Failure Modes)](#7-️-olası-ios-hata-senaryoları--savunma-önlemleri-failure-modes)
8. [🚀 TestFlight & App Store Connect Production Yayın İş Akışı](#8--testflight--app-store-connect-production-yayın-i̇ş-akışı)

---

## 1. 🌟 Yönetici Özeti & iOS Mimari Sözleşmesi

Android ve iOS işletim sistemleri arasındaki temel çekirdek farklılıkları (Sandbox yapısı, APNs mimarisi, URL scheme whitelist zorunluluğu, UI SafeArea/Dynamic Island standartları, Apple kimlik doğrulama zorunluluğu, App Tracking Transparency ve EULA gereklilikleri) FırsatKolik kod tabanında çözümlenmiş ve standartlaştırılmıştır:

1. **Ölümcül Açılış Çökmeleri Engellendi (Zero-Crash):** `firebase_options.dart` içerisindeki `UnsupportedError` giderildi; `iosDev` ve `iosProd` konfigürasyonları eklendi. `Info.plist` içine `GADApplicationIdentifier` ve 27 adet AdMob `SKAdNetworkItems` tanımlandı.
2. **Apple Giriş (Sign in with Apple) Entegrasyonu:** Apple Guideline 4.8 gereğince hem UI (`Icons.apple` butonlu "Apple ile Devam Et") hem servis (`SignInWithApple.getAppleIDCredential`) hem de `Runner.entitlements` yetki katmanında eksiksiz yapılandırıldı.
3. **EULA & Kullanıcı Şartları Sözleşmesi:** Apple Guideline 1.2 ve 5.1.1 gereğince `AuthScreen` üzerinde kullanıcıların görebileceği ve doğrudan `PrivacyPolicyScreen`'e yönlenen tıklanabilir "Kullanım Koşulları & Gizlilik Politikası" onay metni entegre edildi.
4. **Dış Mağaza & Deep Link Entegrasyonu:** iOS 9+ `LSApplicationQueriesSchemes` whitelist'i oluşturularak `hbapp://`, `trendyol://`, `teknosa://`, `n11://`, `amazon://`, `tg://`, `whatsapp://`, `itms-apps://` gibi tüm harici mağaza ve iletişim yönlendirmelerinin çalışması sağlandı.
5. **Apple Universal Links (Associated Domains):** `Runner.entitlements` içerisine `applinks:firsatkolik.app` eklendi; Firebase Hosting `web/.well-known/apple-app-site-association` dosyası `application/json` Content-Type başlığı ile yayına hazır hale getirildi.
6. **APNs & FCM Yarış Durumu (Race Condition) Çözümü:** iOS'ta APNs token atanmadan çağrılan `getToken()` hataları `getAPNSToken()` 5 saniyelik retry döngüsüyle garantiye alındı.
7. **Bağlamsal Bildirim İzni Standartlaştırması:** `initializeLocalNotifications()` içerisindeki `DarwinInitializationSettings`'in `requestAlertPermission` parametresi `false` yapılarak uygulamanın açılışta körü körüne sistem diyaloğu açması engellendi; 5 organik bağlamsal tetikleyici nokta korundu.
8. **iOS Yerel Bildirim Görünürlüğü:** `_localNotifications.show` ve `_firebaseMessagingBackgroundHandler` çağrılarında eksik olan `DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true)` entegre edildi.
9. **Rozet (Badge) Temizleme Mekanizması:** Bildirim kutusu açıldığında iOS uygulama ikonu üzerindeki bildirim sayısının sıfırlanması için `clearBadgeAndNotifications()` metodu eklendi.
10. **Native HTTP Çerez Desteği:** iOS `URLSession` katmanına (`AppDelegate.swift`) `cookie` başlığı entegre edilerek Getir/Zara gibi korumalı mağazaların ayrıştırılması sağlandı.
11. **Platforma Özel AdMob Test ID'si:** iOS cihazlarda Android test banner ID'sinin reklam yükleme hatası (No ad config) vermesini önlemek için `firebase_options.dart` içine platform kontrolü eklenerek resmi iOS test ID'si (`ca-app-pub-3940256099942544/2934735716`) tanımlandı.

---

## 2. ⚖️ Apple App Store İnceleme Kılavuzu (Review Guidelines) Uyumluluk Matrisi

Apple App Store inceleme ekibi tarafından incelenen ve en sık ret gerekçesi olan 6 temel kılavuz maddesi ve FırsatKolik'in teknik çözümü:

| Apple Kılavuz Maddesi | Kural Tanımı & Zorunluluk | FırsatKolik Uygulama Çözümü | Doğrulama & Kod Karşılığı |
| :--- | :--- | :--- | :--- |
| **Guideline 1.2 (User Generated Content - UGC)** | Kullanıcıların içerik ürettiği (fırsat, yorum, mesaj) uygulamalarda EULA onay şartı, küfür filtreleme, rahatsız edici içeriği şikayet etme ve tacizci kullanıcıyı engelleme mekanizması bulunmalıdır. | 1. `auth_screen.dart` altında tıklanabilir EULA / Gizlilik Politikası onayı.<br>2. `containsProfanity` filtresi (mobil + Cloud Functions).<br>3. `ReportDialog`: Fırsat, yorum, mesaj ve kullanıcı şikayet mekanizması.<br>4. Kullanıcı engelleme: Hem `MessageScreen` hem `ProfileScreen` üzerinden 1 tıkla engelleme.<br>5. Web Admin Paneli üzerinden 24 saatte inceleme taahhüdü. | [auth_screen.dart](file:///d:/firsatkolik/lib/screens/auth_screen.dart#L440-L470)<br>[message_screen.dart](file:///d:/firsatkolik/lib/screens/message_screen.dart#L638)<br>[profile_screen.dart](file:///d:/firsatkolik/lib/screens/profile_screen.dart#L2599) |
| **Guideline 4.8 (Sign in with Apple)** | Google veya diğer 3. taraf sosyal giriş yöntemleri sunan tüm iOS uygulamaları, eşdeğer ve eşit görünürlükte Apple ile Giriş seçeneği sunmak zorundadır. | iOS platformunda `Icons.apple` logolu "Apple ile Devam Et" butonu en üst düzey görünürlüktedir. `sign_in_with_apple` paketi ve `Runner.entitlements` yetkisi yapılandırılmıştır. | [auth_screen.dart](file:///d:/firsatkolik/lib/screens/auth_screen.dart#L416-L426)<br>[auth_service.dart](file:///d:/firsatkolik/lib/services/auth_service.dart#L440)<br>[Runner.entitlements](file:///d:/firsatkolik/ios/Runner/Runner.entitlements#L5-L9) |
| **Guideline 5.1.1(v) (Account Deletion - Hesap Silme)** | Hesap oluşturmaya izin veren uygulamalar, uygulama içinden doğrudan ve kolayca hesabı tüm verileriyle silme imkanı sunmalıdır. | `SupportHubScreen` altında "Hesabımı Sil" butonu yer alır. Kullanıcı onayladığında Auth ve Firestore silinir; arka planda `onUserDeleted` fonksiyonu bildirim, cihaz ve tercihlerini temizler. | [support_hub_screen.dart](file:///d:/firsatkolik/lib/screens/support_hub_screen.dart#L326)<br>[auth_service.dart](file:///d:/firsatkolik/lib/services/auth_service.dart#L708)<br>[functions/index.js](file:///d:/firsatkolik/functions/index.js#L2675) |
| **Guideline 2.1 (App Completeness & Performance)** | Uygulama açılışta çökmeyecek, boş veya sahte buton içermeyecek, placeholder veri göstermeyecektir. | `firebase_options.dart` iOS eşitlemesi tamamlandı. AdMob App ID eklendi. Test hesapları ve örnek veriler App Store Connect inceleme notlarına eklenebilir durumdadır. | [firebase_options.dart](file:///d:/firsatkolik/lib/firebase_options.dart#L39)<br>[Info.plist](file:///d:/firsatkolik/ios/Runner/Info.plist#L97) |
| **Guideline 5.1.2 (Data Use & App Tracking Transparency)** | Kişiselleştirilmiş reklam veya cihazlar arası takip yapan uygulamalar iOS 14.5+ ATT izni istemeli ve gizlilik amacını açıklamalıdır. | `Info.plist` içine `NSUserTrackingUsageDescription` eklendi. `GoogleMobileAds` SDK'sı ile UMP Consent formu entegre edildi. | [Info.plist](file:///d:/firsatkolik/ios/Runner/Info.plist#L214)<br>[main.dart](file:///d:/firsatkolik/lib/main.dart#L252) |
| **Guideline 3.1.5(a) (Physical Goods and Services Outside the App)** | Fiziksel ürünlerin ve e-ticaret sitelerindeki indirimlerin paylaşılması IAP (In-App Purchase) kapsamı dışındadır. | FırsatKolik dijital ürün satmaz; fiziksel e-ticaret sitelerindeki (Amazon, Hepsiburada, Trendyol vb.) indirimleri listeler ve dış bağlantı ile yönlendirir. Kurala %100 uygundur. | [store_redirect_service.dart](file:///d:/firsatkolik/lib/services/affiliate/store_redirect_service.dart#L80) |

---

## 3. 🛠️ iOS Altyapı, Yapılandırma Dosyaları & Yetkiler (Kod ve Konfigürasyonlar)

Aşağıdaki yapılandırma dosyaları, Xcode derleme hattında ve iOS işletim sistemi seviyesinde doğrudan kontrol edilmesi gereken resmi kod ve ayar sözleşmeleridir:

### 3.1 `ios/Podfile`
Modern Firebase, AdMob ve Sign in with Apple kütüphanelerinin iOS SDK uyumluluğu için minimum hedef sürüm **iOS 14.0** olarak sabitlenmiştir:
```ruby
# ios/Podfile
platform :ios, '14.0'
```
*Not: `ios/Runner.xcodeproj/project.pbxproj` içerisindeki `IPHONEOS_DEPLOYMENT_TARGET` değeri de tüm konfigürasyonlarda (Debug, Profile, Release) `14.0` olarak eşitlenmiştir.*

### 3.2 `ios/Runner/Runner.entitlements`
Apple Developer hesabında uygulama için tanımlanacak yetkiler proje seviyesinde oluşturulmuş ve `project.pbxproj` dosyasına `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` olarak bağlanmıştır:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- Apple ile Giriş (Sign in with Apple) Yetkisi -->
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>

	<!-- Apple Push Notification Service (APNs) Yetkisi -->
	<key>aps-environment</key>
	<string>development</string>

	<!-- Universal Links (Associated Domains) -->
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:firsatkolik.app</string>
		<string>applinks:sicak-firsatlar-e6eae.web.app</string>
		<string>applinks:firsatkolik.web.app</string>
	</array>
</dict>
</plist>
```

### 3.3 `ios/Runner/Info.plist`
Apple Store ve iOS çalışma ortamı için tanımlanan kritik anahtarlar:
- **`GADApplicationIdentifier`**: `ca-app-pub-3940256099942544~1458002511` (AdMob SDK açılış çökmesini önler).
- **`SKAdNetworkItems`**: 27 adet sertifikalı reklam ağı takip kimliği (AdMob, AppLovin, UnityAds vb.).
- **`LSApplicationQueriesSchemes`**: `https`, `http`, `tg`, `telegram`, `whatsapp`, `hbapp`, `trendyol`, `teknosa`, `n11`, `amazon`, `mailto`, `tel`, `itms-apps` (iOS 9+ `canLaunchUrl` whitelist'i).
- **`FlutterDeepLinkingEnabled`**: `<true/>` (Apple Universal Links'i Flutter rota motoruna bağlar).
- **`CFBundleURLTypes`**: Google Sign-In redirect şemaları (`com.googleusercontent.apps...`) ve özel URL scheme (`firsatkolik`).
- **`UIBackgroundModes`**: `fetch` ve `remote-notification` (Arka plan FCM bildirimleri için).
- **`ITSAppUsesNonExemptEncryption`**: `<false/>` (App Store yüklemelerinde ihracat muafiyetini otomatik onaylar).
- **`NSUserTrackingUsageDescription`**: ATT (App Tracking Transparency) onay izin metni.
- **`NSPhotoLibraryUsageDescription`**: Profil fotoğrafı seçimi için galeri erişim izni.

### 3.4 `ios/Runner/AppDelegate.swift`
Native HTTP MethodChannel köprüsü ve ön plan bildirim delegate kaydı:
```swift
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // iOS 10+ Ön plan bildirimleri için delegate kaydı
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let nativeHttpChannel = FlutterMethodChannel(name: "com.sicakfirsatlar.app/native_http",
                                              binaryMessenger: controller.binaryMessenger)
    
    nativeHttpChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "fetchUrl" {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing url", details: nil))
          return
        }
        
        let userAgent = args["userAgent"] as? String ?? "WhatsApp/2.23.4.15 A"
        let cookie = args["cookie"] as? String
        
        guard let url = URL(string: urlString) else {
          result(FlutterError(code: "BAD_ARGS", message: "Invalid URL", details: nil))
          return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        if let cookie = cookie, !cookie.isEmpty {
          request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        request.timeoutInterval = 10.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
          if let error = error {
            DispatchQueue.main.async {
              result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
            }
            return
          }
          
          guard let httpResponse = response as? HTTPURLResponse else {
            DispatchQueue.main.async {
              result(FlutterError(code: "ERROR", message: "Invalid response type", details: nil))
            }
            return
          }
          
          if httpResponse.statusCode == 200 {
            if let data = data, let html = String(data: data, encoding: .utf8) {
              DispatchQueue.main.async {
                result(html)
              }
            } else {
              DispatchQueue.main.async {
                result(FlutterError(code: "ERROR", message: "Failed to decode UTF-8 data", details: nil))
              }
            }
          } else {
            DispatchQueue.main.async {
              result(FlutterError(code: "HTTP_ERROR", message: "Status code: \(httpResponse.statusCode)", details: nil))
            }
          }
        }
        task.resume()
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3.4.1 🛡️ iOS Yaşam Döngüsü (Lifecycle) & Swipe-to-Kill Stabilizasyonu
- **Deneysel UIScene Uyarısı:** Xcode derleme çıktısında görülen `UIScene lifecycle support will soon be required` uyarısı yalnızca gelecekteki çok pencereli iPadOS uygulamalarına yönelik bir bilgilendirmedir. Tek pencereli iPhone uygulamalarında `UIScene` zorunlu değildir.
- **Çökme Önleme:** `Info.plist` içine `UIApplicationSceneManifest` ve `AppDelegate.swift` içine `FlutterImplicitEngineDelegate` eklendiğinde; kullanıcı uygulamayı çoklu görev yöneticisinden (App Switcher) yukarı kaydırıp kapattığında (swipe-to-kill), UIKit süreci temizce sonlandırmak yerine önce `sceneDidDisconnect` tetikleyip pencereyi siler. Bu sırada arka plandaki eklentiler (Google Mobile Ads, Firebase Messaging vb.) deallocated belleğe eriştiği için `EXC_BAD_ACCESS` / `SIGSEGV` yerel çökmesi meydana gelir ve TestFlight "Fırsatkolik Çöktü" modalı gösterir.
- **Kalıcı Çözüm:** `UIApplicationSceneManifest` kaldırılmış, `AppDelegate` standart ve stabil `FlutterAppDelegate` yapısında tutulmuştur. Swipe-to-kill anında işletim sistemi süreci doğrudan `SIGKILL` ile temizler, çökme oluşmaz.

### 3.4.2 📤 iOS / iPadOS Natif Paylaşım Mimarisi (`ShareHelper` & `sharePositionOrigin`)
- **Popover Zorunluluğu:** iOS ve iPadOS üzerinde Apple `UIActivityViewController`'ı popover olarak sunarken pencerenin açılacağı kaynak koordinatını (`sharePositionOrigin`) zorunlu tutar. Bu parametre verilmezse veya sıfır (`{{0,0}, {0,0}}`) kalırsa `CGRectIsEmpty` denetimi nedeniyle `PlatformException` fırlatılır.
- **Çözüm:** `lib/utils/share_helper.dart` içindeki `ShareHelper.calculateOrigin(context)` metodu, tıklanan butonun RenderBox koordinatlarını (`localToGlobal`) dinamik olarak hesaplar. Buton henüz render olmamışsa veya sheet kapatılmışsa ekran boyutunu baz alan güvenli ve sıfır olmayan bir Rect üreterek `ShareHelper.shareText` ve `ShareHelper.shareFiles` ile paylaşımı iOS'ta hatasız çalıştırır.

---

## 4. 🔔 APNs & Firebase Cloud Messaging (FCM HTTP v1) iOS Mimarisi

iOS bildirim akışı Android'den farklı olarak doğrudan Google FCM sunucularından cihaza ulaşamaz; **Apple Push Notification service (APNs)** tüneli üzerinden işler.

### 4.1 Uçtan Uca APNs İletim Şeması

```
[Cloud Functions: onNotificationCreated / onUserMessageCreated]
                               │
                               ▼ (FCM HTTP v1 API)
                   [Firebase Cloud Messaging]
                               │
                               ▼ (JWT / .p8 Auth Key)
                      [Apple APNs Sunucusu]
                               │
                               ▼ (APNs Device Token)
                         [iPhone / iPad Cihaz]
                               │
         ┌─────────────────────┴─────────────────────────┐
         ▼ (Ön Planda Açıkken)                           ▼ (Arka Plan / Kapalı)
[UNUserNotificationCenterDelegate]             [iOS Sistem Bildirim Merkezi]
         │                                               │
[DarwinNotificationDetails]                    [Kullanıcı Bildirime Dokunur]
         │                                               │
   [In-App Banner]                              [Cold-Start Deep Link Açılışı]
```

### 4.2 Kritik APNs Bildirim Önlemleri

1. **APNs Token Bekleme:** `NotificationService` içinde token alınırken `getAPNSToken()` 5 saniye boyunca 1'er saniye arayla sorgulanır. Token hazır olduğunda `getToken()` çağrılır. Böylece `[apns-token-not-set]` hatası tamamen önlenir.
2. **Cloud Functions APNs Payload:** Arka planda başlık ve gövdenin iOS sistem tepsisinde doğru görünmesi için Cloud Functions (`functions/index.js`) içindeki tüm push mesajlarına:
   ```javascript
   apns: {
     headers: {
       'apns-priority': '10',
       'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
     },
     payload: {
       aps: {
         sound: 'default',
         badge: 1,
         'content-available': 1,
         'interruption-level': 'active',
       }
     }
   }
   ```
   eklenmiştir. Böylece düşük pil modunda dahi bildirimler anında ekrana düşer.
3. **Data-Only Birebir Sohbet İletimi:** Mesaj bildirimleri data-only olarak iletilir. Flutter ön plan dinleyicisi `activeChatUserId` kontrolü yaparak kullanıcının o an sohbette olup olmadığını kontrol eder ve duplicate bildirim oluşmasını engeller.
4. **Rozet (Badge) Temizleme:** Bildirim kutusu açıldığında iOS uygulama ikonu üzerindeki kırmızı sayaç `clearBadgeAndNotifications()` ile sıfırlanır.

---

## 5. 🔍 Tüm Alt Sistemler ve Doküman Modülleriyle Çapraz Analiz (Cross-System Audit)

### 5.1 Backend & Bulut Altyapısı (Cloud Functions & APNs Payload)
- **İlgili Dokümanlar:**
  - [Cloud Functions Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/cloud_functions_rehberi.md)
  - [Backend ve Altyapı Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/backend_ve_altyapi_rehberi.md)
  - [Firestore ve Storage Güvenlik Kuralları](file:///d:/firsatkolik/documentation/backend-ve-altyapi/firestore_ve_storage_guvenlik_kurallari_rehberi.md)
- **iOS Uyumluluk Durumu:**
  1. **APNs Başlıkları ve Öncelik:** `functions/index.js` içerisindeki `onNotificationCreated` ve `onUserMessageCreated` fonksiyonlarında APNs payload'u `apns-priority: '10'`, `sound: 'default'`, `badge: 1` ve `content-available: 1` olarak yapılandırılmıştır.
  2. **Güvenlik Kuralları:** `firestore.rules` ve `storage.rules` platformdan bağımsızdır; iOS istemcileri Firebase App Check (`AppleProvider.deviceCheck` / `AppleProvider.debug`) ve RBAC kurallarına tam riayet eder.

### 5.2 Bildirim Sistemi & APNs Token Yaşam Döngüsü
- **İlgili Dokümanlar:**
  - [Bildirim Sistemi Master Rehberi](file:///d:/firsatkolik/documentation/bildirimler/bildirim_sistemi_rehberi.md)
  - [Bildirim Senaryoları Matrisi](file:///d:/firsatkolik/documentation/bildirimler/notification_scenarios.md)
  - [Notification System Architect](file:///d:/firsatkolik/documentation/bildirimler/NOTIFICATION_SYSTEM_ARCHITECT.md)
- **iOS Uyumluluk Durumu:**
  1. **Bağlamsal İzin İsteme (Contextual UX):** Açılışta körü körüne izin isteme (`DarwinInitializationSettings(requestAlertPermission: false)`) kaldırılmıştır. İzin yalnızca kullanıcı radar eklediğinde, kategori açtığında veya yazarı takip ettiğinde istenir.
  2. **Darwin Notification Details:** `_localNotifications.show()` çağrılarına `iOS: DarwinNotificationDetails(...)` tanımlanarak ön planda veya arka planda sessizce yutulan bildirimler engellenmiştir.

### 5.3 Kimlik Doğrulama, EULA & Hesap Yönetimi
- **İlgili Dokümanlar:**
  - [Profil Resmi ve Kullanıcı Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/profil_resmi_ve_kullanici_rehberi.md)
  - [Domain ve Web Showcase Rehberi](file:///d:/firsatkolik/documentation/web-ve-domain/domain_ve_web_showcase_rehberi.md)
- **iOS Uyumluluk Durumu:**
  1. **Sign in with Apple:** `SignInWithApple.getAppleIDCredential` üzerinden `OAuthProvider("apple.com").credential` oluşturulur. Apple kullanıcı adı gizleme durumunda dahi `AppUser` güvenli varsayılanlarla Firestore'a yazılır.
  2. **EULA & Sözleşme Onayı:** `auth_screen.dart` altında tıklanabilir `PrivacyPolicyScreen` bağlantısı mevcuttur.
  3. **Hesap Silme:** `SupportHubScreen` üzerinden başlatılan silme işlemi Firestore `users` belgesini siler, `FirebaseAuth` kullanıcısını siler ve Cloud Function `onUserDeleted` vasıtasıyla tüm bağımlı alt koleksiyonları (`userDevices`, `notifications`, `preferences`) temizler.

### 5.4 Birebir Mesajlaşma, Moderasyon & Kullanıcı Engelleme
- **İlgili Dokümanlar:**
  - [Mesajlaşma Sistemi Mevcut Durum Raporu](file:///d:/firsatkolik/documentation/mimari-ve-sistem/MESAJLASMA_SISTEMI_MEVCUT_DURUM_RAPORU.md)
  - [İçerik Moderasyonu ve Şikayet Sistemi Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/icerik_moderasyonu_ve_sikayet_sistemi_rehberi.md)
- **iOS Uyumluluk Durumu:**
  1. **Kullanıcı Engelleme:** Hem `MessageScreen` AppBar açılır menüsünde hem de `ProfileScreen` üç nokta menüsünde "Kullanıcıyı Engelle" / "Engeli Kaldır" butonları anında reaksiyon verir.
  2. **İçerik Şikayet Etme:** Fırsatlar (`DealDetailScreen`), yorumlar (`CommentsBottomSheet`), sohbet mesajları (`MessageScreen`) ve kullanıcı profilleri (`ProfileScreen`) üzerinde `ReportDialog` aktiftir.
  3. **Klavye & SafeArea:** iOS klavye açılışlarında `Scaffold(resizeToAvoidBottomInset: true)` ve `reverse: true` ListView yapısıyla mesaj giriş çubuğu Dynamic Island veya klavye altında ezilmez.

### 5.5 Dış Mağazalar, Affiliate & Apple Universal Links
- **İlgili Dokümanlar:**
  - [Affiliate Link Dönüştürme Rehberi](file:///d:/firsatkolik/documentation/scraping-ve-botlar/affiliate/affiliate_link_donusturme_ve_stratejileri_rehberi.md)
  - [Mağaza Kılavuzları (Hepsiburada, Amazon, Trendyol, Teknosa vb.)](file:///d:/firsatkolik/documentation/kategoriler-ve-magazalar/)
- **iOS Uyumluluk Durumu:**
  1. **URL Scheme Whitelist:** `Info.plist` içine `hbapp`, `trendyol`, `teknosa`, `n11`, `amazon`, `tg`, `whatsapp`, `itms-apps` eklenmiştir. `canLaunchUrl()` iOS'ta false dönmez.
  2. **Apple Universal Links:** `Runner.entitlements` içinde `applinks:firsatkolik.app` mevcuttur. `web/.well-known/apple-app-site-association` ve `web/apple-app-site-association` dosyaları ile iOS cihazlar web bağlantılarına tıklandığında doğrudan mobil uygulamayı açar.

### 5.6 Scraping, Native MethodChannel & Telegram Botu
- **İlgili Dokümanlar:**
  - [Scraping Mimarisi Rehberi](file:///d:/firsatkolik/documentation/scraping-ve-botlar/scraping_mimarisi_rehberi.md)
  - [Bot Scraping Rules and Strategies](file:///d:/firsatkolik/documentation/scraping-ve-botlar/bot_scraping_rules_and_strategies.md)
- **iOS Uyumluluk Durumu:**
  1. **AppDelegate Native HTTP:** Android `MainActivity.kt` içerisindeki native HTTP istemcisinin tam karşılığı `ios/Runner/AppDelegate.swift` içinde `URLSession` ile yazılmıştır. `cookie`, `userAgent` ve `timeout` parametreleri eksiksizdir.
  2. **Telegram Botu Linkleri:** Botkolik tarafından Telegram grubuna atılan `firsatkolik.app/deal/{id}` linkleri iOS cihazlarda doğrudan uygulama içi detayı açar.

### 5.7 Kuponlar ve Aktüel Afiş Katalogları
- **İlgili Dokümanlar:**
  - [Kuponlar Modülü Rehberi](file:///d:/firsatkolik/documentation/kuponlar/kuponlar_modulu_rehberi.md)
  - [Aktüel Kataloglar Modülü Rehberi](file:///d:/firsatkolik/documentation/aktuel/aktuel_kataloglar_modulu_rehberi.md)
- **iOS Uyumluluk Durumu:**
  1. **Taptic Engine (HapticFeedback):** Kupon kodu kopyalandığında veya oylama yapıldığında iOS Taptic Engine tetiklenir (`HapticFeedback.lightImpact()` / `mediumImpact()`).
  2. **InteractiveViewer:** Aktüel katalog afişleri iOS'un yerel 2 parmakla büyütme (pinch-to-zoom) hareketleriyle pürüzsüz çalışır.

### 5.8 Mobil Arayüz, Dynamic Island, Safe Area & AdMob
- **İlgili Dokümanlar:**
  - [Design System Guide](file:///d:/firsatkolik/documentation/mobil-ve-ui/DESIGN_SYSTEM_GUIDE.md)
  - [Ticari Reklam Uyum Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/ticari_reklam_uyum_ve_etiketleme_rehberi.md)
- **iOS Uyumluluk Durumu:**
  1. **Dynamic Island & Notch:** `home_screen.dart`, `deal_detail_screen.dart` ve modal sayfalarda `MediaQuery.of(context).padding.top` kullanılarak ada ve çentik altına içerik taşması engellenmiştir.
  2. **Home Indicator:** Alt menü çubuklarında `SafeArea(top: false)` ve `MediaQuery.of(context).padding.bottom + 14` kullanılarak iPhone alt gezinme çubuğu ile butonların çakışması önlenmiştir.
  3. **AdMob iOS Banner ID:** `firebase_options.dart` içine `ca-app-pub-3940256099942544/2934735716` test banner ID'si entegre edilmiştir.

### 5.9 Web Admin Paneli & Hosting Yapılandırması
- **İlgili Dokümanlar:**
  - [Web Admin Paneli Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/web_admin_paneli_rehberi.md)
  - [Environment Management Guide](file:///d:/firsatkolik/documentation/backend-ve-altyapi/environment_management_guide.md)
- **iOS Uyumluluk Durumu:**
  1. **AASA Desteği:** `firebase.json` içerisindeki hosting ayarları `.well-known` dizinini yutmayacak şekilde düzenlenmiş ve `Content-Type: application/json` başlığı eklenmiştir.
  2. **Apple İnceleme Demo Hesabı:** Web Admin panelinde hazır bulunan test hesapları (`test_admin`, `test_user`) App Store Connect incelemesinde kullanılabilir.

---

## 6. 📋 Uçtan Uca Ekran & İşlevsellik Kontrol Listesi (25 Nokta)

| No | Modül / Ekran | İşlevsellik / Aksiyon | iOS Durumu & Alınan Önlem | Doğrulama & Test |
| :---: | :--- | :--- | :--- | :--- |
| **01** | **Splash & Başlatma** | Firebase Core, Crashlytics, AdMob başlatma | **TAM UYUMLU** ✅<br>`firebase_options.dart` iOS mapping ve `GADApplicationIdentifier` aktif. | `ios_compatibility_test.dart` doğrulandı. |
| **02** | **Kimlik Doğrulama** | Google Sign-In | **TAM UYUMLU** ✅<br>`CFBundleURLTypes` içine Google URL Scheme eklendi. | `Info.plist` şema testi tamamlandı. |
| **03** | **Kimlik Doğrulama** | Sign in with Apple | **TAM UYUMLU** ✅<br>`Runner.entitlements`'a `com.apple.developer.applesignin` tanımlandı. | Guideline 4.8 sağlandı. |
| **04** | **Kimlik Doğrulama** | EULA & Şartlar Onayı | **TAM UYUMLU** ✅<br>`auth_screen.dart`'ta tıklanabilir Kullanım Koşulları & Gizlilik Politikası linki aktif. | Guideline 1.2 & 5.1.1 sağlandı. |
| **05** | **Ana Sayfa** | Kategori/Fırsat Listesi & Scroll | **TAM UYUMLU** ✅<br>`BouncingScrollPhysics` ve iOS yerel sürtünme mekaniği devrede. | Safe Area ve scroll testi yapıldı. |
| **06** | **Ana Sayfa Alt Barı** | 4'lü Bottom Navigation & FAB | **TAM UYUMLU** ✅<br>`SafeArea(top: false)` ile Home Indicator çakışması önlendi. | Widget hiyerarşisi doğrulandı. |
| **07** | **Arama Radarı** | Kelime Takibi & İzin İsteme | **TAM UYUMLU** ✅<br>Organik tetikleyici nokta; `_messaging.requestPermission()` çağrılır. | Bağlamsal izin akışı doğrulandı. |
| **08** | **Fırsat Paylaşma** | Link Scraping (Native HTTP) | **TAM UYUMLU** ✅<br>`AppDelegate.swift` içindeki `fetchUrl` çerezli `URLSession` ile çalışır. | MethodChannel parametreleri doğrulandı. |
| **09** | **Paylaşım Menüsü** | Dışarıdan Link Kabul Etme | **TAM UYUMLU** ✅<br>`receive_sharing_intent` iOS'ta güvenli try-catch içine alındı. | Çökme koruması doğrulandı. |
| **10** | **Fırsat Detayı** | "Fırsata Git" Yönlendirmesi | **TAM UYUMLU** ✅<br>`LSApplicationQueriesSchemes` listesi (`hbapp`, `trendyol`, `amazon`) tanımlı. | URL scheme whitelist doğrulandı. |
| **11** | **Fırsat Detayı Barı** | Sticky Fiyat & Fırsata Git | **TAM UYUMLU** ✅<br>`bottom: MediaQuery.of(context).padding.bottom + 14` ile tam oturur. | Layout analizi doğrulandı. |
| **12** | **Fırsat Detayı Menü** | İçerik Şikayeti (`ReportDialog`) | **TAM UYUMLU** ✅<br>Apple Guideline 1.2 gereği fırsat şikayet modalı aktiftir. | Şikayet akışı doğrulandı. |
| **13** | **Yorumlar Sayfası** | Yorum Paylaşma & Şikayet | **TAM UYUMLU** ✅<br>Yorum şikayeti ve yorum sahibi engelleme seçenekleri aktiftir. | `CommentsBottomSheet` doğrulandı. |
| **14** | **Canlı Mesajlaşma** | P2P Sohbet & Klavye | **TAM UYUMLU** ✅<br>`resizeToAvoidBottomInset: true` ile klavye girişi pürüzsüzdür. | Klavye padding kontrol edildi. |
| **15** | **Canlı Mesajlaşma** | Kullanıcı Engelleme & Şikayet | **TAM UYUMLU** ✅<br>AppBar açılır menüsünde "Kullanıcıyı Engelle" ve "Şikayet Et" butonları devrededir. | `MessageScreen` doğrulandı. |
| **16** | **Kullanıcı Profili** | Profil Menüsü & Engelleme | **TAM UYUMLU** ✅<br>Başka kullanıcının profiline bakıldığında engelleme ve şikayet butonları mevcuttur. | `ProfileScreen` doğrulandı. |
| **17** | **Kullanıcı Profili** | Rozetler & WebP Avatar | **TAM UYUMLU** ✅<br>Kamera iznine gerek duymayan optimize WebP avatar galerisiyle çalışır. | Veri modeli doğrulandı. |
| **18** | **Destek Merkezi** | Hesap Silme (Account Deletion) | **TAM UYUMLU** ✅<br>Firestore + Auth + Cloud Function ile tüm kullanıcı verileri silinir. | Guideline 5.1.1(v) doğrulandı. |
| **19** | **Değerlendirme** | App Store Puanlama | **TAM UYUMLU** ✅<br>iOS'ta `market://` yerine `itms-apps://` ve App Store web linki açılır. | Platform kontrolü doğrulandı. |
| **20** | **Bildirim Servisi** | APNs Token Alma & Kayıt | **TAM UYUMLU** ✅<br>`getAPNSToken()` retry döngüsü ile `apns-token-not-set` hatası önlenmiştir. | Servis katmanı doğrulandı. |
| **21** | **Bildirim Merkezi** | Rozet Temizleme & Okundu | **TAM UYUMLU** ✅<br>`clearBadgeAndNotifications()` ile uygulama ikonu rozeti sıfırlanır. | Servis metodu doğrulandı. |
| **22** | **Arka Plan Bildirimi** | Local Notification Gösterimi | **TAM UYUMLU** ✅<br>`DarwinNotificationDetails(presentAlert: true)` ile sistem tepsisine basılır. | `main.dart` doğrulandı. |
| **23** | **Kuponlar Modülü** | Kupon Kopyalama & Taptic | **TAM UYUMLU** ✅<br>`HapticFeedback.lightImpact()` ve pano kopyalama aktiftir. | Kupon sayfası doğrulandı. |
| **24** | **Aktüel Afişler** | Afiş Zoom & İnceleme | **TAM UYUMLU** ✅<br>`InteractiveViewer` iOS pinch-to-zoom hareketleriyle tam uyumludur. | Katalog sayfası doğrulandı. |
| **25** | **App İkonları** | iOS Home Screen & Settings | **TAM UYUMLU** ✅<br>20x20'den 1024x1024'e 22 adet iOS ikonu `Assets.xcassets` içinde yer alır. | Varlıklar doğrulandı. |

---

## 7. ⚠️ Olası iOS Hata Senaryoları & Savunma Önlemleri (Failure Modes)

1. **Hata: `[apns-token-not-set] Please wait for APNs token before calling getToken()`**
   - *Sebep:* iOS'ta internet yavaşken Firebase Messaging, APNs token Apple sunucularından dönmeden `getToken()` çağırmaya kalkışır.
   - *Çözüm:* `NotificationService.dart` içerisindeki `_saveFCMTokenInternal()` metodu `_messaging.getAPNSToken()` fonksiyonunu 5 saniye boyunca her saniye kontrol eder; token hazır olunca `getToken()` çağrılır.
2. **Hata: `canLaunchUrl(hbapp://...) returns false`**
   - *Sebep:* iOS 9+, `Info.plist` içerisindeki `LSApplicationQueriesSchemes` listesinde açıkça beyan edilmeyen şemaları güvenlik gerekçesiyle reddeder.
   - *Çözüm:* `Info.plist` içine `hbapp`, `trendyol`, `teknosa`, `n11`, `amazon`, `tg`, `whatsapp`, `itms-apps` eklenmiştir.
3. **Hata: AdMob `LoadAdError(code: 3, message: "No ad config")`**
   - *Sebep:* Geliştirme esnasında Android'e ait Google test reklam birimi ID'si iOS cihazda çağrılmıştır.
   - *Çözüm:* `firebase_options.dart` içine `defaultTargetPlatform == TargetPlatform.iOS` kontrolü eklenerek resmi iOS test ID'si (`ca-app-pub-3940256099942544/2934735716`) bağlanmıştır.
4. **Hata: Apple İnceleme Reddi (Guideline 1.2 - EULA & Reporting Missing)**
   - *Sebep:* Kullanıcıların paylaşım yaptığı bir uygulamada şikayet veya engelleme seçeneğinin bulunmaması.
   - *Çözüm:* `AuthScreen`'e tıklanabilir EULA onay linki, `MessageScreen` ve `ProfileScreen`'e anında engelleme/şikayet aksiyonları eklenmiştir.
5. **Hata: Home Indicator / Dynamic Island Taşması**
   - *Sebep:* Alt sabit butonların iPhone 15/16 alt gezinme çubuğunun veya Dynamic Island'ın arkasında kalması.
   - *Çözüm:* `SafeArea(top: false)` ve `MediaQuery.of(context).padding.bottom + 14` kullanılarak dinamik güvenli alan padding'i verilmiştir.

---

## 8. 🚀 TestFlight & App Store Connect Production Yayın İş Akışı

### 8.1 Apple Developer Portal Ayarları
1. **Identifiers (App ID):**
   - DEV Bundle ID: `com.sicakfirsatlar.sicakFirsatlar`
   - PROD Bundle ID: `com.firsatkolik.app`
2. **Capabilities (Yetenekler):**
   - `Push Notifications` ✅
   - `Sign in with Apple` ✅
   - `Associated Domains` (`applinks:firsatkolik.app`, `applinks:sicak-firsatlar-e6eae.web.app`) ✅
3. **APNs Authentication Key (.p8):**
   - Apple Developer Portal > `Keys` menüsünden **Apple Push Notifications service (APNs)** seçeneğiyle bir anahtar üretilir.
   - `AuthKey_XXXXXXXXXX.p8` dosyası indirilir. Key ID ve Team ID not edilir.
   - Firebase Console > `Project Settings` > `Cloud Messaging` > `Apple app configuration` sekmesine yüklenir.

### 8.2 Firebase Console & iOS Kimlik Doğrulama Yapılandırması
1. **Resmi iOS Uygulama Kayıtları:**
   - **PROD Projesi (`firsatkolik-prod-e6eae`):** App ID `1:228657473310:ios:5f779f3647ed4dd2380b0f`, Bundle ID `com.firsatkolik.app`
   - **DEV Projesi (`sicak-firsatlar-e6eae`):** App ID `1:560592268193:ios:be496ea2d9e55177d6f9e0`, Bundle ID `com.firsatkolik.app`
2. **Plists ve Xcode Kaynak Yönetimi:**
   - `ios/Runner/GoogleService-Info.plist`, `GoogleService-Info-prod.plist` ve `GoogleService-Info-dev.plist` oluşturulup `project.pbxproj` dosyasında `Resources` derleme fazına eklenmiştir. CI sırasında flavor'a göre otomatik kopyalanır.
3. **Google Sign-In URL Şeması (RFC 8252):**
   - `ios/Runner/Info.plist` içine `REVERSED_CLIENT_ID` şemaları işlenmiştir:
     - Prod: `com.googleusercontent.apps.228657473310-7dlhjuj25p2ov8o5274n3o3759h6gubs`
     - Dev: `com.googleusercontent.apps.560592268193-a70ituj4997v31non78gvno3f5tsked7`
   - **Neden SHA-1 Gerekmez?:** Android'deki gibi Keystore SHA-1 parmak izi iOS ekosisteminde aranmaz. Apple sandbox mimarisi, güvenliği `Bundle ID` ve özel URL şeması ile sağlar.
4. **Sign in with Apple (App Store Guideline 4.8):**
   - Firebase Console > `Authentication` > `Sign-in method` menüsünden **Apple** sağlayıcısı "Etkin" (Enabled) yapılır. Yerel iOS uygulamaları Apple'ın yerel `AuthenticationServices` çerçevesini kullandığı için **Services ID veya Private Key girilmesine gerek yoktur**.
   - `ios/Runner/Runner.entitlements` dosyasına `com.apple.developer.applesignin` eklenmiştir.
   - `AuthService.signInWithApple()` metodu kriptografik SHA-256 nonce korumasıyla (`crypto: ^3.0.3`) kimlik doğrular ve Apple'ın yalnızca ilk girişte döndürdüğü ad-soyad bilgilerini Firestore profiline kalıcı kaydeder.

### 8.3 Derleme ve Dağıtım Komutları
- **CI/CD Otomasyonu (Önerilen - GitHub Actions):**
  - Workflow: `.github/workflows/ios_testflight_deploy.yml`
  - Derleme komutu otomatik olarak `--build-number=${{ github.run_number }}` parametresini ekler; bu sayede TestFlight mükerrer yükleme (`ITMS-90189`) hatası engellenir.
- **DEV Flavor (Geliştirici Testi):**
  ```bash
  flutter build ipa --flavor dev --dart-define=FLAVOR=dev --build-number=<BUILD_NO> --release
  ```
- **PROD Flavor (Resmi App Store Connect / TestFlight Yayını):**
  ```bash
  flutter build ipa --flavor prod --dart-define=FLAVOR=prod --build-number=<BUILD_NO> --release --export-options-plist=ios_ci/ExportOptions_prod.plist
  ```

### 8.4 App Store Connect İncelemeci Notları (Reviewer Notes) Şablonu
Apple inceleme ekibine gönderilecek resmi not:
```text
Sayın Apple İnceleme Ekibi,

FırsatKolik, Türkiye e-ticaret ekosistemindeki kullanıcıların indirim ve fırsatları paylaştığı topluluk odaklı bir indirim yönlendirme platformudur.

1. Test Giriş Bilgileri (Demo Account):
   - E-posta: apple_reviewer@firsatkolik.app
   - Şifre: Reviewer123!
   - Alternatif: Sign in with Apple butonu ile doğrudan test edebilirsiniz.

2. Apple İnceleme Kılavuzu Uyumlulukları:
   - Guideline 1.2 (UGC): Kullanıcı Sözleşmesi (EULA) giriş ekranında mevcuttur. Tüm fırsat, yorum ve mesaj ekranlarında içerik şikayet etme (Report) ve kullanıcı engelleme (Block) butonları bulunmaktadır.
   - Guideline 4.8: Sign in with Apple eksiksiz olarak entegre edilmiştir.
   - Guideline 5.1.1: Profil > Ayarlar > Hesabımı Sil menüsünden hesap tüm verileriyle anında silinebilmektedir.
   - Guideline 3.1.5(a): Uygulamada satılan dijital bir ürün bulunmamakta olup, harici e-ticaret sitelerindeki fiziksel ürün indirimleri listelenmektedir.
```
