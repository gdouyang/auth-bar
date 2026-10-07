import SwiftUI
import AppKit

public struct AddAccountSheet: View {
    @ObservedObject var accountManager: AccountManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    // Manual / Smart input tab
    @State private var accountName = ""
    @State private var issuer = ""
    @State private var secretKey = ""
    @State private var type: OTPType = .totp
    @State private var algorithm: OTPAlgorithm = .sha1
    @State private var digits: Int = 6
    @State private var period: Int = 30

    // URI Tab
    @State private var uriInput = ""
    @State private var errorMessage: String? = nil
    @State private var clipboardPreview: String? = nil

    public init(accountManager: AccountManager) {
        self.accountManager = accountManager
    }

    private var cleanedSecret: String {
        secretKey
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private var isSecretValid: Bool {
        guard !cleanedSecret.isEmpty else { return false }
        guard let data = Base32.decode(cleanedSecret) else { return false }
        return !data.isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("添加双重验证账户")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Picker("", selection: $selectedTab) {
                Text("手动 / 粘贴密钥").tag(0)
                Text("识别二维码").tag(1)
                Text("导入 URI").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 10)

            // Clipboard Quick Import Banner
            if let preview = clipboardPreview {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundColor(.accentColor)
                    Text("剪贴板检测到: \(preview)")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Button("填入") {
                        autoFillFromClipboard()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal)
                .padding(.bottom, 6)
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    if selectedTab == 0 {
                        manualEntryTab
                    } else if selectedTab == 1 {
                        qrScanTab
                    } else {
                        uriImportTab
                    }

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }

            Divider()

            // Bottom action buttons
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if selectedTab == 0 {
                    Button("添加账户") {
                        saveManualAccount()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isSecretValid)
                } else if selectedTab == 2 {
                    Button("解析并导入") {
                        importURI()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(uriInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 450, height: 460)
        .onAppear {
            checkClipboard()
        }
    }

    // MARK: - Subviews

    private var manualEntryTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Secret Key input with Paste button
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("密钥 (Secret Key) *")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: pasteSecretFromClipboard) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.clipboard")
                            Text("从剪贴板粘贴")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                HStack {
                    TextField("例如: JBSWY3DPEHPK3PXP 或直接粘贴 otpauth://", text: $secretKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: secretKey) { _, newValue in
                            handleSecretChanged(newValue)
                        }

                    if !secretKey.isEmpty {
                        Button(action: { secretKey = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Validation status indicator
                if !secretKey.isEmpty {
                    if isSecretValid {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Base32 格式正确")
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("格式有误：Base32 由 A-Z 及 2-7 组成，不含 0, 1, 8, 9")
                                .foregroundColor(.orange)
                        }
                        .font(.caption)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("服务商 / 发行方 (Issuer)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例如: Google, GitHub, AWS, 微软", text: $issuer)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("账户名称 / 邮箱 (Account)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例如: yourname@gmail.com", text: $accountName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("类型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $type) {
                        Text("基于时间 (TOTP)").tag(OTPType.totp)
                        Text("基于计数 (HOTP)").tag(OTPType.hotp)
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("位数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $digits) {
                        Text("6 位").tag(6)
                        Text("8 位").tag(8)
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("算法")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $algorithm) {
                        Text("SHA1").tag(OTPAlgorithm.sha1)
                        Text("SHA256").tag(OTPAlgorithm.sha256)
                        Text("SHA512").tag(OTPAlgorithm.sha512)
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }
            }
        }
    }

    private var qrScanTab: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("快捷扫描与识别")
                    .font(.system(size: 15, weight: .semibold))
                Text("支持直接读取屏幕上的二维码，或选择包含二维码的截图文件。同时支持 Google 迁移二维码 (Transfer accounts)。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 10)

            VStack(spacing: 12) {
                Button(action: scanScreen) {
                    HStack {
                        Image(systemName: "display")
                        Text("一键识别屏幕上的二维码")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: chooseImageFile) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("从截图或图片文件导入...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
        }
    }

    private var uriImportTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("粘贴 otpauth:// 或 otpauth-migration:// 链接:")
                .font(.subheadline)

            TextEditor(text: $uriInput)
                .font(.system(.body, design: .monospaced))
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button("从剪贴板粘贴") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        uriInput = text
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func checkClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return
        }

        if text.lowercased().hasPrefix("otpauth://") {
            clipboardPreview = "otpauth 链接"
        } else if GoogleMigrationDecoder.isMigrationURL(text) {
            clipboardPreview = "Google 迁移码"
        } else {
            let cleaned = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
            if cleaned.count >= 8 && Base32.decode(cleaned) != nil {
                clipboardPreview = "密钥: \(cleaned.prefix(6))..."
            }
        }
    }

    private func autoFillFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        // If it's a migration URL
        if GoogleMigrationDecoder.isMigrationURL(text) {
            let count = accountManager.importFromURLString(text)
            if count > 0 {
                dismiss()
                return
            }
        }

        // If it's an otpauth:// URL
        if let parsed = OTPAuthURL.parse(text) {
            fillFromParsed(parsed)
            return
        }

        // If it's a raw secret
        let cleaned = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if cleaned.count >= 8 && Base32.decode(cleaned) != nil {
            self.secretKey = cleaned
            if self.accountName.isEmpty {
                self.accountName = "新账户"
            }
        }
    }

    private func pasteSecretFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            errorMessage = "剪贴板为空"
            return
        }
        handleSecretChanged(text)
    }

    private func handleSecretChanged(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // If user pasted an otpauth:// URL into the secret field, auto parse all fields!
        if trimmed.lowercased().hasPrefix("otpauth://"), let parsed = OTPAuthURL.parse(trimmed) {
            fillFromParsed(parsed)
            return
        }

        // If user pasted otpauth-migration://
        if GoogleMigrationDecoder.isMigrationURL(trimmed) {
            let count = accountManager.importFromURLString(trimmed)
            if count > 0 {
                dismiss()
                return
            }
        }

        self.secretKey = trimmed
    }

    private func fillFromParsed(_ parsed: OTPAuthParsedData) {
        self.secretKey = parsed.secret
        self.issuer = parsed.issuer
        self.accountName = parsed.accountName
        self.type = parsed.type
        self.algorithm = parsed.algorithm
        self.digits = parsed.digits
        self.period = parsed.period
        self.errorMessage = nil
    }

    private func scanScreen() {
        errorMessage = nil
        let result = accountManager.importFromScreenQR()
        if result.count > 0 {
            dismiss()
        } else {
            errorMessage = result.error ?? "未能识别屏幕二维码"
        }
    }

    private func chooseImageFile() {
        errorMessage = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .image]

        if panel.runModal() == .OK, let url = panel.url {
            let result = accountManager.importFromImageFile(url: url)
            if result.count > 0 {
                dismiss()
            } else {
                errorMessage = result.error ?? "未能识别图片中的二维码"
            }
        }
    }

    private func saveManualAccount() {
        errorMessage = nil
        guard isSecretValid else {
            errorMessage = "密钥不是有效的 Base32 编码，请检查"
            return
        }

        var finalName = accountName.trimmingCharacters(in: .whitespaces)
        let finalIssuer = issuer.trimmingCharacters(in: .whitespaces)

        if finalName.isEmpty {
            finalName = !finalIssuer.isEmpty ? finalIssuer : "我的验证账户"
        }

        let item = AccountItem(
            accountName: finalName,
            issuer: finalIssuer,
            secret: cleanedSecret,
            algorithm: algorithm,
            digits: digits,
            type: type,
            period: period
        )
        accountManager.addAccount(item)
        dismiss()
    }

    private func importURI() {
        errorMessage = nil
        let count = accountManager.importFromURLString(uriInput)
        if count > 0 {
            dismiss()
        } else {
            errorMessage = "无法解析该 URI，请确认格式是否为 otpauth:// 或 otpauth-migration://"
        }
    }
}
