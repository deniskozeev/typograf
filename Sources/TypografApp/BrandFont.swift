import AppKit
import SwiftUI

/// Фирменный шрифт Literata из ресурсов — для иконки в менюбаре.
enum BrandFont {

    /// Оси вариативности: вес и оптический размер.
    private static let weightAxis = 0x7767_6874  // 'wght'
    private static let opticalAxis = 0x6F70_737A // 'opsz'

    static func register() {
        guard let url = Bundle.module.url(forResource: "Literata", withExtension: "ttf") else {
            NSLog("Typograf: Literata.ttf not found in bundle")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Literata — вариативный шрифт: вес и оптический размер задаются осями,
    /// обычные weight-трейты дескриптора на него не действуют.
    /// Малый opticalSize делает штрихи плотнее — то, что нужно для 16 px.
    static func nsFont(size: CGFloat, weight: CGFloat = 700, opticalSize: CGFloat = 12) -> NSFont {
        guard let base = NSFont(name: "Literata", size: size)
            ?? NSFont(name: "Literata-Regular", size: size) else {
            return .systemFont(ofSize: size, weight: .bold)
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
                NSNumber(value: weightAxis): weight,
                NSNumber(value: opticalAxis): opticalSize
            ]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    /// Векторный контур глифа — для точного оптического центрирования.
    static func glyphPath(for character: Character, font: NSFont) -> CGPath? {
        var chars = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count),
              let glyph = glyphs.first else { return nil }
        return CTFontCreatePathForGlyph(font, glyph, nil)
    }

    /// Template-иконка менюбара по макету: сквиркл контуром 16×16 (штрих 1.3),
    /// заглавная «T» Literata Bold по центру.
    static func statusBarIcon() -> NSImage {
        let side: CGFloat = 16
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            // Сквиркл на весь холст, штрих 1.3pt по внутреннему краю.
            let outline = rect.insetBy(dx: 0.65, dy: 0.65)
            context.addPath(CGPath(
                roundedRect: outline,
                cornerWidth: 4.4,
                cornerHeight: 4.4,
                transform: nil
            ))
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.3)
            context.strokePath()

            // «T» — 11pt bold, малый оптический размер, оптически по центру.
            let font = nsFont(size: 11, weight: 700, opticalSize: 8)
            if let path = glyphPath(for: "T", font: font) {
                let bounds = path.boundingBoxOfPath
                context.saveGState()
                context.translateBy(x: rect.midX - bounds.midX, y: rect.midY - bounds.midY)
                context.addPath(path)
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()
                context.restoreGState()
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
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(CGColor(red: 0.39, green: 0.77, blue: 0.44, alpha: 1))
            context.fillEllipse(in: rect)
            return true
        }
    }
}
