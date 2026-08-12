import AppKit
import SwiftUI

/// Шрифт Nunito Sans из ресурсов — для иконки в менюбаре и всплывашки.
enum NunitoFont {

    /// Идентификатор оси вариативности 'wght'.
    private static let weightAxis = 0x7767_6874

    static func register() {
        guard let url = Bundle.module.url(forResource: "NunitoSans", withExtension: "ttf") else {
            NSLog("Typograf: NunitoSans.ttf not found in bundle")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Nunito Sans — вариативный шрифт: вес задаётся осью 'wght' (400…1000),
    /// обычные weight-трейты дескриптора на него не действуют.
    static func nsFont(size: CGFloat, weight: CGFloat = 700) -> NSFont {
        guard let base = NSFont(name: "Nunito Sans", size: size)
            ?? NSFont(name: "NunitoSans-Regular", size: size) else {
            return .systemFont(ofSize: size, weight: .bold)
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String):
                [NSNumber(value: weightAxis): weight]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    static func swiftUIFont(size: CGFloat, weight: CGFloat = 700) -> Font {
        Font(nsFont(size: size, weight: weight))
    }

    /// Векторный контур глифа — для точного оптического центрирования.
    static func glyphPath(for character: Character, font: NSFont) -> CGPath? {
        var chars = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count),
              let glyph = glyphs.first else { return nil }
        return CTFontCreatePathForGlyph(font, glyph, nil)
    }

    /// Иконка менюбара по макету: сквиркл контуром 16×16 (штрих 1.3),
    /// «t» semibold по центру. Всегда template — тему отрабатывает система.
    static func statusBarIcon() -> NSImage {
        let side: CGFloat = 16
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let outline = rect.insetBy(dx: 0.65, dy: 0.65)
            context.addPath(CGPath(
                roundedRect: outline,
                cornerWidth: 4.35,
                cornerHeight: 4.35,
                transform: nil
            ))
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.3)
            context.strokePath()

            // «t» — натуральный размер 14pt semibold, оптически по центру.
            let font = nsFont(size: 14, weight: 600)
            if let path = glyphPath(for: "t", font: font) {
                let bounds = path.boundingBoxOfPath
                context.translateBy(x: rect.midX - bounds.midX, y: rect.midY - bounds.midY)
                context.addPath(path)
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Зелёная точка-бейдж (6×6, #63C470) — отдельный слой поверх иконки,
    /// чтобы её можно было анимировать и не терять template-рендер иконки.
    static func badgeDot() -> NSImage {
        NSImage(size: NSSize(width: 6, height: 6), flipped: false) { rect in
            NSColor(calibratedRed: 0.388, green: 0.769, blue: 0.439, alpha: 1).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }
}
