import Foundation

class OpenAIService {
    private let apiKey: String = {
        APIKeyManager.getAPIKey() ?? "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"
    }()
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func sendMessage(messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = OpenAIRequest(model: "gpt-4o-mini", messages: messages)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return decodedResponse.choices.first?.message.content ?? "Sin respuesta"
    }
}
