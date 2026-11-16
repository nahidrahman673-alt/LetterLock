//
//  RainShuffle.swift
//  LetterLock
//

import SwiftUI

/// "Letter Rain & Bounce": tiles rain down from the top of the screen and land on one of three
/// depth floors (back near the top, middle, front at the bottom). From there every filler tile bounces
/// forward down each lower floor like steps and falls off the bottom of the screen. Size and brightness
/// follow screen position, so tiles start small and dim at the back and grow as they come toward you.
/// The chosen letter drops onto the back floor, then bounces forward to take centre stage at the front.
struct RainShuffle: View {
    let letter: String
    let isShuffling: Bool
    let hasChosen: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drops: [Drop] = []
    @State private var chosenAt: Date?
    /// Once the reveal has finished moving, the timeline pauses.
    @State private var isSettled = false

    /// Tile size at perspective scale 1. Actual size grows from about 0.45× at the top of the area
    /// to 1.25× at the bottom (see `perspective(at:)`).
    private static let tileSize: CGFloat = 48
    private static let finalSize: CGFloat = 200
    private static let gravity = 2600.0
    private static let bounciness = 0.5
    /// Long enough for any tile to bounce down every floor and leave the screen.
    private static let lifetime = 4.0
    private static let edges: [Color] = [.letterYellow, .letterMint, .letterCoral, .letterLilac]

    /// Hero timing: lands on the back floor, hops to the middle, then to the front.
    private static let firstHop = 0.85
    private static let hopDuration = 0.42
    private static var revealEnd: Double { firstHop + hopDuration * 2 }

    fileprivate enum Depth: Int, CaseIterable {
        case back, middle, front

        /// Where this floor sits, as a fraction of the area's height.
        var floorLine: Double {
            switch self {
            case .back: 0.36
            case .middle: 0.66
            case .front: 0.97
            }
        }

        /// This floor and every floor in front of it, in the order a tile bounces down them.
        var floorsDownward: [Depth] { Depth.allCases.filter { $0.rawValue >= rawValue } }
    }

    fileprivate struct Drop: Identifiable {
        let id = UUID()
        let letter: String
        let depth: Depth
        /// Across the floor, 0 to 1.
        let x: Double
        let spawn: Date
        let spin: Double
        let edge: Color
        /// Extra height above the top of the screen, so tiles don't all arrive in a line.
        let startAbove: Double
    }

    var body: some View {
        GeometryReader { geometry in
            if reduceMotion {
                LetterTile(letter: hasChosen || isShuffling ? letter : "?", size: Self.finalSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            } else {
                TimelineView(.animation(paused: drops.isEmpty && (chosenAt == nil || isSettled))) { context in
                    // Start above the top of the screen, not just above this area, so tiles fall in from off-screen.
                    scene(at: context.date, in: geometry.size, screenTop: -geometry.frame(in: .global).minY)
                }
            }
        }
        .onChange(of: letter) {
            if letter == "?" {
                drops = []
                chosenAt = nil
            } else if isShuffling {
                spawnDrops()
            }
        }
        .onChange(of: hasChosen) {
            chosenAt = hasChosen ? .now : nil
        }
        .onAppear {
            // Arriving after the letter was chosen: show it already in place.
            if hasChosen { chosenAt = .distantPast }
        }
        .task(id: hasChosen) {
            isSettled = false
            guard hasChosen else { return }
            try? await Task.sleep(for: .seconds(Self.lifetime))
            drops = []
            isSettled = true
        }
    }

    // MARK: - Scene

    /// Every moving tile is drawn into one Canvas each frame. Before, each tile was its own view whose
    /// size changed every frame, so the phone re-laid-out up to ~50 letters per frame, dropped frames,
    /// and the rain looked blurry. A Canvas draws the letters as sharp outlines at any size and angle.
    @ViewBuilder
    private func scene(at now: Date, in size: CGSize, screenTop: CGFloat) -> some View {
        ZStack {
            if drops.isEmpty && chosenAt == nil {
                LetterTile(letter: "?", size: 120)
                    .position(x: size.width / 2, y: size.height - 120 * 1.16 / 2)
            }

            // A Canvas only draws inside its own box, so it reaches up to the top of the screen
            // (tiles fall in from there), out to the sides, and well below the area (tiles bounce out
            // over the buttons and off the bottom). Drawing still uses this area's coordinates.
            let above = max(0, -screenTop) + 200
            let below: CGFloat = 900
            let side: CGFloat = 80
            Canvas { context, _ in
                var context = context
                context.translateBy(x: side, y: above)
                var sprites = drops.map { rainTile($0, now: now, in: size, screenTop: screenTop) }
                if let chosenAt {
                    sprites.append(hero(since: now.timeIntervalSince(chosenAt), in: size, screenTop: screenTop))
                }
                // Lower on screen means closer to the viewer, so it draws on top.
                for sprite in sprites.sorted(by: { $0.layer < $1.layer }) {
                    Self.draw(sprite, in: context)
                }
            }
            .frame(width: size.width + side * 2, height: size.height + above + below)
            .offset(y: (below - above) / 2)
        }
        .frame(width: size.width, height: size.height)
    }

    /// One tile to draw this frame: where its centre is, how big, and how it's turned and shaded.
    private struct Sprite {
        let letter: String
        let center: CGPoint
        /// Width; the face is 1.16 times as tall, with the coloured edge peeking out below.
        let size: CGFloat
        var fill: Color = .letterCream
        let edge: Color
        let tilt: Double
        let dimming: Double
        let layer: Double
    }

    /// Draws a tile exactly like `LetterTile`: coloured edge, cream face, navy letter.
    private static func draw(_ sprite: Sprite, in context: GraphicsContext) {
        var tile = context
        tile.translateBy(x: sprite.center.x, y: sprite.center.y)
        tile.rotate(by: .degrees(sprite.tilt))

        let width = sprite.size
        let height = width * 1.16
        let face = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let corner = width * 0.22
        let faceShape = Path(roundedRect: face, cornerRadius: corner)
        let edgeShape = Path(roundedRect: face.offsetBy(dx: 0, dy: width * 0.1), cornerRadius: corner)

        tile.fill(edgeShape, with: .color(sprite.edge))
        tile.fill(faceShape, with: .color(sprite.fill))
        tile.draw(
            Text(sprite.letter)
                .font(.system(size: width * 0.68, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.letterNavy),
            at: .zero,
            anchor: .center
        )
        if sprite.dimming > 0 {
            var shade = edgeShape
            shade.addPath(faceShape)
            tile.fill(shade, with: .color(.black.opacity(sprite.dimming)))
        }
    }

    private func rainTile(_ drop: Drop, now: Date, in size: CGSize, screenTop: CGFloat) -> Sprite {
        let age = max(0, now.timeIntervalSince(drop.spawn))
        let startY = screenTop - drop.startAbove

        // Rest heights for the tile's centre on its own floor and each floor in front of it.
        let floors = drop.depth.floorsDownward.map { depth in
            let lineY = size.height * depth.floorLine
            return lineY - Self.tileSize * 1.16 * Self.perspective(at: lineY / size.height) / 2
        }
        let y = Self.staircaseY(after: age, from: startY, floors: floors, gravity: Self.gravity, bounciness: Self.bounciness)
        let depthFraction = y / max(1, size.height)
        let scale = Self.perspective(at: depthFraction)
        let width = Self.tileSize * scale

        return Sprite(
            letter: drop.letter,
            center: CGPoint(x: width / 2 + drop.x * max(0, size.width - width), y: y),
            size: width,
            edge: drop.edge,
            tilt: drop.spin * min(age, 2.5),
            dimming: Self.dimming(at: depthFraction),
            layer: depthFraction
        )
    }

    /// Drops onto the back floor, then bounces forward to the middle and front floors, growing as it comes.
    private func hero(since t: Double, in size: CGSize, screenTop: CGFloat) -> Sprite {
        let fullHeight = Self.finalSize * 1.16
        let backScale = Self.tileSize * Self.perspective(at: Depth.back.floorLine) / Self.finalSize
        let middleScale = Self.tileSize * Self.perspective(at: Depth.middle.floorLine) / Self.finalSize * 1.6

        func restY(_ depth: Depth, scale: Double) -> Double {
            size.height * depth.floorLine - fullHeight * scale / 2
        }

        let backY = restY(.back, scale: backScale)
        let middleY = restY(.middle, scale: middleScale)
        let frontY = restY(.front, scale: 1)

        var y: Double
        var scale: Double
        var brightness: Double
        var layer: Double

        if t < Self.firstHop {
            // Falls from the top of the screen onto the back floor, small and dim.
            let startY = screenTop - fullHeight * backScale
            y = backY - Self.heightAboveFloor(after: t, droppedFrom: backY - startY, gravity: 3000, bounciness: 0.4)
            scale = backScale
            brightness = Self.dimming(at: Depth.back.floorLine)
            layer = Depth.back.floorLine + 0.01
        } else if t < Self.firstHop + Self.hopDuration {
            // Hop 1: back to middle.
            let p = (t - Self.firstHop) / Self.hopDuration
            y = Self.lerp(backY, middleY, p) - sin(p * .pi) * 70
            scale = Self.lerp(backScale, middleScale, Self.easeOutCubic(p))
            brightness = Self.lerp(Self.dimming(at: Depth.back.floorLine), Self.dimming(at: Depth.middle.floorLine), p)
            layer = Depth.middle.floorLine + 0.01
        } else {
            // Hop 2: middle to front, growing to full size with a little overshoot.
            let p = min(1, (t - Self.firstHop - Self.hopDuration) / Self.hopDuration)
            y = Self.lerp(middleY, frontY, p) - sin(p * .pi) * 110
            scale = middleScale + (1 - middleScale) * Self.easeOutBack(p)
            brightness = Self.lerp(Self.dimming(at: Depth.middle.floorLine), 0, p)
            layer = 10
        }

        return Sprite(
            letter: letter,
            center: CGPoint(x: size.width / 2, y: y),
            size: Self.finalSize * scale,
            edge: .letterYellow,
            tilt: 0,
            dimming: brightness,
            layer: layer
        )
    }

    // MARK: - Spawning

    private func spawnDrops() {
        let now = Date.now
        drops.removeAll { now.timeIntervalSince($0.spawn) > Self.lifetime }
        for index in 0..<3 {
            drops.append(Drop(
                letter: index == 0 ? letter : (GameViewModel.letterPool.randomElement() ?? "A"),
                depth: Depth.allCases[index],
                x: Double.random(in: 0...1),
                spawn: now.addingTimeInterval(Double(index) * 0.05),
                spin: Double.random(in: -35...35),
                edge: Self.edges.randomElement() ?? .letterYellow,
                startAbove: Double.random(in: 0...120)
            ))
        }
    }

    // MARK: - Physics and easing

    /// Height above the floor for something dropped from `height`, bouncing a few times.
    private static func heightAboveFloor(after t: Double, droppedFrom height: Double, gravity: Double, bounciness: Double) -> Double {
        let firstImpact = (2 * max(0, height) / gravity).squareRoot()
        if t < firstImpact { return height - 0.5 * gravity * t * t }
        var speed = gravity * firstImpact * bounciness
        var remaining = t - firstImpact
        for _ in 0..<6 {
            let flight = 2 * speed / gravity
            if remaining < flight { return speed * remaining - 0.5 * gravity * remaining * remaining }
            remaining -= flight
            speed *= bounciness
        }
        return 0
    }

    /// Position down the stack of floors: falls to the first floor, bounces, falls to the next,
    /// and after the last floor keeps falling (off the bottom of the screen). Y grows downward.
    private static func staircaseY(after t: Double, from startY: Double, floors: [Double], gravity: Double, bounciness: Double) -> Double {
        var y = startY
        var velocity = 0.0
        var remaining = t
        for floor in floors {
            let distance = floor - y
            let timeToFloor = (-velocity + (velocity * velocity + 2 * gravity * max(0, distance)).squareRoot()) / gravity
            if remaining < timeToFloor {
                return y + velocity * remaining + 0.5 * gravity * remaining * remaining
            }
            remaining -= timeToFloor
            let impactSpeed = velocity + gravity * timeToFloor
            y = floor
            velocity = -impactSpeed * bounciness
        }
        return y + velocity * remaining + 0.5 * gravity * remaining * remaining
    }

    /// Perspective scale for a point `fraction` of the way down the area (0 = top, 1 = bottom, more = below it).
    private static func perspective(at fraction: Double) -> Double {
        0.45 + 0.8 * max(0, fraction)
    }

    /// Further away (higher up) is dimmer: how dark the shade over the tile is, 0 to 0.3.
    private static func dimming(at fraction: Double) -> Double {
        0.3 * (1 - min(1, max(0, fraction)))
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private static func easeOutCubic(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

    private static func easeOutBack(_ t: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }
}

// The demo only exists in Debug builds, so this preview does too (it broke the Release build).
#if DEBUG
#Preview("Rain on repeat") {
    let viewModel = GameViewModel()
    viewModel.runShuffleDemo()
    return LetterChoiceView(viewModel: viewModel)
}
#endif
