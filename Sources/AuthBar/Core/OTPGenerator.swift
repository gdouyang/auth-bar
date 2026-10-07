import Foundation
import CryptoKit

public enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

public enum OTPType: String, Codable, CaseIterable, Sendable {
    case totp = "totp"
    case hotp = "hotp"
}

public struct OTPGenerator {
    /// Generates OTP code based on secret data and counter
    public static func generateHOTP(
        secret: Data,
        counter: UInt64,
        digits: Int = 6,
        algorithm: OTPAlgorithm = .sha1
    ) -> String? {
        guard digits >= 6 && digits <= 8 else { return nil }
        guard !secret.isEmpty else { return nil }

        // Counter to 8-byte big-endian
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: MemoryLayout<UInt64>.size)

        let hmacBytes: [UInt8]
        let symmetricKey = SymmetricKey(data: secret)

        switch algorithm {
        case .sha1:
            let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: symmetricKey)
            hmacBytes = Array(hmac)
        case .sha256:
            let hmac = HMAC<SHA256>.authenticationCode(for: counterData, using: symmetricKey)
            hmacBytes = Array(hmac)
        case .sha512:
            let hmac = HMAC<SHA512>.authenticationCode(for: counterData, using: symmetricKey)
            hmacBytes = Array(hmac)
        }

        // Dynamic truncation (RFC 4226 section 5.4)
        guard let lastByte = hmacBytes.last else { return nil }
        let offset = Int(lastByte & 0x0f)

        guard offset + 4 <= hmacBytes.count else { return nil }

        let truncatedHash = (UInt32(hmacBytes[offset] & 0x7f) << 24)
            | (UInt32(hmacBytes[offset + 1] & 0xff) << 16)
            | (UInt32(hmacBytes[offset + 2] & 0xff) << 8)
            | UInt32(hmacBytes[offset + 3] & 0xff)

        let modulo = UInt32(pow(10.0, Double(digits)))
        let otp = truncatedHash % modulo

        let format = "%0\(digits)u"
        return String(format: format, otp)
    }

    /// Generates TOTP code based on secret and date
    public static func generateTOTP(
        secret: Data,
        date: Date = Date(),
        period: Int = 30,
        digits: Int = 6,
        algorithm: OTPAlgorithm = .sha1
    ) -> String? {
        guard period > 0 else { return nil }
        let timeInterval = date.timeIntervalSince1970
        let counter = UInt64(floor(timeInterval / Double(period)))
        return generateHOTP(secret: secret, counter: counter, digits: digits, algorithm: algorithm)
    }

    /// Generates next TOTP code (for preview)
    public static func generateNextTOTP(
        secret: Data,
        date: Date = Date(),
        period: Int = 30,
        digits: Int = 6,
        algorithm: OTPAlgorithm = .sha1
    ) -> String? {
        guard period > 0 else { return nil }
        let nextDate = date.addingTimeInterval(Double(period))
        return generateTOTP(secret: secret, date: nextDate, period: period, digits: digits, algorithm: algorithm)
    }

    /// Calculates remaining seconds in the current TOTP period
    public static func remainingSeconds(date: Date = Date(), period: Int = 30) -> Int {
        guard period > 0 else { return 0 }
        let time = Int(date.timeIntervalSince1970)
        let elapsed = time % period
        return period - elapsed
    }

    /// Calculates progress (1.0 -> 0.0) in the current period
    public static func progress(date: Date = Date(), period: Int = 30) -> Double {
        guard period > 0 else { return 0.0 }
        let time = date.timeIntervalSince1970
        let remainder = time.truncatingRemainder(dividingBy: Double(period))
        let remaining = Double(period) - remainder
        return remaining / Double(period)
    }
}
