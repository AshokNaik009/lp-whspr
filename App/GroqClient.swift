import Foundation

enum GroqError: LocalizedError {
    case missingAPIKey
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Groq API key in Settings."
        case .http(let code, let body): return "Groq request failed (\(code)): \(body.prefix(200))"
        }
    }
}

struct GroqClient {
    var apiKey: String
    private let base = URL(string: "https://api.groq.com/openai/v1")!

    func transcribe(wav: Data, model: String, language: String?, prompt: String?) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("audio/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let boundary = "LeapWhisper-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("model", model)
        field("response_format", "json")
        field("temperature", "0")
        if let language, language != "auto", !language.isEmpty { field("language", language) }
        if let prompt, !prompt.isEmpty { field("prompt", prompt) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(wav)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body

        struct Response: Decodable { let text: String }
        return try await send(request, as: Response.self).text
    }

    func complete(system: String, user: String, model: String) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        return try await send(request, as: Response.self).choices.first?.message.content ?? ""
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw GroqError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(type, from: data)
    }
}
