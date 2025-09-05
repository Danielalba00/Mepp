import Foundation

struct OpenAIRequest: Codable {
    let model: String
    let messages: [ChatMessage]
}
