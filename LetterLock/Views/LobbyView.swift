//
//  LobbyView.swift
//  LetterLock
//

import SwiftUI

struct LobbyView: View {
    @Bindable var viewModel: GameViewModel
    @Environment(AudioManager.self) private var audio

    var body: some View {
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
        .padding(.top, 4)
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
                Picker("Round timer", selection: $viewModel.roundSeconds) {
                    ForEach(GameViewModel.timerOptions, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
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

            HStack {
                Text("Shuffle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
                Spacer()
                Picker("Shuffle animation", selection: $viewModel.shuffleStyle) {
                    ForEach(ShuffleStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            // Music only; sound effects keep playing so the Time's up options can be heard on their own.
            Toggle(isOn: Binding(get: { audio.isMusicOn }, set: { audio.setMusicOn($0) })) {
                Text("Background music")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
            }
            .tint(Color.letterMint)

            HStack {
                Text("Music")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
                Spacer()
                // Too many options for a segmented control, so a menu.
                Picker("Music", selection: Binding(get: { audio.track }, set: { audio.selectTrack($0) })) {
                    ForEach(MusicTrack.allCases) { track in
                        Text(track.title).tag(track)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.letterYellow)
                .lineLimit(1)
                .fixedSize()
            }

            HStack {
                Text("Time's up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.letterCream)
                Spacer()
                // Choosing a sound plays it, so the options can be compared one after another.
                Picker("Time's up sound", selection: Binding(get: { audio.endSound }, set: { audio.selectEndSound($0) })) {
                    ForEach(EndSound.allCases) { sound in
                        Text(sound.title).tag(sound)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.letterYellow)
                .lineLimit(1)
                .fixedSize()
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
        .environment(AudioManager())
}

#Preview("Guest") {
    let viewModel = GameViewModel()
    viewModel.joinGame(code: "ABCD")
    return LobbyView(viewModel: viewModel)
        .environment(AudioManager())
}
