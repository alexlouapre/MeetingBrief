import Foundation

enum SecretStore {
    private static let fileManager = FileManager.default

    private static var fileURL: URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("MeetingBrief", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        return dir.appendingPathComponent("secrets.json")
    }

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private static func save(_ dict: [String: String]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    static func set(_ value: String, for key: String) {
        var dict = load()
        dict[key] = value
        save(dict)
    }

    static func get(_ key: String) -> String? {
        let v = load()[key]
        return (v?.isEmpty ?? true) ? nil : v
    }

    static func delete(_ key: String) {
        var dict = load()
        dict.removeValue(forKey: key)
        save(dict)
    }
}
