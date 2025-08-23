import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: "system", content: "Eres un asistente útil especializado en mecánica, proporcionando respuestas precisas y detalladas sobre sistemas automotrices, herramientas y reparaciones.")
    ]
    @Published var isLoading = false
    private let openAIService = OpenAIService()
    private var csvContent: String? // Almacenar el contenido del CSV como referencia
    
    func sendMessage(content: String) {
        let userMessage = ChatMessage(role: "user", content: content)
        messages.append(userMessage)
        isLoading = true
        
        // Incluir el contenido del CSV como contexto, si existe
        var apiMessages = messages
        if let csv = csvContent {
            apiMessages.insert(ChatMessage(role: "system", content: "Contexto del CSV cargado:\n\(csv)"), at: 0)
        }
        
        Task {
            do {
                let response = try await openAIService.sendMessage(messages: apiMessages)
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
    
    func loadCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            DispatchQueue.main.async {
                self.messages.append(ChatMessage(role: "system", content: "Archivo CSV cargado como referencia."))
                self.isLoading = false
            }
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            // Reemplazar valores "null" con "0"
            let processedContent = content.replacingOccurrences(of: "null", with: "0")
            DispatchQueue.main.async {
                self.csvContent = processedContent
                self.messages.append(ChatMessage(role: "system", content: "Archivo CSV cargado como referencia."))
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.messages.append(ChatMessage(role: "system", content: "Error al cargar el CSV: \(error.localizedDescription)"))
                self.isLoading = false
            }
        }
    }
}
