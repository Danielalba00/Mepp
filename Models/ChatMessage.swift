import Foundation

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let role: String
    let content: String
}
