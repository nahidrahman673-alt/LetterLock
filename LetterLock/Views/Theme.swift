//
//  Theme.swift
//  LetterLock
//

import SwiftUI

extension Color {
    static let letterNavy = Color(hex: 0x121324)
    static let letterSurface = Color(hex: 0x231E45)
    static let letterBorder = Color(hex: 0x3A3368)
    static let letterCream = Color(hex: 0xFFF7E6)
    static let letterMuted = Color(hex: 0xB9B2D9)
    static let letterYellow = Color(hex: 0xFFD23F)
    static let letterMint = Color(hex: 0x3DDBB4)
    static let letterCoral = Color(hex: 0xFF6B5B)
    static let letterLilac = Color(hex: 0xB79CFF)

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct FilledGameButtonStyle: ButtonStyle {
    var fill: Color = .letterYellow
    var text: Color = .letterNavy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(fill, in: .rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OutlinedGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Color.letterCream)
            .frame(maxWidth: .infinity, minHeight: 54)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.letterCream, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct HostBadge: View {
    var body: some View {
        Text("Host")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.letterNavy)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.letterYellow, in: .capsule)
    }
}

/// A button only the host can press. Guests see a waiting message, plus a prototype-only
/// shortcut that presses it on the host's behalf so the flow can be tested on one phone.
struct HostActionButton: View {
    let viewModel: GameViewModel
    let title: String
    let waitingText: String
    var isEnabled = true
    let action: (UUID) -> Void

    var body: some View {
        if viewModel.isLocalHost, let localPlayer = viewModel.localPlayer {
            Button(title) {
                action(localPlayer.id)
            }
            .buttonStyle(FilledGameButtonStyle())
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
        } else if let host = viewModel.hostPlayer {
            VStack(spacing: 4) {
                Text("\(waitingText)…")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.letterMuted)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.letterSurface, in: .rect(cornerRadius: 16))

                Button("Prototype: tap as \(host.name)") {
                    action(host.id)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.letterYellow)
                .frame(minHeight: 44)
                .disabled(!isEnabled)
            }
        }
    }
}

/// A single letter tile, used for the logo, room code and round letter.
struct LetterTile: View {
    let letter: String
    var size: CGFloat = 46
    var fill: Color = .letterCream
    var edge: Color = .letterYellow
    var tilt: Double = 0

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.68, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.letterNavy)
            .frame(width: size, height: size * 1.16)
            .background {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(fill)
                    .shadow(color: edge, radius: 0, y: size * 0.1)
            }
            .rotationEffect(.degrees(tilt))
    }
}
