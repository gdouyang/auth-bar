import Foundation

public struct OTPAuthParsedData {
    public var type: OTPType
    public var secret: String // Base32
    public var accountName: String
    public var issuer: String
    public var algorithm: OTPAlgorithm
    public var digits: Int
    public var period: Int
    public var counter: UInt64
}

public enum OTPAuthURL {
    /// Parses an `otpauth://` URI
    public static func parse(_ urlString: String) -> OTPAuthParsedData? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "otpauth" else {
            return nil
        }

        let typeStr = (url.host ?? "").lowercased()
        let type: OTPType
        if typeStr == "hotp" {
            type = .hotp
        } else if typeStr == "totp" {
            type = .totp
        } else {
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var secret = ""
        var issuerParam = ""
        var algorithm: OTPAlgorithm = .sha1
        var digits = 6
        var period = 30
        var counter: UInt64 = 0

        for item in components.queryItems ?? [] {
            let name = item.name.lowercased()
            let value = item.value ?? ""
            switch name {
            case "secret":
                secret = value.replacingOccurrences(of: " ", with: "").uppercased()
            case "issuer":
                issuerParam = value
            case "algorithm":
                if let algo = OTPAlgorithm(rawValue: value.uppercased()) {
                    algorithm = algo
                }
            case "digits":
                if let d = Int(value), d >= 6 && d <= 8 {
                    digits = d
                }
            case "period":
                if let p = Int(value), p > 0 {
                    period = p
                }
            case "counter":
                if let c = UInt64(value) {
                    counter = c
                }
            default:
                break
            }
        }

        guard !secret.isEmpty else { return nil }

        // Path is typically "/Issuer:Account" or "/Account"
        var path = url.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        path = path.removingPercentEncoding ?? path

        var labelIssuer = ""
        var accountName = path

        if let colonIndex = path.firstIndex(of: ":") {
            labelIssuer = String(path[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let nextIndex = path.index(after: colonIndex)
            accountName = String(path[nextIndex...]).trimmingCharacters(in: .whitespaces)
        }

        let finalIssuer = !issuerParam.isEmpty ? issuerParam : labelIssuer

        return OTPAuthParsedData(
            type: type,
            secret: secret,
            accountName: accountName.isEmpty ? finalIssuer : accountName,
            issuer: finalIssuer,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter
        )
    }

    /// Builds an `otpauth://` URI
    public static func build(
        type: OTPType,
        accountName: String,
        issuer: String,
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: UInt64 = 0
    ) -> String {
        var label = accountName
        if !issuer.isEmpty && !accountName.contains(":") {
            label = "\(issuer):\(accountName)"
        }
        let escapedLabel = label.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? label

        var query = [
            "secret=\(secret)"
        ]
        if !issuer.isEmpty {
            let escapedIssuer = issuer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? issuer
            query.append("issuer=\(escapedIssuer)")
        }
        if algorithm != .sha1 {
            query.append("algorithm=\(algorithm.rawValue)")
        }
        if digits != 6 {
            query.append("digits=\(digits)")
        }
        if type == .totp && period != 30 {
            query.append("period=\(period)")
        }
        if type == .hotp {
            query.append("counter=\(counter)")
        }

        return "otpauth://\(type.rawValue)/\(escapedLabel)?\(query.joined(separator: "&"))"
    }
}
