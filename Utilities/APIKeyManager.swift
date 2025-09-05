import Foundation
import UIKit // o SwiftUI, cualquiera te da Bundle.main en app iOS

enum APIKeyManager {
    static func getOpenAIKey() -> String? {
        // 1) Buscar en Info.plist (Custom iOS Target Properties)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        // 2) Buscar en Config.plist del bundle
        if let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = plist["OPENAI_API_KEY"] as? String,
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        return nil
    }
    
    // Debug opcional
    static func debugPrintStatus() {
        print("📦 Bundle:", Bundle.main.bundlePath)
        print("ℹ️ Info OPENAI_API_KEY:", Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? "nil")
        print("📄 Config.plist:", Bundle.main.url(forResource: "Config", withExtension: "plist")?.path ?? "nil")
    }
}

