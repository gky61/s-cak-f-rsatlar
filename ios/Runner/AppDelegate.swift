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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // iOS 10+ Ön plan bildirim sunumu (Foreground Notification Presentation)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
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
