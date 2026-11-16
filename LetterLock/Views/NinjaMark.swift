//
//  NinjaMark.swift
//  LetterLock
//

import SwiftUI

/// The Alphabet Assassin mark: a capital A as a ninja, with a cream eye wrap, narrowed eyes and a
/// coral headband, standing on a yellow edge like the letter tiles. Drawn from the same shapes as
/// the logo in Canva and on the design canvas (a 210 × 200 grid), so it stays sharp at any size.
struct NinjaMark: View {
    var size: CGFloat = 150
    /// Shows through the triangle inside the A, so it should match what the mark sits on.
    var hole: Color = .letterNavy

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 210, y: canvasSize.height / 200)
            context.fill(Self.body(dropBy: 10), with: .color(.letterYellow))
            context.fill(Self.body(dropBy: 0), with: .color(.letterSurface))
            context.fill(Self.counter, with: .color(hole))
            context.fill(Self.tailTop, with: .color(.letterCoral))
            context.fill(Self.tailBottom, with: .color(.letterCoral))

            // The headband and the eye wrap tilt slightly, like the mascot's head is cocked.
            var band = context
            band.tilt(by: -4, around: CGPoint(x: 105, y: 49))
            band.fill(Path(roundedRect: CGRect(x: 66, y: 44, width: 78, height: 10), cornerRadius: 5), with: .color(.letterCoral))

            var wrap = context
            wrap.tilt(by: -4, around: CGPoint(x: 105, y: 77))
            wrap.fill(Path(roundedRect: CGRect(x: 56, y: 62, width: 98, height: 30), cornerRadius: 15), with: .color(.letterCream))
            wrap.fill(Self.leftEye, with: .color(.letterNavy))
            wrap.fill(Self.rightEye, with: .color(.letterNavy))
        }
        .frame(width: size, height: size * 200 / 210)
        .accessibilityHidden(true)
    }

    // MARK: - Shapes, in the 210 × 200 grid

    private static func body(dropBy dy: CGFloat) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y + dy) }
        var path = Path()
        path.move(to: p(105, 18))
        path.addCurve(to: p(121, 30), control1: p(113, 18), control2: p(117, 22))
        path.addLine(to: p(181, 160))
        path.addCurve(to: p(169, 176), control1: p(185, 170), control2: p(179, 176))
        path.addLine(to: p(139, 176))
        path.addCurve(to: p(126, 166), control1: p(132, 176), control2: p(128, 172))
        path.addLine(to: p(119, 146))
        path.addLine(to: p(91, 146))
        path.addLine(to: p(84, 166))
        path.addCurve(to: p(71, 176), control1: p(82, 172), control2: p(78, 176))
        path.addLine(to: p(41, 176))
        path.addCurve(to: p(29, 160), control1: p(31, 176), control2: p(25, 170))
        path.addLine(to: p(89, 30))
        path.addCurve(to: p(105, 18), control1: p(93, 22), control2: p(97, 18))
        path.closeSubpath()
        return path
    }

    private static let counter = Path { path in
        path.move(to: CGPoint(x: 105, y: 100))
        path.addLine(to: CGPoint(x: 116, y: 128))
        path.addLine(to: CGPoint(x: 94, y: 128))
        path.closeSubpath()
    }

    private static let tailTop = Path { path in
        path.move(to: CGPoint(x: 140, y: 46))
        path.addCurve(to: CGPoint(x: 176, y: 20), control1: CGPoint(x: 156, y: 40), control2: CGPoint(x: 168, y: 30))
        path.addLine(to: CGPoint(x: 179, y: 28))
        path.addCurve(to: CGPoint(x: 144, y: 54), control1: CGPoint(x: 172, y: 40), control2: CGPoint(x: 160, y: 50))
        path.closeSubpath()
    }

    private static let tailBottom = Path { path in
        path.move(to: CGPoint(x: 142, y: 51))
        path.addCurve(to: CGPoint(x: 178, y: 74), control1: CGPoint(x: 158, y: 54), control2: CGPoint(x: 170, y: 62))
        path.addLine(to: CGPoint(x: 170, y: 76))
        path.addCurve(to: CGPoint(x: 140, y: 57), control1: CGPoint(x: 162, y: 66), control2: CGPoint(x: 154, y: 60))
        path.closeSubpath()
    }

    private static let leftEye = Path { path in
        path.move(to: CGPoint(x: 74, y: 76))
        path.addLine(to: CGPoint(x: 98, y: 80))
        path.addCurve(to: CGPoint(x: 86, y: 87), control1: CGPoint(x: 96, y: 86), control2: CGPoint(x: 91, y: 88))
        path.addCurve(to: CGPoint(x: 74, y: 76), control1: CGPoint(x: 79, y: 86), control2: CGPoint(x: 75, y: 82))
        path.closeSubpath()
    }

    private static let rightEye = Path { path in
        path.move(to: CGPoint(x: 136, y: 76))
        path.addLine(to: CGPoint(x: 112, y: 80))
        path.addCurve(to: CGPoint(x: 124, y: 87), control1: CGPoint(x: 114, y: 86), control2: CGPoint(x: 119, y: 88))
        path.addCurve(to: CGPoint(x: 136, y: 76), control1: CGPoint(x: 131, y: 86), control2: CGPoint(x: 135, y: 82))
        path.closeSubpath()
    }
}

private extension GraphicsContext {
    /// Rotates everything drawn after this by `degrees` around `point`.
    mutating func tilt(by degrees: Double, around point: CGPoint) {
        translateBy(x: point.x, y: point.y)
        rotate(by: .degrees(degrees))
        translateBy(x: -point.x, y: -point.y)
    }
}

#Preview {
    NinjaMark()
        .padding(40)
        .background(Color.letterNavy)
}
