import Foundation

struct ChatMessage: Identifiable, Codable {
    var id = UUID()   // ahora es var → el decoder puede sobrescribirlo
    let role: String
    let content: String
}

