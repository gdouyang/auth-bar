import SwiftUI

public struct AccountRowView: View {
    public let account: AccountItem
    @ObservedObject var accountManager: AccountManager

    @State private var isHovered = false
    @State private var isCopied = false
    var onEdit: (AccountItem) -> Void
    var onDelete: (AccountItem) -> Void

    public init(
        account: AccountItem,
        accountManager: AccountManager,
        onEdit: @escaping (AccountItem) -> Void,
        onDelete: @escaping (AccountItem) -> Void
    ) {
        self.account = account
        self.accountManager = accountManager
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: account.brandColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: account.iconSymbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: account.brandColors.first?.opacity(0.3) ?? .clear, radius: 4, x: 0, y: 2)

            // Titles & Code
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(account.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if account.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }

                    if account.type == .hotp {
                        Text("HOTP")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                if !account.displaySubtitle.isEmpty {
                    Text(account.displaySubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // 2FA Code Display
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(account.formattedCode())
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(codeColor)
                        .textSelection(.enabled)

                    if accountManager.settings.showNextCodePreview && account.type == .totp {
                        let next = account.nextCode()
                        if !next.isEmpty {
                            Text("下周期: \(next)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                }
            }

            Spacer()

            // Countdown Timer or HOTP counter action
            if account.type == .totp {
                CircularTimerView(
                    progress: accountManager.progress,
                    secondsRemaining: accountManager.secondsRemaining,
                    size: 30,
                    lineWidth: 3.5
                )
            } else {
                Button(action: {
                    accountManager.incrementCounter(id: account.id)
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("生成下一个计数码")
            }

            // Copy button
            Button(action: {
                triggerCopy()
            }) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isCopied ? .green : (isHovered ? .accentColor : .secondary))
                    .frame(width: 28, height: 28)
                    .background(isHovered ? Color.secondary.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("点击复制验证码")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: { triggerCopy() }) {
                Label("复制验证码", systemImage: "doc.on.doc")
            }

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(account.otpAuthURL, forType: .string)
                accountManager.showToast("已复制 otpauth:// 链接")
            }) {
                Label("复制 URI (otpauth://)", systemImage: "link")
            }

            Button(action: {
                accountManager.togglePin(id: account.id)
            }) {
                Label(account.pinned ? "取消置顶" : "置顶账户", systemImage: account.pinned ? "pin.slash" : "pin")
            }

            Divider()

            Button(action: { onEdit(account) }) {
                Label("编辑账户", systemImage: "pencil")
            }

            Button(role: .destructive, action: { onDelete(account) }) {
                Label("删除账户", systemImage: "trash")
            }
        }
    }

    private var codeColor: Color {
        if account.type == .totp && accountManager.secondsRemaining <= 4 {
            return .red
        }
        return .primary
    }

    private func triggerCopy() {
        accountManager.copyCode(for: account)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}
