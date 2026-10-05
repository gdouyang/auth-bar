import SwiftUI

public struct EditAccountSheet: View {
    @ObservedObject var accountManager: AccountManager
    @Environment(\.dismiss) private var dismiss

    @State private var account: AccountItem
    @State private var issuer: String
    @State private var accountName: String
    @State private var secret: String
    @State private var digits: Int
    @State private var period: Int
    @State private var algorithm: OTPAlgorithm
    @State private var errorMessage: String? = nil

    public init(account: AccountItem, accountManager: AccountManager) {
        self._account = State(initialValue: account)
        self._issuer = State(initialValue: account.issuer)
        self._accountName = State(initialValue: account.accountName)
        self._secret = State(initialValue: account.secret)
        self._digits = State(initialValue: account.digits)
        self._period = State(initialValue: account.period)
        self._algorithm = State(initialValue: account.algorithm)
        self.accountManager = accountManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑账户")
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

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("服务商 / 发行方 (Issuer)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $issuer)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("账户名称 / 邮箱 (Account)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $accountName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("密钥 (Secret Key)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $secret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("位数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $digits) {
                            Text("6 位").tag(6)
                            Text("8 位").tag(8)
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("周期 (秒)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("30", value: $period, format: .number)
                            .textFieldStyle(.roundedBorder)
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
                    }
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()

            Spacer()

            Divider()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存修改") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
    }

    private func saveChanges() {
        let cleanedSecret = secret.replacingOccurrences(of: " ", with: "")
        guard Base32.decode(cleanedSecret) != nil else {
            errorMessage = "密钥格式不正确 (Base32)"
            return
        }

        var updated = account
        updated.issuer = issuer.trimmingCharacters(in: .whitespaces)
        updated.accountName = accountName.trimmingCharacters(in: .whitespaces)
        updated.secret = cleanedSecret
        updated.digits = digits
        updated.period = period > 0 ? period : 30
        updated.algorithm = algorithm

        accountManager.updateAccount(updated)
        dismiss()
    }
}
