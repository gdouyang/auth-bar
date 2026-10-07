import Testing
import Foundation
@testable import AuthBar

@Suite("Base32 Tests")
struct Base32Tests {
    @Test("Base32 encoding and decoding standard vectors")
    func testBase32EncodingDecoding() {
        let vectors: [(String, String)] = [
            ("", ""),
            ("f", "MY======"),
            ("fo", "MZXQ===="),
            ("foo", "MZXW6==="),
            ("foob", "MZXW6YQ="),
            ("fooba", "MZXW6YTB"),
            ("foobar", "MZXW6YTBOI======")
        ]

        for (plain, encoded) in vectors {
            let data = plain.data(using: .utf8)!
            let encodedResult = Base32.encode(data)
            #expect(encodedResult == encoded)

            let decodedResult = Base32.decode(encoded)
            #expect(decodedResult == data)
        }
    }

    @Test("Base32 decoding is case insensitive and handles spaces/dashes")
    func testBase32Resilience() {
        let input = "mzxw 6ytb-oi"
        let expected = "foobar".data(using: .utf8)!
        let decoded = Base32.decode(input)
        #expect(decoded == expected)
    }
}

@Suite("RFC 4226 HOTP Tests")
struct HOTPTests {
    // RFC 4226 Appendix D - Test Values
    // The test secret is the ASCII string "12345678901234567890"
    let secret = "12345678901234567890".data(using: .ascii)!

    @Test("RFC 4226 test vector counts 0 to 9")
    func testRFCHOTP() {
        let expected = [
            "755224",
            "287082",
            "359152",
            "969429",
            "338314",
            "254676",
            "287922",
            "162583",
            "399871",
            "520489"
        ]

        for (counter, expectedCode) in expected.enumerated() {
            let code = OTPGenerator.generateHOTP(secret: secret, counter: UInt64(counter), digits: 6, algorithm: .sha1)
            #expect(code == expectedCode)
        }
    }
}

@Suite("RFC 6238 TOTP Tests")
struct TOTPTests {
    let secretSha1 = "12345678901234567890".data(using: .ascii)!

    @Test("RFC 6238 SHA1 8-digit test vectors")
    func testRFCTOTP() {
        // T0 = 0, Period = 30
        let vectors: [(TimeInterval, String)] = [
            (59, "94287082"),
            (1111111109, "07081804"),
            (1111111111, "14050471"),
            (1234567890, "89005924"),
            (2000000000, "69279037")
        ]

        for (time, expectedCode) in vectors {
            let date = Date(timeIntervalSince1970: time)
            let code = OTPGenerator.generateTOTP(
                secret: secretSha1,
                date: date,
                period: 30,
                digits: 8,
                algorithm: .sha1
            )
            #expect(code == expectedCode)
        }
    }
}

@Suite("OTPAuth URL Tests")
struct OTPAuthURLTests {
    @Test("Parse standard otpauth URI")
    func testParseURL() {
        let url = "otpauth://totp/Google:alice@gmail.com?secret=JBSWY3DPEHPK3PXP&issuer=Google&algorithm=SHA1&digits=6&period=30"
        let parsed = OTPAuthURL.parse(url)
        #expect(parsed != nil)
        #expect(parsed?.type == .totp)
        #expect(parsed?.accountName == "alice@gmail.com")
        #expect(parsed?.issuer == "Google")
        #expect(parsed?.secret == "JBSWY3DPEHPK3PXP")
        #expect(parsed?.algorithm == .sha1)
        #expect(parsed?.digits == 6)
        #expect(parsed?.period == 30)
    }

    @Test("Build and roundtrip otpauth URI")
    func testBuildURL() {
        let built = OTPAuthURL.build(
            type: .totp,
            accountName: "bob@example.com",
            issuer: "GitHub",
            secret: "JBSWY3DPEHPK3PXP"
        )
        let parsed = OTPAuthURL.parse(built)
        #expect(parsed != nil)
        #expect(parsed?.issuer == "GitHub")
        #expect(parsed?.accountName == "bob@example.com")
        #expect(parsed?.secret == "JBSWY3DPEHPK3PXP")
    }
}

@Suite("AccountItem Tests")
struct AccountItemTests {
    @Test("Account code formatting")
    func testCodeFormatting() {
        let account = AccountItem(
            accountName: "user@test.com",
            issuer: "TestApp",
            secret: "JBSWY3DPEHPK3PXP",
            digits: 6
        )
        let formatted = account.formattedCode()
        #expect(formatted.count == 7) // 6 digits + 1 space
        #expect(formatted.contains("\u{00A0}") || formatted.contains(" "))
    }
}

@Suite("Google Migration Decoder Tests")
struct GoogleMigrationDecoderTests {
    @Test("Check migration url detection")
    func testMigrationUrlCheck() {
        let url = "otpauth-migration://offline?data=test"
        #expect(GoogleMigrationDecoder.isMigrationURL(url))
        #expect(!GoogleMigrationDecoder.isMigrationURL("otpauth://totp/Test"))
    }
}
