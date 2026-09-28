import Flutter
import UIKit
import UserNotifications
import google_mobile_ads

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

    if let controller = window?.rootViewController as? FlutterViewController {
      let nativeHttpChannel = FlutterMethodChannel(
        name: "com.sicakfirsatlar.app/native_http",
        binaryMessenger: controller.binaryMessenger
      )

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

      // iOS Uygulama İkonu Bildirim Rozeti (App Icon Badge) Kanalı
      let badgeChannel = FlutterMethodChannel(
        name: "com.sicakfirsatlar.app/badge",
        binaryMessenger: controller.binaryMessenger
      )

      badgeChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "setBadge" {
          let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 0
          DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
            if #available(iOS 16.0, *) {
              UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
            }
            result(true)
          }
        } else if call.method == "clearBadge" {
          DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            if #available(iOS 16.0, *) {
              UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
            result(true)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }

    // Google Mobile Ads — iOS Özel Native Reklam Fabrikası (FLTNativeAdFactory)
    // 120x120 pt MediaView ve güvenli AutoLayout sınırlarıyla hem "MediaView is too small for video"
    // hem de "Advertiser assets outside native ad view" uyarılarını kalıcı olarak çözer.
    let nativeAdFactory = FirsatKolikNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "firsatkolik_native_ad_factory",
      nativeAdFactory: nativeAdFactory
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // iOS 10+ Ön plan bildirim sunumu (Foreground Notification Presentation)
  // Birebir sohbet mesajları ve admin mesajları uygulama açıkken Flutter tarafında InAppMessageBanner ile sunulur.
  // Ön plandayken Apple sistem push bildiriminin (tepe banner) basılmasını engelle (çift bildirim önleyici).
  // Diğer bildirimler (fırsat, kupon, yorum vb.) için iOS native banner sunumu kullanılır.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    let type = (userInfo["type"] as? String) ?? ""
    let category = notification.request.content.categoryIdentifier

    let isChatMessage = type == "message" || type == "user_message" || type == "chat" || category == "USER_MESSAGE" || (userInfo["senderId"] != nil && type != "deal" && type != "comment_reply" && type != "admin_deal")
    let isAdminMessage = type == "admin_message" || category == "ADMIN_MESSAGE"

    if isChatMessage || isAdminMessage {
      completionHandler([])
      return
    }

    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  // iOS Bildirim Tıklama Yanıtı (Notification Tap Response)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  // APNs Cihaz Token Kaydı (Device Token Registration)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

// MARK: - FırsatKolik iOS Native Ad Factory (Enterprise-Grade Custom Native Ad)
/// AdMob Native Ad Validator uyumlu kurumsal Native Reklam Fabrikası.
/// Google'ın varsayılan GADTSmallTemplateView.xib şablonundaki yapısal kısıtları (0.25 genişlik çarpanı)
/// ve subpixel AutoLayout taşmalarını aşarak 0 validator hatası ile çalışır:
/// 1. 120 x 120 pt ölçüsünde kilitlenmiş GADMediaView ile "MediaView is too small for video" uyarısını yok eder.
/// 2. İçerik bileşenlerini (başlık, reklam rozeti, reklamveren, CTA butonu) 10-12 pt güvenli iç boşlukla
///    GADNativeAdView sınırları içine hapsederek "Advertiser assets outside native ad view" uyarısını sıfırlar.
class FirsatKolikNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: GADNativeAd,
    customOptions: [AnyHashable: Any]?
  ) -> GADNativeAdView? {
    let isDark = (customOptions?["isDark"] as? Bool) ?? false

    // 1. Kök Görünüm (Root GADNativeAdView)
    let nativeAdView = GADNativeAdView()
    nativeAdView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // Tema Renkleri
    let surfaceColor = isDark
      ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // AppTheme.darkSurface (#1C1C1E)
      : UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0) // AppTheme.lightBackground (#F1F5F9)
    let borderColor = isDark
      ? UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1.0) // #3A3A3C
      : UIColor(red: 0.80, green: 0.84, blue: 0.88, alpha: 1.0) // #CBD5E1
    let primaryTextColor = isDark ? UIColor.white : UIColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1.0)
    let secondaryTextColor = isDark ? UIColor(red: 0.60, green: 0.60, blue: 0.63, alpha: 1.0) : UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1.0)
    let brandOrange = UIColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1.0) // #FF6B00 FırsatKolik Primary

    nativeAdView.backgroundColor = surfaceColor
    nativeAdView.layer.borderColor = borderColor.cgColor
    nativeAdView.layer.borderWidth = 1.0
    nativeAdView.layer.cornerRadius = 16.0
    nativeAdView.clipsToBounds = true

    // 2. Sol Bölüm: Medya & Görsel Taşıyıcı (Media Container - Tam 120 x 120 pt)
    let mediaContainer = UIView()
    mediaContainer.translatesAutoresizingMaskIntoConstraints = false
    mediaContainer.backgroundColor = isDark ? UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0) : UIColor.white
    mediaContainer.layer.cornerRadius = 12.0
    mediaContainer.clipsToBounds = true
    mediaContainer.layer.borderColor = borderColor.cgColor
    mediaContainer.layer.borderWidth = 1.0
    nativeAdView.addSubview(mediaContainer)

    let mediaView = GADMediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.contentMode = .scaleAspectFill
    mediaView.clipsToBounds = true
    mediaContainer.addSubview(mediaView)

    // İkon Görseli (Medya içeriği yoksa veya sadece logo gelmişse fallback)
    let iconImageView = UIImageView()
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    iconImageView.contentMode = .scaleAspectFit
    iconImageView.clipsToBounds = true
    if let icon = nativeAd.icon?.image {
      iconImageView.image = icon
      iconImageView.isHidden = false
    } else {
      iconImageView.isHidden = true
    }
    mediaContainer.addSubview(iconImageView)

    // Medya Taşıyıcı Kısıtları (Constraints)
    let mediaWidth = mediaContainer.widthAnchor.constraint(equalToConstant: 120)
    let mediaHeight = mediaContainer.heightAnchor.constraint(equalToConstant: 120)
    mediaWidth.priority = UILayoutPriority(999)
    mediaHeight.priority = UILayoutPriority(999)

    NSLayoutConstraint.activate([
      mediaContainer.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 10),
      mediaContainer.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 10),
      mediaContainer.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -10),
      mediaWidth,
      mediaHeight,

      mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
      mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
      mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
      mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),

      iconImageView.centerXAnchor.constraint(equalTo: mediaContainer.centerXAnchor),
      iconImageView.centerYAnchor.constraint(equalTo: mediaContainer.centerYAnchor),
      iconImageView.widthAnchor.constraint(equalTo: mediaContainer.widthAnchor, multiplier: 0.8),
      iconImageView.heightAnchor.constraint(equalTo: mediaContainer.heightAnchor, multiplier: 0.8),
    ])

    mediaView.mediaContent = nativeAd.mediaContent
    nativeAdView.mediaView = mediaView
    if nativeAd.icon != nil {
      nativeAdView.iconView = iconImageView
    }

    // 3. Sağ Bölüm: İçerik Taşıyıcı (Content Container)
    let contentContainer = UIView()
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    nativeAdView.addSubview(contentContainer)

    let headlineLabel = UILabel()
    headlineLabel.translatesAutoresizingMaskIntoConstraints = false
    headlineLabel.text = nativeAd.headline
    headlineLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
    headlineLabel.textColor = primaryTextColor
    headlineLabel.numberOfLines = 2
    headlineLabel.lineBreakMode = .byTruncatingTail
    contentContainer.addSubview(headlineLabel)
    nativeAdView.headlineView = headlineLabel

    // Rozet ve Reklamveren Satırı (Attribution Row)
    let attributionRow = UIView()
    attributionRow.translatesAutoresizingMaskIntoConstraints = false
    contentContainer.addSubview(attributionRow)

    let adBadge = UILabel()
    adBadge.translatesAutoresizingMaskIntoConstraints = false
    adBadge.text = "Reklam"
    adBadge.font = UIFont.systemFont(ofSize: 9.5, weight: .bold)
    adBadge.textColor = UIColor(red: 0.23, green: 0.40, blue: 0.16, alpha: 1.0)
    adBadge.textAlignment = .center
    adBadge.layer.borderColor = adBadge.textColor.cgColor
    adBadge.layer.borderWidth = 1.0
    adBadge.layer.cornerRadius = 3.0
    adBadge.layer.masksToBounds = true
    attributionRow.addSubview(adBadge)

    let advertiserLabel = UILabel()
    advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
    var advertiserText = nativeAd.advertiser ?? nativeAd.store ?? ""
    if let starRating = nativeAd.starRating, starRating.doubleValue > 0 {
      let stars = String(repeating: "★", count: min(5, starRating.intValue))
      advertiserText = advertiserText.isEmpty ? stars : "\(advertiserText) • \(stars)"
    }
    advertiserLabel.text = advertiserText
    advertiserLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
    advertiserLabel.textColor = secondaryTextColor
    advertiserLabel.numberOfLines = 1
    advertiserLabel.lineBreakMode = .byTruncatingTail
    attributionRow.addSubview(advertiserLabel)
    nativeAdView.advertiserView = advertiserLabel

    // CTA Butonu
    let ctaButton = UIButton(type: .custom)
    ctaButton.translatesAutoresizingMaskIntoConstraints = false
    ctaButton.backgroundColor = brandOrange
    ctaButton.setTitle(nativeAd.callToAction ?? "Fırsatı Gör", for: .normal)
    ctaButton.setTitleColor(UIColor.white, for: .normal)
    ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
    ctaButton.layer.cornerRadius = 14.0
    ctaButton.clipsToBounds = true
    ctaButton.isUserInteractionEnabled = false // GADNativeAdView dokunma/tıklama yönetimini devralır
    contentContainer.addSubview(ctaButton)
    nativeAdView.callToActionView = ctaButton

    // İçerik Kısıtları (Content Layout Constraints)
    NSLayoutConstraint.activate([
      contentContainer.leadingAnchor.constraint(equalTo: mediaContainer.trailingAnchor, constant: 12),
      contentContainer.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
      contentContainer.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 10),
      contentContainer.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -10),

      headlineLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor),
      headlineLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
      headlineLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

      attributionRow.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
      attributionRow.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
      attributionRow.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
      attributionRow.heightAnchor.constraint(equalToConstant: 16),

      adBadge.leadingAnchor.constraint(equalTo: attributionRow.leadingAnchor),
      adBadge.centerYAnchor.constraint(equalTo: attributionRow.centerYAnchor),
      adBadge.widthAnchor.constraint(equalToConstant: 44),
      adBadge.heightAnchor.constraint(equalToConstant: 16),

      advertiserLabel.leadingAnchor.constraint(equalTo: adBadge.trailingAnchor, constant: 6),
      advertiserLabel.trailingAnchor.constraint(lessThanOrEqualTo: attributionRow.trailingAnchor),
      advertiserLabel.centerYAnchor.constraint(equalTo: attributionRow.centerYAnchor),

      ctaButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
      ctaButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
      ctaButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
      ctaButton.heightAnchor.constraint(equalToConstant: 28),
      ctaButton.topAnchor.constraint(greaterThanOrEqualTo: attributionRow.bottomAnchor, constant: 4),
    ])

    nativeAdView.nativeAd = nativeAd
    return nativeAdView
  }
}
