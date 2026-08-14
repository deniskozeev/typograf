// Рисует фон DMG-окна (660×400): пунктирная контурная стрелка между
// иконкой приложения и папкой «Программы» (иконки Finder рисует сам).
// Пишет 1x и 2x PNG для последующей склейки в HiDPI-TIFF.
// Использование: swift scripts/make-dmg-background.swift <outdir>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/dmg-bg"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(scale: CGFloat) -> NSImage {
    let w: CGFloat = 660, h: CGFloat = 400
    let image = NSImage(size: NSSize(width: w * scale, height: h * scale), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        ctx.scaleBy(x: scale, y: scale)

        ctx.setFillColor(CGColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Контурная блок-стрелка пунктиром, по центру между иконками
        // (центры иконок: {165, 185} и {495, 185} от верхнего левого угла).
        let cy: CGFloat = h - 185
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 284, y: cy + 18))
        arrow.addLine(to: CGPoint(x: 330, y: cy + 18))
        arrow.addLine(to: CGPoint(x: 330, y: cy + 40))
        arrow.addLine(to: CGPoint(x: 376, y: cy))
        arrow.addLine(to: CGPoint(x: 330, y: cy - 40))
        arrow.addLine(to: CGPoint(x: 330, y: cy - 18))
        arrow.addLine(to: CGPoint(x: 284, y: cy - 18))
        arrow.closeSubpath()

        ctx.addPath(arrow)
        ctx.setStrokeColor(CGColor(gray: 0.55, alpha: 1))
        ctx.setLineWidth(1.6)
        ctx.setLineDash(phase: 0, lengths: [5, 4])
        ctx.setLineJoin(.round)
        ctx.strokePath()
        return true
    }
    return image
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = NSSize(width: 660, height: 400)
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try! png.write(to: URL(fileURLWithPath: path))
}

writePNG(draw(scale: 1), to: "\(outDir)/bg-1x.png")
writePNG(draw(scale: 2), to: "\(outDir)/bg-2x.png")
print("backgrounds written to \(outDir)")
