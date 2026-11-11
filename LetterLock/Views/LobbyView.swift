//
//  LobbyView.swift
//  LetterLock
//

import SwiftUI

struct LobbyView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 18) {
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
            }

            settings

            HStack {
                Text("PLAYERS \(viewModel.players.count)/\(GameViewModel.playerLimit.upperBound)")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(Color.letterMuted)
                Spacer()
                if viewModel.isLocalHost {
                    testPlayerControls
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.players) { player in
                        PlayerRow(player: player)
                    }
                }
            }
            .scrollIndicators(.hidden)

            HostActionButton(
                viewModel: viewModel,
                title: "Start Game",
                waitingText: "Waiting for the host to start",
                isEnabled: viewModel.canStartGame
            ) { hostId in
                viewModel.startGame(by: hostId)
            }

            if !viewModel.canStartGame {
                Text("You need at least \(GameViewModel.playerLimit.lowerBound) players.")
                    .font(.footnote)
                    .foregroundStyle(Color.letterMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
    }

    private var settings: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Rounds")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
                Spacer()
                Picker("Rounds", selection: $viewModel.totalRounds) {
                    ForEach(GameViewModel.roundOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .disabled(!viewModel.isLocalHost)
            }

            HStack {
                Text("Round timer")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
                Spacer()
                Text("\(GameViewModel.roundDuration) seconds")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterMuted)
            }
        }
        .padding(14)
        .background(Color.letterSurface, in: .rect(cornerRadius: 12))
    }

    private var testPlayerControls: some View {
        HStack(spacing: 4) {
            Text("Test players")
                .font(.caption)
                .foregroundStyle(Color.letterMuted)
            Button {
                viewModel.removeTestPlayer()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.players.count <= GameViewModel.playerLimit.lowerBound)
            .accessibilityLabel("Remove a test player")

            Button {
                viewModel.addTestPlayer()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canAddPlayer)
            .accessibilityLabel("Add a test player")
        }
        .font(.title3)
        .foregroundStyle(Color.letterYellow)
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
                HostBadge()
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

#Preview("Host") {
    LobbyView(viewModel: .preview(.lobby))
}

#Preview("Guest") {
    let viewModel = GameViewModel()
    viewModel.joinGame(code: "ABCD")
    return LobbyView(viewModel: viewModel)
}
