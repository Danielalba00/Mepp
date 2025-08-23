import Foundation

class APIKeyManager {
    static func getAPIKey() -> String? {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let apiKey = config["OpenAIAPIKey"] as? String {
            return apiKey
        }
        return nil
    }
}
