// Renders the Peek-Slides app icon (Branding/AppIcon.svg, direction A:
// the Audiopeek peak peeking out of a slide) into AppIcon.appiconset.
//
//   swift apps/mac/scripts/render-app-icon.swift
//
// Geometry is on the 1024 macOS icon grid and mirrors Branding/AppIcon.svg;
// change both together.

import AppKit

let ink = CGColor(srgbRed: 0x0B / 255, green: 0x2A / 255, blue: 0x33 / 255, alpha: 1)
let paper = CGColor(srgbRed: 0xEE / 255, green: 0xF1 / 255, blue: 0xF0 / 255, alpha: 1)
let cyanBright = CGColor(srgbRed: 0x3F / 255, green: 0xD7 / 255, blue: 0xDC / 255, alpha: 1)

/// Draws in SVG coordinates (origin top-left, 1024 units).
func drawIcon(in ctx: CGContext) {
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)

    func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
    }
    func fill(_ path: CGPath, _ color: CGColor) {
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    fill(rounded(100, 100, 824, 824, 185), ink)

    // Slide frame (stroke centred on the rect, like SVG).
    ctx.addPath(rounded(226, 372, 572, 322, 22))
    ctx.setStrokeColor(paper)
    ctx.setLineWidth(26)
    ctx.strokePath()

    // Peak: 14 · 24 · 36 · 50 proportions; the centre bar is drawn last.
    for (x, y, h) in [(314, 572, 70), (374, 522, 120), (434, 462, 180),
                      (554, 462, 180), (614, 522, 120), (674, 572, 70)] as [(CGFloat, CGFloat, CGFloat)] {
        fill(rounded(x, y, 36, h, 12), paper)
    }
    // Ink halo cuts the frame where the centre bar peeks out.
    fill(rounded(480, 300, 64, 342, 12), ink)
    fill(rounded(494, 300, 36, 342, 12), cyanBright)
}

func png(size: Int) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconSet = scriptDir.appendingPathComponent("../Assets.xcassets/AppIcon.appiconset").standardized

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try png(size: base * scale).write(to: iconSet.appendingPathComponent(name))
        print("wrote \(name) (\(base * scale)px)")
    }
}
