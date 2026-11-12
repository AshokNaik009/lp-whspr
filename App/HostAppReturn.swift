import UIKit

/// After the keyboard opens the app to start the mic, jump back to the app the user was typing in.
/// iOS has no public "go back" API, so this only works for host apps with a known URL scheme;
/// otherwise the user taps the ◀ breadcrumb.
enum HostAppReturn {
    private static let schemes: [String: String] = [
        "net.whatsapp.WhatsApp": "whatsapp://",
        "net.whatsapp.WhatsAppSMB": "whatsapp-smb://",
        "ph.telegra.Telegraph": "tg://",
        "com.tinyspeck.chatlyio": "slack://",
        "com.microsoft.skype.teams": "msteams://",
        "com.google.Gmail": "googlegmail://",
        "com.microsoft.Office.Outlook": "ms-outlook://",
        "com.apple.mobilenotes": "mobilenotes://",
        "com.apple.mobilemail": "message://",
        "com.google.chrome.ios": "googlechrome://",
        "com.atebits.Tweetie2": "twitter://",
        "com.burbn.instagram": "instagram://",
        "com.facebook.Messenger": "fb-messenger://",
        "com.linkedin.LinkedIn": "linkedin://",
        "com.openai.chat": "chatgpt://",
        "notion.id": "notion://",
    ]

    static func url(forHost bundleID: String?) -> URL? {
        guard let bundleID, let scheme = schemes[bundleID] else { return nil }
        return URL(string: scheme)
    }

    /// Returns false when the host is unknown, so the UI can show the swipe-back hint instead.
    @MainActor
    @discardableResult
    static func goBack(to bundleID: String?) -> Bool {
        guard let url = url(forHost: bundleID) else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
