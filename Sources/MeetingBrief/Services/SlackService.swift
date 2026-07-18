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
    /// Fetches both channels and users. If users.list fails (e.g., missing scope), returns
    /// channels only plus a non-fatal error message the UI can surface for diagnostics.
    static func listDestinations() async throws -> (items: [SlackChannel], usersError: String?) {
        let channels = try await listChannels()
        do {
            let users = try await listUsers()
            return (channels + users, nil)
        } catch {
            return (channels, error.localizedDescription)
        }
    }

    static func listChannels() async throws -> [SlackChannel] {
        guard let token = SecretStore.get("slack_bot_token"), !token.isEmpty else {
            throw SlackError.missingToken
        }

        var all: [SlackChannel] = []
        var cursor: String? = nil
        while true {
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
            request.timeoutInterval = 30
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            try checkHTTP(response: response, data: data, context: "conversations.list")

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
            all.append(contentsOf: (r.channels ?? []).map {
                SlackChannel(id: $0.id, name: $0.name, kind: .channel)
            })

            guard let next = r.response_metadata?.next_cursor, !next.isEmpty else { break }
            cursor = next
        }

        return all.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    static func listUsers() async throws -> [SlackChannel] {
        guard let token = SecretStore.get("slack_bot_token"), !token.isEmpty else {
            throw SlackError.missingToken
        }

        var all: [SlackChannel] = []
        var cursor: String? = nil
        while true {
            var components = URLComponents(string: "https://slack.com/api/users.list")!
            var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "200")]
            if let c = cursor, !c.isEmpty {
                items.append(URLQueryItem(name: "cursor", value: c))
            }
            components.queryItems = items

            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 30
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            try checkHTTP(response: response, data: data, context: "users.list")

            struct Resp: Codable {
                let ok: Bool
                let error: String?
                let members: [Member]?
                let response_metadata: Meta?
                struct Member: Codable {
                    let id: String
                    let name: String
                    let real_name: String?
                    let deleted: Bool?
                    let is_bot: Bool?
                    let profile: Profile?
                    struct Profile: Codable {
                        let display_name_normalized: String?
                        let real_name_normalized: String?
                    }
                }
                struct Meta: Codable { let next_cursor: String? }
            }
            let r = try JSONDecoder().decode(Resp.self, from: data)
            if !r.ok { throw SlackError.apiError(r.error ?? "unknown") }

            for m in (r.members ?? []) {
                if m.deleted == true { continue }
                if m.is_bot == true { continue }
                if m.id == "USLACKBOT" { continue }

                let displayName: String
                if let dn = m.profile?.display_name_normalized, !dn.isEmpty {
                    displayName = dn
                } else if let rn = m.profile?.real_name_normalized, !rn.isEmpty {
                    displayName = rn
                } else if let rn = m.real_name, !rn.isEmpty {
                    displayName = rn
                } else {
                    displayName = m.name
                }

                all.append(SlackChannel(id: m.id, name: displayName, kind: .user))
            }

            guard let next = r.response_metadata?.next_cursor, !next.isEmpty else { break }
            cursor = next
        }

        return all.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    static func postMessage(channelId: String, text: String) async throws {
        guard let token = SecretStore.get("slack_bot_token"), !token.isEmpty else {
            throw SlackError.missingToken
        }
        let body: [String: Any] = [
            "channel": channelId,
            "text": text
        ]
        var request = URLRequest(url: URL(string: "https://slack.com/api/chat.postMessage")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data, context: "chat.postMessage")

        struct Resp: Codable { let ok: Bool; let error: String? }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        if !r.ok { throw SlackError.apiError(r.error ?? "unknown") }
    }

    private static func checkHTTP(response: URLResponse, data: Data, context: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw SlackError.apiError("\(context) HTTP \(http.statusCode) — \(body)")
        }
    }
}
