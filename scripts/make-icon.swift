// Генерирует AppIcon.iconset: заглавная «T» (Literata Bold) на стеклянном сквиркле.
// Вариант задаётся аргументом: swift scripts/make-icon.swift [dark|light]
//   dark  — фон #111111, буква #F8F9FA (по умолчанию)
//   light — фон #F8F9FA, буква #111111
// Превью обоих вариантов пишутся в design/.
import AppKit

let fontURL = URL(fileURLWithPath: "Sources/TypografApp/Resources/Literata.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

struct Variant {
    let name: String
    let bgTop: CGColor
    let bgBottom: CGColor
    let letter: CGColor
    let topHighlight: CGFloat   // прозрачность световой кромки сверху
    let letterShadow: CGFloat   // прозрачность тени под буквой
}

// #111111 и #F8F9FA с лёгким градиентом вокруг базового цвета — «стекло».
let dark = Variant(
    name: "dark",
    bgTop: CGColor(red: 0.125, green: 0.125, blue: 0.13, alpha: 1),
    bgBottom: CGColor(red: 0.045, green: 0.045, blue: 0.05, alpha: 1),
    letter: CGColor(red: 0.973, green: 0.976, blue: 0.98, alpha: 1),
    topHighlight: 0.16,
    letterShadow: 0.45
)
let light = Variant(
    name: "light",
    bgTop: CGColor(red: 0.995, green: 0.995, blue: 1.0, alpha: 1),
    bgBottom: CGColor(red: 0.925, green: 0.93, blue: 0.945, alpha: 1),
    letter: CGColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1),
    topHighlight: 0.85,
    letterShadow: 0.18
)

// Оптический размер 12 — «текстовая» Literata, какой её все знают;
// большие значения opsz дают контрастный дисплейный рисунок, похожий на другой шрифт.
func literata(size: CGFloat, weight: CGFloat = 700, optical: CGFloat = 12) -> NSFont {
    let base = NSFont(name: "Literata", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
    let descriptor = base.fontDescriptor.addingAttributes([
        NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
            NSNumber(value: 0x7767_6874): weight,  // 'wght'
            NSNumber(value: 0x6F70_737A): optical  // 'opsz'
        ]
    ])
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func glyphPath(for character: Character, font: NSFont) -> CGPath? {
    var chars = Array(String(character).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count),
          let glyph = glyphs.first else { return nil }
    return CTFontCreatePathForGlyph(font, glyph, nil)
}

func drawIcon(side: CGFloat, variant: Variant) -> NSImage {
    NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }

        // Скругление и отступы по сетке иконок macOS.
        let inset = side * 0.098
        let square = rect.insetBy(dx: inset, dy: inset)
        let radius = side * 0.185
        let squircle = CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil)

        // Фон-градиент.
        context.saveGState()
        context.addPath(squircle)
        context.clip()
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [variant.bgTop, variant.bgBottom] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: square.midX, y: square.maxY),
            end: CGPoint(x: square.midX, y: square.minY),
            options: []
        )

        // Стеклянная кромка: светлая линия по верхнему краю, затухающая к низу.
        let edgeWidth = max(side * 0.004, 1)
        let edge = CGPath(
            roundedRect: square.insetBy(dx: edgeWidth / 2, dy: edgeWidth / 2),
            cornerWidth: radius - edgeWidth / 2,
            cornerHeight: radius - edgeWidth / 2,
            transform: nil
        )
        let edgeGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(gray: 1, alpha: variant.topHighlight),
                CGColor(gray: 1, alpha: 0)
            ] as CFArray,
            locations: [0, 0.45]
        )!
        context.saveGState()
        context.addPath(edge)
        context.setLineWidth(edgeWidth)
        context.replacePathWithStrokedPath()
        context.clip()
        context.drawLinearGradient(
            edgeGradient,
            start: CGPoint(x: square.midX, y: square.maxY),
            end: CGPoint(x: square.midX, y: square.minY),
            options: []
        )
        context.restoreGState()
        context.restoreGState()

        // «T», оптически отцентрированная по границам глифа.
        let font = literata(size: side * 0.6)
        guard let path = glyphPath(for: "T", font: font) else { return false }
        let bounds = path.boundingBoxOfPath
        let targetHeight = side * 0.40
        let scale = targetHeight / bounds.height

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -side * 0.01),
            blur: side * 0.025,
            color: CGColor(gray: 0, alpha: variant.letterShadow)
        )
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        context.addPath(path)
        context.setFillColor(variant.letter)
        context.fillPath()
        context.restoreGState()
        return true
    }
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = image.size
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try! png.write(to: URL(fileURLWithPath: path))
}

// Превью обоих вариантов — посмотреть глазами.
try? FileManager.default.createDirectory(atPath: "design", withIntermediateDirectories: true)
for variant in [dark, light] {
    writePNG(drawIcon(side: 512, variant: variant), to: "design/appicon-\(variant.name).png")
}

// Iconset выбранного варианта.
let chosen = CommandLine.arguments.contains("light") ? light : dark
let iconset = "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for (name, side) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
] {
    writePNG(drawIcon(side: CGFloat(side), variant: chosen), to: "\(iconset)/\(name).png")
}
print("iconset (\(chosen.name)) written to \(iconset); previews in design/")
