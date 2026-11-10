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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(Color.letterNavy)
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
