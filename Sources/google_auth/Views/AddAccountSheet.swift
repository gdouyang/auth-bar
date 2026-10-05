import SwiftUI
import AppKit

public struct AddAccountSheet: View {
    @ObservedObject var accountManager: AccountManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    // Manual tab
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

    public init(accountManager: AccountManager) {
        self.accountManager = accountManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("添加验证账户")
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
                Text("识别二维码").tag(0)
                Text("手动输入").tag(1)
                Text("导入 URI").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    if selectedTab == 0 {
                        qrScanTab
                    } else if selectedTab == 1 {
                        manualEntryTab
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

                if selectedTab == 1 {
                    Button("添加账户") {
                        saveManualAccount()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(secretKey.trimmingCharacters(in: .whitespaces).isEmpty)
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
        .frame(width: 440, height: 420)
    }

    // MARK: - Subviews

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

    private var manualEntryTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("服务商 / 发行方 (Issuer)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例如: Google, GitHub, AWS", text: $issuer)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("账户名称 / 邮箱 (Account)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例如: yourname@gmail.com", text: $accountName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("密钥 (Secret Key)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Base32 格式，例如: JBSWY3DPEHPK3PXP", text: $secretKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
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
                .buttonStyle(.link)

                Spacer()
            }
        }
    }

    // MARK: - Actions

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
        let cleanedSecret = secretKey.replacingOccurrences(of: " ", with: "")
        guard Base32.decode(cleanedSecret) != nil else {
            errorMessage = "密钥不是有效的 Base32 编码，请检查"
            return
        }

        let item = AccountItem(
            accountName: accountName.trimmingCharacters(in: .whitespaces),
            issuer: issuer.trimmingCharacters(in: .whitespaces),
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
