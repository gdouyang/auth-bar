import Foundation

public enum Base32 {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    private static let decodeMap: [Character: UInt8] = {
        var map = [Character: UInt8]()
        for (i, char) in alphabet.enumerated() {
            map[char] = UInt8(i)
            // Support lowercase as well
            if let lowerChar = char.lowercased().first {
                map[lowerChar] = UInt8(i)
            }
        }
        return map
    }()

    public static func decode(_ string: String) -> Data? {
        let cleaned = string
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return Data() }

        var buffer: UInt64 = 0
        var bitsLeft = 0
        var result = [UInt8]()

        for char in cleaned {
            guard let val = decodeMap[char] else {
                return nil
            }
            buffer = (buffer << 5) | UInt64(val)
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> bitsLeft) & 0xFF)
                result.append(byte)
            }
        }

        return Data(result)
    }

    public static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        let chars = Array(alphabet)
        var result = ""
        var buffer: UInt64 = 0
        var bitsLeft = 0

        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = Int((buffer >> bitsLeft) & 0x1F)
                result.append(chars[index])
            }
        }

        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1F)
            result.append(chars[index])
        }

        while result.count % 8 != 0 {
            result.append("=")
        }

        return result
    }
}
