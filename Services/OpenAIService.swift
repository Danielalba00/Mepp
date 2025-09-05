import Foundation

struct OpenAIChatMessage: Codable { let role: String; let content: String }
struct OpenAIChatRequest: Codable { let model: String; let messages: [OpenAIChatMessage] }
struct OpenAIChatChoice: Codable {
    struct Msg: Codable { let role: String; let content: String }
    let index: Int
    let message: Msg
}
struct OpenAIChatResponse: Codable { let choices: [OpenAIChatChoice] }

final class OpenAIService {
    // Configura timeouts para evitar “congelados”
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20      // ⏱️ 20s por request
        cfg.timeoutIntervalForResource = 20
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()
    
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    // Wrapper de compatibilidad si lo llamas como .chat(...)
    func chat(messages: [ChatMessage]) async throws -> OpenAIChatResponse {
        try await sendMessage(messages: messages)
    }
    
    func sendMessage(messages: [ChatMessage]) async throws -> OpenAIChatResponse {
        guard let apiKey = APIKeyManager.getOpenAIKey(), !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIService", code: -1000,
                          userInfo: [NSLocalizedDescriptionKey: "OPENAI_API_KEY no disponible"])
        }
        
        // Construye el payload
        let payload = OpenAIChatRequest(
            model: "gpt-4o-mini", // ajusta al modelo que tengas habilitado
            messages: messages.map { OpenAIChatMessage(role: $0.role, content: $0.content) }
        )
        
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(payload)
        
        // 📋 Logs mínimos para diagnosticar
#if DEBUG
        print("➡️ POST \(endpoint.absoluteString)")
#endif
        
        let (data, resp) = try await OpenAIService.session.data(for: req)
        
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIService", code: -1001,
                          userInfo: [NSLocalizedDescriptionKey: "Respuesta HTTP inválida"])
        }
        
#if DEBUG
        let bodyStr = String(data: data, encoding: .utf8) ?? "<no utf8>"
        print("⬅️ \(http.statusCode) | \(bodyStr.prefix(400))")
#endif
        
        // Si no es 2xx, lanza error con el cuerpo para verlo en UI
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<sin cuerpo>"
            throw NSError(domain: "OpenAIService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode). Body: \(body)"])
        }
        
        return try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
    }
}

