import UIKit
import Social
import MobileCoreServices
import Photos
import UniformTypeIdentifiers

// MARK: - Shared Media Models (receive_sharing_intent uyumlu)

public enum SharedMediaType: String, Codable, CaseIterable {
    case image
    case video
    case text
    case file
    case url

    public var toUTTypeIdentifier: String {
        if #available(iOS 14.0, *) {
            switch self {
            case .image:
                return UTType.image.identifier
            case .video:
                return UTType.movie.identifier
            case .text:
                return UTType.text.identifier
            case .file:
                return UTType.fileURL.identifier
            case .url:
                return UTType.url.identifier
            }
        }
        switch self {
        case .image:
            return "public.image"
        case .video:
            return "public.movie"
        case .text:
            return "public.text"
        case .file:
            return "public.file-url"
        case .url:
            return "public.url"
        }
    }
}

public class SharedMediaFile: Codable {
    var path: String
    var mimeType: String?
    var thumbnail: String?
    var duration: Double?
    var message: String?
    var type: SharedMediaType

    public init(
        path: String,
        mimeType: String? = nil,
        thumbnail: String? = nil,
        duration: Double? = nil,
        message: String? = nil,
        type: SharedMediaType
    ) {
        self.path = path
        self.mimeType = mimeType
        self.thumbnail = thumbnail
        self.duration = duration
        self.message = message
        self.type = type
    }
}

// MARK: - Constants

private let kSchemePrefix = "ShareMedia"
private let kUserDefaultsKey = "ShareKey"
private let kUserDefaultsMessageKey = "ShareMessageKey"

// MARK: - ShareViewController (Self-Contained, Zero External Dependency)

@objc(ShareViewController)
class ShareViewController: SLComposeServiceViewController {
    private let hostAppBundleIdentifier = "com.firsatkolik.app"
    private let appGroupId = "group.com.firsatkolik.app"
    private var sharedMedia: [SharedMediaFile] = []

    override func isContentValid() -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didSelectPost() {
        saveAndRedirect(message: contentText)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let content = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = content.attachments, !attachments.isEmpty else {
            dismissWithError()
            return
        }

        let totalAttachments = attachments.count
        var processedCount = 0

        for attachment in attachments {
            var matched = false
            for type in SharedMediaType.allCases {
                if attachment.hasItemConformingToTypeIdentifier(type.toUTTypeIdentifier) {
                    matched = true
                    attachment.loadItem(forTypeIdentifier: type.toUTTypeIdentifier, options: nil) { [weak self] data, error in
                        guard let self = self, error == nil else {
                            self?.dismissWithError()
                            return
                        }

                        DispatchQueue.main.async {
                            switch type {
                            case .text:
                                if let text = data as? String {
                                    self.handleMedia(forLiteral: text, type: type)
                                }
                            case .url:
                                if let url = data as? URL {
                                    self.handleMedia(forLiteral: url.absoluteString, type: type)
                                }
                            case .image:
                                if let image = data as? UIImage {
                                    self.handleMedia(forUIImage: image, type: type)
                                } else if let url = data as? URL {
                                    self.handleMedia(forFile: url, type: type)
                                }
                            case .video, .file:
                                if let url = data as? URL {
                                    self.handleMedia(forFile: url, type: type)
                                }
                            }

                            processedCount += 1
                            if processedCount >= totalAttachments {
                                self.saveAndRedirect(message: self.contentText)
                            }
                        }
                    }
                    break
                }
            }
            if !matched {
                processedCount += 1
                if processedCount >= totalAttachments {
                    saveAndRedirect(message: contentText)
                }
            }
        }
    }

    private func handleMedia(forLiteral item: String, type: SharedMediaType) {
        sharedMedia.append(SharedMediaFile(
            path: item,
            mimeType: type == .text ? "text/plain" : nil,
            type: type
        ))
    }

    private func handleMedia(forUIImage image: UIImage, type: SharedMediaType) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        let tempPath = groupURL.appendingPathComponent("TempImage_\(UUID().uuidString).png")
        if let data = image.pngData() {
            try? data.write(to: tempPath)
            sharedMedia.append(SharedMediaFile(
                path: tempPath.absoluteString,
                mimeType: "image/png",
                type: type
            ))
        }
    }

    private func handleMedia(forFile url: URL, type: SharedMediaType) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        let fileName = getFileName(from: url, type: type)
        let newPath = groupURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: newPath.path) {
                try FileManager.default.removeItem(at: newPath)
            }
            try FileManager.default.copyItem(at: url, to: newPath)
            sharedMedia.append(SharedMediaFile(
                path: newPath.absoluteString,
                mimeType: url.mimeType(),
                type: type
            ))
        } catch {
            print("Cannot copy file: \(error)")
        }
    }

    private func saveAndRedirect(message: String? = nil) {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        if let encoded = try? JSONEncoder().encode(sharedMedia) {
            userDefaults?.set(encoded, forKey: kUserDefaultsKey)
        }
        userDefaults?.set(message, forKey: kUserDefaultsMessageKey)
        userDefaults?.synchronize()
        redirectToHostApp()
    }

    private func redirectToHostApp() {
        guard let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        var responder: UIResponder? = self
        var opened = false

        if #available(iOS 18.0, *) {
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    opened = true
                    break
                }
                responder = responder?.next
            }
        }

        if !opened {
            let selectorOpenURL = sel_registerName("openURL:")
            var r: UIResponder? = self
            while r != nil {
                if r?.responds(to: selectorOpenURL) == true {
                    _ = r?.perform(selectorOpenURL, with: url)
                    break
                }
                r = r?.next
            }
        }

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func dismissWithError() {
        let alert = UIAlertController(title: "Hata", message: "Paylaşılan içerik okunamadı.", preferredStyle: .alert)
        let action = UIAlertAction(title: "Tamam", style: .cancel) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    private func getFileName(from url: URL, type: SharedMediaType) -> String {
        var name = url.lastPathComponent
        if name.isEmpty {
            switch type {
            case .image: name = "\(UUID().uuidString).png"
            case .video: name = "\(UUID().uuidString).mp4"
            case .text: name = "\(UUID().uuidString).txt"
            default: name = UUID().uuidString
            }
        }
        return name
    }
}

extension URL {
    func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
                return mimeType
            }
        }
        return "application/octet-stream"
    }
}
