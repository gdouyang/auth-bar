import Foundation
import AppKit
import Vision

public enum BarcodeScanner {
    /// Detects QR codes inside an NSImage
    public static func detectQRCode(in image: NSImage) -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        return detectQRCode(in: cgImage)
    }

    /// Detects QR codes inside a CGImage
    public static func detectQRCode(in cgImage: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results else { return [] }
            return results.compactMap { $0.payloadStringValue }
        } catch {
            return []
        }
    }

    /// Captures the main screen and searches for QR codes
    public static func scanScreenForQRCodes() -> [String] {
        let displayID = CGMainDisplayID()
        guard let screenImage = CGDisplayCreateImage(displayID) else {
            // Fallback to window list image if direct display capture is nil
            if let windowImage = CGWindowListCreateImage(
                CGRect.infinite,
                .optionOnScreenOnly,
                kCGNullWindowID,
                .nominalResolution
            ) {
                return detectQRCode(in: windowImage)
            }
            return []
        }
        return detectQRCode(in: screenImage)
    }
}
