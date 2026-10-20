import Foundation

/// Fork-only signing support; never falls back to the App Store app's group.
public enum DevAppIdentity {
    public static let baseGroup = "group.io.github.h4m4chi-ttr.azookey.dev.a159b2"
    public static let urlScheme = "azooKeyDev"

    public static var keyboardBundleIdentifier: String {
        if Bundle.main.bundleURL.pathExtension == "appex" {
            return Bundle.main.bundleIdentifier ?? ""
        }
        if let plugins = Bundle.main.builtInPlugInsURL,
           let keyboard = Bundle(url: plugins.appendingPathComponent("Keyboard.appex")),
           let identifier = keyboard.bundleIdentifier {
            return identifier
        }
        return Bundle.main.object(forInfoDictionaryKey: "AzooKeyKeyboardBundleIdentifier") as? String ?? ""
    }

    public static func isDevelopmentGroup(_ identifier: String) -> Bool {
        identifier == baseGroup || identifier.hasPrefix(baseGroup + ".")
    }

    public static let appGroup: String = {
        // AltStore writes the actual profile groups into each re-signed bundle.
        let altGroups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        let profileGroups = provisioningGroups()
        let candidates = (profileGroups + altGroups + [baseGroup]).filter(isDevelopmentGroup)
        return candidates.first {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
        } ?? baseGroup
    }()

    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    private static func provisioningGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), options: [], in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: data.subdata(in: start.lowerBound..<end.upperBound), options: 0, format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else {
            return []
        }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }
}
