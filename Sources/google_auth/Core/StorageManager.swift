import Foundation

@MainActor
public final class StorageManager {
    public static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let appSupportDirectory: URL

    private var accountsFileURL: URL {
        appSupportDirectory.appendingPathComponent("accounts.json")
    }

    private var settingsFileURL: URL {
        appSupportDirectory.appendingPathComponent("settings.json")
    }

    private init() {
        if let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.appSupportDirectory = baseDir.appendingPathComponent("GoogleAuthenticatorMac", isDirectory: true)
        } else {
            self.appSupportDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".google_authenticator_mac")
        }

        try? fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true, attributes: [
            FileAttributeKey.posixPermissions: 0o700
        ])
    }

    public func loadAccounts() -> [AccountItem] {
        guard fileManager.fileExists(atPath: accountsFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: accountsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AccountItem].self, from: data)
        } catch {
            print("Error loading accounts: \(error)")
            return []
        }
    }

    public func saveAccounts(_ accounts: [AccountItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(accounts)
            try data.write(to: accountsFileURL, options: .atomic)
            // Ensure 0600 permissions
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: accountsFileURL.path)
        } catch {
            print("Error saving accounts: \(error)")
        }
    }

    public func loadSettings() -> AppSettings {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            return AppSettings()
        }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    public func saveSettings(_ settings: AppSettings) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("Error saving settings: \(error)")
        }
    }
}
