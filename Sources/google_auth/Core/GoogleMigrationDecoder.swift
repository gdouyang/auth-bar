import Foundation

/// Decodes Google Authenticator Migration QR code URIs
/// Format: `otpauth-migration://offline?data=<base64-encoded-protobuf>`
public enum GoogleMigrationDecoder {
    public struct MigratedAccount {
        public var name: String
        public var issuer: String
        public var secretBase32: String
        public var algorithm: OTPAlgorithm
        public var digits: Int
        public var type: OTPType
        public var counter: UInt64
    }

    public static func isMigrationURL(_ urlString: String) -> Bool {
        return urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("otpauth-migration://")
    }

    public static func decode(_ urlString: String) -> [MigratedAccount] {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItem = components.queryItems?.first(where: { $0.name == "data" }),
              let dataString = queryItem.value else {
            return []
        }

        // Support URL-safe base64 and standard base64
        var base64 = dataString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let payloadData = Data(base64Encoded: base64) else {
            return []
        }

        return parsePayload(payloadData)
    }

    // Simple Protobuf parser for MigrationPayload
    private static func parsePayload(_ data: Data) -> [MigratedAccount] {
        var results = [MigratedAccount]()
        var index = 0

        while index < data.count {
            guard let (tag, wireType) = readTag(data, index: &index) else { break }
            if tag == 1 && wireType == 2 { // otp_parameters
                guard let messageData = readLengthDelimited(data, index: &index) else { break }
                if let account = parseOtpParameters(messageData) {
                    results.append(account)
                }
            } else {
                skipField(data, wireType: wireType, index: &index)
            }
        }

        return results
    }

    private static func parseOtpParameters(_ data: Data) -> MigratedAccount? {
        var index = 0
        var secretData = Data()
        var name = ""
        var issuer = ""
        var algorithm: OTPAlgorithm = .sha1
        var digits = 6
        var type: OTPType = .totp
        var counter: UInt64 = 0

        while index < data.count {
            guard let (tag, wireType) = readTag(data, index: &index) else { break }
            switch (tag, wireType) {
            case (1, 2): // secret (bytes)
                if let bytes = readLengthDelimited(data, index: &index) {
                    secretData = bytes
                }
            case (2, 2): // name (string)
                if let bytes = readLengthDelimited(data, index: &index),
                   let str = String(data: bytes, encoding: .utf8) {
                    name = str
                }
            case (3, 2): // issuer (string)
                if let bytes = readLengthDelimited(data, index: &index),
                   let str = String(data: bytes, encoding: .utf8) {
                    issuer = str
                }
            case (4, 0): // algorithm
                if let val = readVarint(data, index: &index) {
                    switch val {
                    case 1: algorithm = .sha1
                    case 2: algorithm = .sha256
                    case 3: algorithm = .sha512
                    default: algorithm = .sha1
                    }
                }
            case (5, 0): // digits
                if let val = readVarint(data, index: &index) {
                    digits = (val == 2) ? 8 : 6
                }
            case (6, 0): // type
                if let val = readVarint(data, index: &index) {
                    type = (val == 1) ? .hotp : .totp
                }
            case (7, 0): // counter
                if let val = readVarint(data, index: &index) {
                    counter = val
                }
            default:
                skipField(data, wireType: wireType, index: &index)
            }
        }

        guard !secretData.isEmpty else { return nil }

        let secretBase32 = Base32.encode(secretData)

        // Parse issuer and account from name if needed
        var accountName = name
        if issuer.isEmpty, let colonIndex = name.firstIndex(of: ":") {
            issuer = String(name[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let nextIndex = name.index(after: colonIndex)
            accountName = String(name[nextIndex...]).trimmingCharacters(in: .whitespaces)
        } else if let colonIndex = name.firstIndex(of: ":") {
            let nextIndex = name.index(after: colonIndex)
            accountName = String(name[nextIndex...]).trimmingCharacters(in: .whitespaces)
        }

        return MigratedAccount(
            name: accountName.isEmpty ? name : accountName,
            issuer: issuer,
            secretBase32: secretBase32,
            algorithm: algorithm,
            digits: digits,
            type: type,
            counter: counter
        )
    }

    private static func readTag(_ data: Data, index: inout Int) -> (Int, Int)? {
        guard let varint = readVarint(data, index: &index) else { return nil }
        let wireType = Int(varint & 0x07)
        let fieldNumber = Int(varint >> 3)
        return (fieldNumber, wireType)
    }

    private static func readVarint(_ data: Data, index: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0

        while index < data.count {
            let byte = data[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 {
                return result
            }
            shift += 7
            if shift > 64 { return nil }
        }
        return nil
    }

    private static func readLengthDelimited(_ data: Data, index: inout Int) -> Data? {
        guard let length = readVarint(data, index: &index) else { return nil }
        let intLen = Int(length)
        guard index + intLen <= data.count else { return nil }
        let subdata = data.subdata(in: index..<(index + intLen))
        index += intLen
        return subdata
    }

    private static func skipField(_ data: Data, wireType: Int, index: inout Int) {
        switch wireType {
        case 0: // Varint
            _ = readVarint(data, index: &index)
        case 1: // 64-bit
            index = min(index + 8, data.count)
        case 2: // Length-delimited
            if let len = readVarint(data, index: &index) {
                index = min(index + Int(len), data.count)
            }
        case 5: // 32-bit
            index = min(index + 4, data.count)
        default:
            index = data.count
        }
    }
}
