import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
public final class AccountManager: ObservableObject {
    public static let shared = AccountManager()

    @Published public var accounts: [AccountItem] = []
    @Published public var searchText: String = ""
    @Published public var secondsRemaining: Int = 30
    @Published public var progress: Double = 1.0
    @Published public var toastMessage: String? = nil
    @Published public var settings: AppSettings

    private var timerCancellable: AnyCancellable?
    private var toastDismissWorkItem: DispatchWorkItem?

    private init() {
        self.settings = StorageManager.shared.loadSettings()
        self.accounts = StorageManager.shared.loadAccounts()

        // If newly created and no accounts, add a friendly sample if desired, or leave empty
        startTimer()
    }

    public var filteredAccounts: [AccountItem] {
        var list = accounts
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let term = searchText.lowercased()
            list = list.filter {
                $0.accountName.lowercased().contains(term) ||
                $0.issuer.lowercased().contains(term)
            }
        }

        if settings.sortAlphabetically {
            list.sort {
                let name1 = $0.issuer.isEmpty ? $0.accountName : $0.issuer
                let name2 = $1.issuer.isEmpty ? $1.accountName : $1.issuer
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }

        // Pinned accounts always appear on top
        return list.sorted { (a1, a2) -> Bool in
            if a1.pinned != a2.pinned {
                return a1.pinned && !a2.pinned
            }
            return false
        }
    }

    private func startTimer() {
        updateProgress()
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateProgress()
            }
    }

    private func updateProgress() {
        let now = Date()
        let rem = OTPGenerator.remainingSeconds(date: now, period: 30)
        let prog = OTPGenerator.progress(date: now, period: 30)
        self.secondsRemaining = rem
        self.progress = prog
    }

    public func addAccount(_ account: AccountItem) {
        accounts.append(account)
        save()
        showToast("已添加「\(account.displayTitle)」")
    }

    public func updateAccount(_ account: AccountItem) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            save()
            showToast("已更新「\(account.displayTitle)」")
        }
    }

    public func deleteAccount(id: UUID) {
        if let item = accounts.first(where: { $0.id == id }) {
            accounts.removeAll { $0.id == id }
            save()
            showToast("已删除「\(item.displayTitle)」")
        }
    }

    public func togglePin(id: UUID) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].pinned.toggle()
            save()
        }
    }

    public func incrementCounter(id: UUID) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].counter += 1
            save()
        }
    }

    public func copyCode(for account: AccountItem) {
        let code = account.code()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        showToast("已复制: \(account.formattedCode())")

        if settings.autoHideAfterCopy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.keyWindow?.orderOut(nil)
            }
        }
    }

    public func showToast(_ message: String) {
        toastDismissWorkItem?.cancel()
        toastMessage = message

        let item = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    public func save() {
        StorageManager.shared.saveAccounts(accounts)
        StorageManager.shared.saveSettings(settings)
    }

    // MARK: - Import & Export

    public func importFromURLString(_ string: String) -> Int {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a migration URI
        if GoogleMigrationDecoder.isMigrationURL(trimmed) {
            let migrated = GoogleMigrationDecoder.decode(trimmed)
            guard !migrated.isEmpty else { return 0 }
            for m in migrated {
                let item = AccountItem(
                    accountName: m.name,
                    issuer: m.issuer,
                    secret: m.secretBase32,
                    algorithm: m.algorithm,
                    digits: m.digits,
                    type: m.type,
                    counter: m.counter
                )
                accounts.append(item)
            }
            save()
            showToast("成功导入 \(migrated.count) 个 Google 验证账户")
            return migrated.count
        }

        // Standard otpauth://
        if let parsed = OTPAuthURL.parse(trimmed) {
            let item = AccountItem(
                accountName: parsed.accountName,
                issuer: parsed.issuer,
                secret: parsed.secret,
                algorithm: parsed.algorithm,
                digits: parsed.digits,
                type: parsed.type,
                period: parsed.period,
                counter: parsed.counter
            )
            accounts.append(item)
            save()
            showToast("成功导入「\(item.displayTitle)」")
            return 1
        }

        return 0
    }

    public func importFromScreenQR() -> (count: Int, error: String?) {
        let codes = BarcodeScanner.scanScreenForQRCodes()
        guard !codes.isEmpty else {
            return (0, "屏幕上未检测到二维码，请确保二维码在屏幕上清晰可见")
        }

        var importedCount = 0
        for code in codes {
            importedCount += importFromURLString(code)
        }

        if importedCount > 0 {
            return (importedCount, nil)
        } else {
            return (0, "已检测到二维码，但不是支持的 OTP/Google Authenticator 格式")
        }
    }

    public func importFromImageFile(url: URL) -> (count: Int, error: String?) {
        guard let image = NSImage(contentsOf: url) else {
            return (0, "无法打开所选图片文件")
        }
        let codes = BarcodeScanner.detectQRCode(in: image)
        guard !codes.isEmpty else {
            return (0, "图片中未找到二维码")
        }

        var count = 0
        for code in codes {
            count += importFromURLString(code)
        }

        if count > 0 {
            return (count, nil)
        } else {
            return (0, "图片中的二维码不是有效的验证码 URI")
        }
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(accounts),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    public func importJSON(_ jsonString: String) -> (count: Int, error: String?) {
        guard let data = jsonString.data(using: .utf8) else {
            return (0, "无效的 JSON 数据")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let imported = try decoder.decode([AccountItem].self, from: data)
            guard !imported.isEmpty else { return (0, "导入列表中没有账户") }

            for item in imported {
                // avoid duplicate ID
                var newItem = item
                if accounts.contains(where: { $0.id == item.id }) {
                    newItem.id = UUID()
                }
                accounts.append(newItem)
            }
            save()
            showToast("成功导入 \(imported.count) 个账户")
            return (imported.count, nil)
        } catch {
            return (0, "JSON 解析失败: \(error.localizedDescription)")
        }
    }
}
