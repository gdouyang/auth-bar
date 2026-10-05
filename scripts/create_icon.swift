import AppKit

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Outer rounded rectangle (macOS standard squircle style)
    let rect = CGRect(x: s * 0.08, y: s * 0.08, width: s * 0.84, height: s * 0.84)
    let cornerRadius = s * 0.18
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Background gradient (Deep blue to dark slate)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.10, green: 0.35, blue: 0.85, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.15, blue: 0.50, alpha: 1.0).cgColor
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    }
    ctx.restoreGState()

    // Subtle inner border
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
    ctx.setLineWidth(max(1.0, s * 0.015))
    ctx.strokePath()
    ctx.restoreGState()

    // Draw Shield / Key Icon in center
    let centerRect = CGRect(x: s * 0.22, y: s * 0.22, width: s * 0.56, height: s * 0.56)
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.45, weight: .bold)
        .applying(.init(paletteColors: [.white, NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.9)]))
    if let sfImage = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        sfImage.draw(in: centerRect)
    }

    image.unlockFocus()
    return image
}

let iconsetURL = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

for (baseSize, scale) in sizes {
    let pixelSize = baseSize * scale
    let image = generateIcon(size: pixelSize)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else { continue }

    let filename = scale == 1 ? "icon_\(baseSize)x\(baseSize).png" : "icon_\(baseSize)x\(baseSize)@2x.png"
    let fileURL = iconsetURL.appendingPathComponent(filename)
    try? pngData.write(to: fileURL)
}

print("Iconset created successfully.")
