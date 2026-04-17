import Foundation

enum SlackError: Error, LocalizedError {
    case missingToken
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Slack bot token manquant. Configure-le dans Réglages."
        case .apiError(let m): return "Erreur Slack : \(m)"
        }
    }
}

struct SlackService {
    static func listChannels() async throws -> [SlackChannel] {
        guard let token = Keychain.get("slack_bot_token"), !token.isEmpty else {
            throw SlackError.missingToken
        }

        var all: [SlackChannel] = []
        var cursor: String? = nil
        repeat {
            var components = URLComponents(string: "https://slack.com/api/conversations.list")!
            var items: [URLQueryItem] = [
                URLQueryItem(name: "limit", value: "200"),
                URLQueryItem(name: "exclude_archived", value: "true"),
                URLQueryItem(name: "types", value: "public_channel,private_channel")
            ]
            if let c = cursor, !c.isEmpty {
                items.append(URLQueryItem(name: "cursor", value: c))
            }
            components.queryItems = items

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            struct Resp: Codable {
                let ok: Bool
                let error: String?
                let channels: [Chan]?
                let response_metadata: Meta?
                struct Chan: Codable { let id: String; let name: String }
                struct Meta: Codable { let next_cursor: String? }
            }
            let r = try JSONDecoder().decode(Resp.self, from: data)
            if !r.ok { throw SlackError.apiError(r.error ?? "unknown") }
            all.append(contentsOf: (r.channels ?? []).map { SlackChannel(id: $0.id, name: $0.name) })
            cursor = r.response_metadata?.next_cursor
        } while cursor != nil && !(cursor?.isEmpty ?? true)

        return all.sorted { $0.name < $1.name }
    }

    static func postMessage(channelId: String, text: String) async throws {
        guard let token = Keychain.get("slack_bot_token"), !token.isEmpty else {
            throw SlackError.missingToken
        }
        let body: [String: Any] = [
            "channel": channelId,
            "text": text
        ]
        var request = URLRequest(url: URL(string: "https://slack.com/api/chat.postMessage")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct Resp: Codable { let ok: Bool; let error: String? }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        if !r.ok { throw SlackError.apiError(r.error ?? "unknown") }
    }
}
