import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var biometricAuth = BiometricAuth.shared

    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var editingAccount: AccountItem? = nil
    @State private var accountToDelete: AccountItem? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            if accountManager.settings.requireTouchID && !biometricAuth.isUnlocked {
                lockedView
            } else {
                // Search bar
                searchBar

                // Account list or Empty state
                if accountManager.accounts.isEmpty {
                    emptyStateView
                } else if accountManager.filteredAccounts.isEmpty {
                    noSearchResultsView
                } else {
                    accountsList
                }
            }

            // Bottom bar / Toast
            bottomStatusBar
        }
        .frame(width: 380, height: 490)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingAddSheet) {
            AddAccountSheet(accountManager: accountManager)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(accountManager: accountManager)
        }
        .sheet(item: $editingAccount) { account in
            EditAccountSheet(account: account, accountManager: accountManager)
        }
        .alert(
            "确认删除账户",
            isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            )
        ) {
            Button("取消", role: .cancel) {
                accountToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let acc = accountToDelete {
                    accountManager.deleteAccount(id: acc.id)
                    accountToDelete = nil
                }
            }
        } message: {
            if let acc = accountToDelete {
                Text("确定要删除「\(acc.displayTitle)」吗？删除后将无法通过此应用生成该验证码。")
            }
        }
        .onAppear {
            if accountManager.settings.requireTouchID {
                biometricAuth.authenticate { _ in }
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.accentColor)

            Text("身份验证器")
                .font(.system(size: 14, weight: .bold))

            Spacer()

            // Quick import from clipboard
            Button(action: {
                let res = accountManager.importFromClipboard()
                if let err = res.error {
                    accountManager.showToast(err)
                }
            }) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("从剪贴板导入")

            // Quick scan screen button
            Button(action: {
                let res = accountManager.importFromScreenQR()
                if let err = res.error {
                    accountManager.showToast(err)
                }
            }) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("一键识别屏幕二维码")

            // Add button
            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("添加账户")

            // Settings button
            Button(action: { showingSettingsSheet = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("设置")

            // Quit button
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("退出应用")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            TextField("搜索账户或发行商...", text: $accountManager.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !accountManager.searchText.isEmpty {
                Button(action: { accountManager.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Account List

    private var accountsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(accountManager.filteredAccounts) { account in
                    AccountRowView(
                        account: account,
                        accountManager: accountManager,
                        onEdit: { acc in
                            editingAccount = acc
                        },
                        onDelete: { acc in
                            accountToDelete = acc
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 6) {
                Text("暂无验证账户")
                    .font(.system(size: 15, weight: .bold))
                Text("您可以扫描网页上的二维码、导入 Google 迁移码，或手动输入密钥。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                Button(action: {
                    let res = accountManager.importFromClipboard()
                    if let err = res.error {
                        accountManager.showToast(err)
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("从剪贴板读取并导入")
                    }
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    let res = accountManager.importFromScreenQR()
                    if let err = res.error {
                        accountManager.showToast(err)
                    }
                }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("一键识别屏幕上的二维码")
                    }
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)

                Button(action: { showingAddSheet = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("手动添加账户")
                    }
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("没有找到匹配的账户")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Locked View

    private var lockedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("身份验证器已锁定")
                .font(.headline)
            Text("请使用 Touch ID 或 Mac 密码解锁以查看动态验证码")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("立即解锁") {
                biometricAuth.authenticate { _ in }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Bottom Status Bar

    private var bottomStatusBar: some View {
        HStack {
            if let toast = accountManager.toastMessage {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(toast)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text("\(accountManager.accounts.count) 个验证账户")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Text("刷新剩余:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(accountManager.secondsRemaining)s")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(accountManager.secondsRemaining <= 4 ? .red : .secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: accountManager.toastMessage)
    }
}
