import Foundation
import SwiftUI

public struct AccountItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var accountName: String
    public var issuer: String
    public var secret: String // Base32
    public var algorithm: OTPAlgorithm
    public var digits: Int
    public var type: OTPType
    public var period: Int
    public var counter: UInt64
    public var pinned: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        accountName: String,
        issuer: String = "",
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        type: OTPType = .totp,
        period: Int = 30,
        counter: UInt64 = 0,
        pinned: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.accountName = accountName
        self.issuer = issuer
        self.secret = secret.replacingOccurrences(of: " ", with: "").uppercased()
        self.algorithm = algorithm
        self.digits = digits
        self.type = type
        self.period = period
        self.counter = counter
        self.pinned = pinned
        self.createdAt = createdAt
    }

    /// Secret data decoded from Base32
    public var secretData: Data? {
        Base32.decode(secret)
    }

    /// Generates the current OTP code
    public func code(at date: Date = Date()) -> String {
        guard let data = secretData else { return "------" }
        switch type {
        case .totp:
            return OTPGenerator.generateTOTP(
                secret: data,
                date: date,
                period: period,
                digits: digits,
                algorithm: algorithm
            ) ?? String(repeating: "-", count: digits)
        case .hotp:
            return OTPGenerator.generateHOTP(
                secret: data,
                counter: counter,
                digits: digits,
                algorithm: algorithm
            ) ?? String(repeating: "-", count: digits)
        }
    }

    /// Generates next period OTP code
    public func nextCode(at date: Date = Date()) -> String {
        guard let data = secretData, type == .totp else { return "" }
        return OTPGenerator.generateNextTOTP(
            secret: data,
            date: date,
            period: period,
            digits: digits,
            algorithm: algorithm
        ) ?? ""
    }

    /// Formats code with space (e.g. "123 456" or "1234 5678")
    public func formattedCode(at date: Date = Date()) -> String {
        let raw = code(at: date)
        if raw.count == 6 {
            let prefix = raw.prefix(3)
            let suffix = raw.suffix(3)
            return "\(prefix)\u{00A0}\(suffix)"
        } else if raw.count == 8 {
            let prefix = raw.prefix(4)
            let suffix = raw.suffix(4)
            return "\(prefix)\u{00A0}\(suffix)"
        }
        return raw
    }

    /// Effective display name
    public var displayTitle: String {
        if !issuer.isEmpty {
            return issuer
        }
        return accountName.isEmpty ? "未命名账户" : accountName
    }

    public var displaySubtitle: String {
        if !issuer.isEmpty && !accountName.isEmpty && issuer != accountName {
            return accountName
        }
        return ""
    }

    /// System symbol name based on issuer
    public var iconSymbol: String {
        let key = (issuer.isEmpty ? accountName : issuer).lowercased()
        if key.contains("google") { return "g.circle.fill" }
        if key.contains("github") { return "terminal.fill" }
        if key.contains("apple") || key.contains("icloud") { return "applelogo" }
        if key.contains("microsoft") || key.contains("azure") || key.contains("outlook") { return "window.shade.closed" }
        if key.contains("amazon") || key.contains("aws") { return "cart.fill" }
        if key.contains("facebook") || key.contains("meta") { return "person.2.fill" }
        if key.contains("twitter") || key.contains(" x") || key == "x" { return "bubble.left.fill" }
        if key.contains("discord") || key.contains("chat") { return "bubble.left.and.bubble.right.fill" }
        if key.contains("binance") || key.contains("crypto") || key.contains("coin") { return "bitcoinsign.circle.fill" }
        if key.contains("bank") || key.contains("pay") { return "creditcard.fill" }
        if key.contains("mail") { return "envelope.fill" }
        if key.contains("cloud") { return "cloud.fill" }
        return "lock.shield.fill"
    }

    /// Gradient color for issuer tag
    public var brandColors: [Color] {
        let key = (issuer.isEmpty ? accountName : issuer).lowercased()
        if key.contains("google") {
            return [Color.blue, Color.red]
        }
        if key.contains("github") {
            return [Color(white: 0.2), Color(white: 0.4)]
        }
        if key.contains("apple") {
            return [Color.gray, Color.black]
        }
        if key.contains("microsoft") || key.contains("azure") {
            return [Color.blue, Color.cyan]
        }
        if key.contains("amazon") || key.contains("aws") {
            return [Color.orange, Color.yellow]
        }
        if key.contains("binance") || key.contains("crypto") {
            return [Color.yellow, Color.orange]
        }
        return [Color.indigo, Color.purple]
    }

    /// Exports to otpauth:// URI
    public var otpAuthURL: String {
        OTPAuthURL.build(
            type: type,
            accountName: accountName,
            issuer: issuer,
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter
        )
    }
}
