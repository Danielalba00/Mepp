import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: "system", content: "Eres un asistente útil especializado en mecánica, proporcionando respuestas precisas y detalladas sobre sistemas automotrices, herramientas y reparaciones.")
    ]
    @Published var isLoading = false
    private let openAIService = OpenAIService()
    
    func sendMessage(content: String) {
        let userMessage = ChatMessage(role: "user", content: content)
        messages.append(userMessage)
        isLoading = true
        
        Task {
            do {
                let response = try await openAIService.sendMessage(messages: messages)
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
                    isLoading = false
                }
            }
        }
    }
}
