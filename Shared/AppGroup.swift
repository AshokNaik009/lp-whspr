import Foundation

enum AppGroup {
    static let identifier: String = {
        if let id = Bundle.main.object(forInfoDictionaryKey: "LeapAppGroup") as? String, !id.isEmpty {
            return id
        }
        return "group.com.leapwhisper.shared"
    }()

    static let urlScheme = "leapwhisper"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func sessionURL(startWithMode modeID: String?) -> URL {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "session"
        var items = [URLQueryItem(name: "start", value: "1")]
        if let modeID { items.append(URLQueryItem(name: "mode", value: modeID)) }
        components.queryItems = items
        return components.url!
    }
}
