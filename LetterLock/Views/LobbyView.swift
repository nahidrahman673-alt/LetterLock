//
//  LobbyView.swift
//  LetterLock
//

import SwiftUI

struct LobbyView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    viewModel.resetToHome()
                } label: {
                    Text("Leave")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.letterYellow)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                Text("ROOM CODE")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(Color.letterMuted)

                HStack(spacing: 8) {
                    ForEach(Array(viewModel.roomCode.enumerated()), id: \.offset) { _, character in
                        LetterTile(letter: String(character), size: 56)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Room code \(viewModel.roomCode)")

                Text("Think alike. Don't.")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.letterCream)
                    .padding(.top, 10)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.players) { player in
                        PlayerRow(player: player)
                    }
                }
            }

            Button("Start Round") {
                viewModel.startRound()
            }
            .buttonStyle(FilledGameButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
    }
}

private struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 8) {
            Text(player.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.letterCream)

            if player.isHost {
                Text("Host")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.letterNavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.letterYellow, in: .capsule)
            }

            Spacer()

            Text(player.isReady ? "Ready" : "Waiting")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(player.isReady ? Color.letterMint : Color.letterMuted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Color.letterSurface, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    LobbyView(viewModel: .preview(.lobby))
}
