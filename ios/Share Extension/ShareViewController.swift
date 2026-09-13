import UIKit
import Social
import MobileCoreServices
import Photos
import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    /// Host uygulamanın bundle identifier bilgisi
    override func getHostAppBundleId() -> String {
        return "com.firsatkolik.app"
    }

    /// Host uygulama ile Share Extension arasındaki App Group tanıtıcısı
    override func getAppGroupId() -> String {
        return "group.com.firsatkolik.app"
    }
}
