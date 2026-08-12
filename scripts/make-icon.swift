// Генерирует AppIcon.icns: белая «t» (Nunito Sans) на зелёном градиентном сквиркле.
// Запускается из build.sh: swift scripts/make-icon.swift
import AppKit

let fontURL = URL(fileURLWithPath: "Sources/TypografApp/Resources/NunitoSans.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

func glyphPath(for character: Character, font: NSFont) -> CGPath? {
    var chars = Array(String(character).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count),
          let glyph = glyphs.first else { return nil }
    return CTFontCreatePathForGlyph(font, glyph, nil)
}

func boldNunito(size: CGFloat, weight: CGFloat = 800) -> NSFont {
    let base = NSFont(name: "Nunito Sans", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
    // Вариативный шрифт: вес задаётся осью 'wght', трейты не работают.
    let descriptor = base.fontDescriptor.addingAttributes([
        NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String):
            [NSNumber(value: 0x7767_6874): weight]
    ])
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func drawIcon(side: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }

        // Скругление и отступы по сетке иконок macOS.
        let inset = side * 0.098
        let square = rect.insetBy(dx: inset, dy: inset)
        let squircle = CGPath(
            roundedRect: square,
            cornerWidth: side * 0.185,
            cornerHeight: side * 0.185,
            transform: nil
        )

        context.saveGState()
        context.addPath(squircle)
        context.clip()
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(red: 0.62, green: 0.89, blue: 0.55, alpha: 1),
                CGColor(red: 0.33, green: 0.73, blue: 0.36, alpha: 1)
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: square.midX, y: square.maxY),
            end: CGPoint(x: square.midX, y: square.minY),
            options: []
        )
        context.restoreGState()

        // Белая «t», оптически отцентрированная по границам глифа.
        let font = boldNunito(size: side * 0.6)
        guard let path = glyphPath(for: "t", font: font) else { return false }
        let bounds = path.boundingBoxOfPath
        let targetHeight = side * 0.42
        let scale = targetHeight / bounds.height

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -side * 0.008),
            blur: side * 0.012,
            color: CGColor(gray: 0, alpha: 0.15)
        )
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        context.addPath(path)
        context.setFillColor(.white)
        context.fillPath()
        context.restoreGState()
        return true
    }
}

let iconset = "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for (name, side) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
] {
    let image = drawIcon(side: CGFloat(side))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { continue }
    rep.size = image.size
    guard let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
print("iconset written to \(iconset)")
