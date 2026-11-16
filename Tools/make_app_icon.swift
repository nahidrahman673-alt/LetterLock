// Draws the Alphabet Assassin app icon (the ninja A on navy) as a 1024 × 1024 PNG.
// Uses the same shapes as NinjaMark.swift (a 210 × 200 grid).
// Run: swift Tools/make_app_icon.swift LetterLock/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let side = 1024

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let navy = rgb(0x121324), surface = rgb(0x231E45), cream = rgb(0xFFF7E6)
let yellow = rgb(0xFFD23F), coral = rgb(0xFF6B5B)

guard let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("Could not make a drawing surface") }

// Flip so y goes down, like the design grid.
context.translateBy(x: 0, y: CGFloat(side))
context.scaleBy(x: 1, y: -1)

context.setFillColor(navy)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

// The mark fills about three quarters of the icon, centred on the A itself (grid y 18 to 186).
let scale: CGFloat = 3.62
context.translateBy(x: (CGFloat(side) - 210 * scale) / 2, y: CGFloat(side) / 2 - 102 * scale)
context.scaleBy(x: scale, y: scale)

func fill(_ color: CGColor, _ build: (CGMutablePath) -> Void) {
    let path = CGMutablePath()
    build(path)
    context.addPath(path)
    context.setFillColor(color)
    context.fillPath()
}

func body(_ dy: CGFloat) -> (CGMutablePath) -> Void {
    { p in
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y + dy) }
        p.move(to: pt(105, 18))
        p.addCurve(to: pt(121, 30), control1: pt(113, 18), control2: pt(117, 22))
        p.addLine(to: pt(181, 160))
        p.addCurve(to: pt(169, 176), control1: pt(185, 170), control2: pt(179, 176))
        p.addLine(to: pt(139, 176))
        p.addCurve(to: pt(126, 166), control1: pt(132, 176), control2: pt(128, 172))
        p.addLine(to: pt(119, 146))
        p.addLine(to: pt(91, 146))
        p.addLine(to: pt(84, 166))
        p.addCurve(to: pt(71, 176), control1: pt(82, 172), control2: pt(78, 176))
        p.addLine(to: pt(41, 176))
        p.addCurve(to: pt(29, 160), control1: pt(31, 176), control2: pt(25, 170))
        p.addLine(to: pt(89, 30))
        p.addCurve(to: pt(105, 18), control1: pt(93, 22), control2: pt(97, 18))
        p.closeSubpath()
    }
}

fill(yellow, body(10))
fill(surface, body(0))
fill(navy) { p in
    p.move(to: CGPoint(x: 105, y: 100))
    p.addLine(to: CGPoint(x: 116, y: 128))
    p.addLine(to: CGPoint(x: 94, y: 128))
    p.closeSubpath()
}
fill(coral) { p in
    p.move(to: CGPoint(x: 140, y: 46))
    p.addCurve(to: CGPoint(x: 176, y: 20), control1: CGPoint(x: 156, y: 40), control2: CGPoint(x: 168, y: 30))
    p.addLine(to: CGPoint(x: 179, y: 28))
    p.addCurve(to: CGPoint(x: 144, y: 54), control1: CGPoint(x: 172, y: 40), control2: CGPoint(x: 160, y: 50))
    p.closeSubpath()
}
fill(coral) { p in
    p.move(to: CGPoint(x: 142, y: 51))
    p.addCurve(to: CGPoint(x: 178, y: 74), control1: CGPoint(x: 158, y: 54), control2: CGPoint(x: 170, y: 62))
    p.addLine(to: CGPoint(x: 170, y: 76))
    p.addCurve(to: CGPoint(x: 140, y: 57), control1: CGPoint(x: 162, y: 66), control2: CGPoint(x: 154, y: 60))
    p.closeSubpath()
}

func tilted(around center: CGPoint, _ draw: () -> Void) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: -4 * .pi / 180)
    context.translateBy(x: -center.x, y: -center.y)
    draw()
    context.restoreGState()
}

tilted(around: CGPoint(x: 105, y: 49)) {
    fill(coral) { $0.addRoundedRect(in: CGRect(x: 66, y: 44, width: 78, height: 10), cornerWidth: 5, cornerHeight: 5) }
}
tilted(around: CGPoint(x: 105, y: 77)) {
    fill(cream) { $0.addRoundedRect(in: CGRect(x: 56, y: 62, width: 98, height: 30), cornerWidth: 15, cornerHeight: 15) }
    fill(navy) { p in
        p.move(to: CGPoint(x: 74, y: 76))
        p.addLine(to: CGPoint(x: 98, y: 80))
        p.addCurve(to: CGPoint(x: 86, y: 87), control1: CGPoint(x: 96, y: 86), control2: CGPoint(x: 91, y: 88))
        p.addCurve(to: CGPoint(x: 74, y: 76), control1: CGPoint(x: 79, y: 86), control2: CGPoint(x: 75, y: 82))
        p.closeSubpath()
    }
    fill(navy) { p in
        p.move(to: CGPoint(x: 136, y: 76))
        p.addLine(to: CGPoint(x: 112, y: 80))
        p.addCurve(to: CGPoint(x: 124, y: 87), control1: CGPoint(x: 114, y: 86), control2: CGPoint(x: 119, y: 88))
        p.addCurve(to: CGPoint(x: 136, y: 76), control1: CGPoint(x: 131, y: 86), control2: CGPoint(x: 135, y: 82))
        p.closeSubpath()
    }
}

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("Could not write \(output)") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not save \(output)") }
print("Saved \(output)")
