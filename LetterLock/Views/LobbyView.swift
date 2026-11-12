//
//  LobbyView.swift
//  LetterLock
//

import SwiftUI

struct LobbyView: View {
    @Bindable var viewModel: GameViewModel
    @Environment(AudioManager.self) private var audio
    @State private var isEditingName = false

    var body: some View {
        // The whole page scrolls so every player can be reached, even with 8 in the room.
        // Start Game stays fixed at the bottom.
        ScrollView {
            VStack(spacing: 18) {
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
                phoneSettings

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

                VStack(spacing: 8) {
                    ForEach(viewModel.players) { player in
                        if player.isLocal {
                            // Tap your own name to change it.
                            Button { isEditingName = true } label: {
                                PlayerRow(player: player)
                            }
                            .accessibilityHint("Change your name")
                        } else {
                            PlayerRow(player: player)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
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
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.letterNavy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .sheet(isPresented: $isEditingName) {
            NameEntryView(viewModel: viewModel, buttonTitle: "Save") {}
        }
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
                .frame(width: 150)
                .disabled(!viewModel.isLocalHost)
            }

            HStack {
                Text("Round timer")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
                Spacer()
                Picker("Round timer", selection: $viewModel.roundSeconds) {
                    ForEach(GameViewModel.timerOptions, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .disabled(!viewModel.isLocalHost)
            }
        }
        .padding(14)
        .background(Color.letterSurface, in: .rect(cornerRadius: 12))
    }

    /// Personal preferences, so anyone can change them, not just the host.
    private var phoneSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ON THIS PHONE")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)

            // Music only; sound effects keep playing. The mute button silences both.
            Toggle(isOn: Binding(get: { audio.isMusicOn }, set: { audio.setMusicOn($0) })) {
                Text("Background music")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
            }
            .tint(Color.letterMint)
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

            if player.isLocal {
                Image(systemName: "pencil")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.letterYellow)
                    .accessibilityHidden(true)
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
        .environment(AudioManager())
}

#Preview("Guest") {
    let viewModel = GameViewModel()
    viewModel.joinGame(code: "ABCD")
    return LobbyView(viewModel: viewModel)
        .environment(AudioManager())
}
