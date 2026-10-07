import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var biometricAuth = BiometricAuth.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingExportSheet = false
    @State private var exportedJSON = ""
    @State private var showingImportSheet = false
    @State private var importJSONText = ""
    @State private var showingDeleteAllAlert = false

    public init(accountManager: AccountManager) {
        self.accountManager = accountManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("偏好设置")
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

            Divider()

            Form {
                Section("常规与交互") {
                    Toggle("复制验证码后自动关闭弹窗", isOn: $accountManager.settings.autoHideAfterCopy)
                        .onChange(of: accountManager.settings.autoHideAfterCopy) { _, _ in
                            accountManager.save()
                        }

                    Toggle("显示下一周期验证码预览", isOn: $accountManager.settings.showNextCodePreview)
                        .onChange(of: accountManager.settings.showNextCodePreview) { _, _ in
                            accountManager.save()
                        }

                    Toggle("按发行方/账户名称字母排序", isOn: $accountManager.settings.sortAlphabetically)
                        .onChange(of: accountManager.settings.sortAlphabetically) { _, _ in
                            accountManager.save()
                        }
                }

                Section("安全锁定") {
                    Toggle("开启 Touch ID / 密码解锁", isOn: $accountManager.settings.requireTouchID)
                        .onChange(of: accountManager.settings.requireTouchID) { _, newValue in
                            if newValue {
                                biometricAuth.authenticate(reason: "验证以启用安全锁定") { success in
                                    if !success {
                                        accountManager.settings.requireTouchID = false
                                    }
                                    accountManager.save()
                                }
                            } else {
                                accountManager.save()
                            }
                        }
                    Text("启用后，唤起应用时需先进行指纹或密码验证，防止他人偷看。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("数据备份与恢复") {
                    HStack(spacing: 12) {
                        Button("导出数据 (JSON)") {
                            exportData()
                        }

                        Button("从 JSON 恢复") {
                            showingImportSheet = true
                        }
                    }

                    Button("清空所有账户", role: .destructive) {
                        showingDeleteAllAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)

            Spacer()

            Divider()

            HStack {
                Text("AuthBar for Mac v1.0.0")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 440, height: 420)
        .alert("清空所有账户", isPresented: $showingDeleteAllAlert) {
            Button("取消", role: .cancel) {}
            Button("清空全部", role: .destructive) {
                accountManager.accounts.removeAll()
                accountManager.save()
                accountManager.showToast("已清空所有账户")
            }
        } message: {
            Text("此操作不可恢复，请确保您已经备份了验证码密钥！")
        }
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
        }
        .sheet(isPresented: $showingImportSheet) {
            importSheet
        }
    }

    private func exportData() {
        exportedJSON = accountManager.exportJSON()
        showingExportSheet = true
    }

    private var exportSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("导出数据 (JSON)")
                    .font(.headline)
                Spacer()
                Button(action: { showingExportSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("请妥善保管以下 JSON 内容，切勿泄露给他人：")
                .font(.footnote)
                .foregroundColor(.secondary)

            TextEditor(text: .constant(exportedJSON))
                .font(.system(.caption, design: .monospaced))
                .frame(height: 200)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button("复制到剪贴板") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportedJSON, forType: .string)
                    accountManager.showToast("已复制到剪贴板")
                }
                Spacer()
                Button("关闭") {
                    showingExportSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 420, height: 320)
    }

    private var importSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("从 JSON 恢复数据")
                    .font(.headline)
                Spacer()
                Button(action: { showingImportSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("请在此粘贴导出的 JSON 文本：")
                .font(.footnote)
                .foregroundColor(.secondary)

            TextEditor(text: $importJSONText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button("从剪贴板粘贴") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        importJSONText = text
                    }
                }
                Spacer()
                Button("取消") {
                    showingImportSheet = false
                }
                Button("确认导入") {
                    let result = accountManager.importJSON(importJSONText)
                    if result.count > 0 {
                        showingImportSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(importJSONText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 320)
    }
}
