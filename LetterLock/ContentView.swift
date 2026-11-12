//
//  ContentView.swift
//  LetterLock
//
//  Created by Nahid Rahman on 10/11/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var audio = AudioManager()
    @State private var isConfirmingLeave = false

    /// Lobby and final results leave straight away; mid-match asks first so a stray tap can't end the game.
    private func leave() {
        switch viewModel.gameState {
        case .lobby, .finalResults:
            viewModel.resetToHome()
        default:
            isConfirmingLeave = true
        }
    }

    var body: some View {
        Group {
            switch viewModel.gameState {
            case .home:
                HomeView(viewModel: viewModel)
            case .lobby:
                LobbyView(viewModel: viewModel)
            case .choosingLetter:
                LetterChoiceView(viewModel: viewModel)
            case .playing:
                GameBoardView(viewModel: viewModel)
            case .reveal:
                RevealView(viewModel: viewModel)
            case .finalResults:
                FinalResultsView(viewModel: viewModel)
            }
        }
        // Every screen except Home (which has the big logo) gets the same title bar.
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.gameState != .home {
                TitleBar(audio: audio, onLeave: leave)
            }
        }
        .alert("Leave the game?", isPresented: $isConfirmingLeave) {
            Button("Leave", role: .destructive) { viewModel.resetToHome() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("You'll go back to the main menu and this game will end for you.")
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.gameState == .home {
                MuteButton(audio: audio)
                    .padding(.trailing, 12)
            }
        }
        .environment(audio)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.sounds = audio
            audio.startMusic()
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-DrawDemo") {
                viewModel.showFinalResultsDemo(draw: true)
            }
            if arguments.contains("-ShuffleDemo") || arguments.contains("-PileDemo") {
                viewModel.shuffleStyle = arguments.contains("-PileDemo") ? .pile : .rain
                viewModel.runShuffleDemo()
            }
            #endif
        }
    }
}

/// The LetterLock wordmark centred at the top, with an optional Leave on the left and the mute
/// button on the right. Shared by every screen after Home so the identity stays consistent.
struct TitleBar: View {
    let audio: AudioManager
    var onLeave: (() -> Void)?

    private let sideWidth: CGFloat = 72

    var body: some View {
        HStack(spacing: 0) {
            // Fixed-width slots on both sides keep the wordmark centred whether or not Leave shows.
            ZStack(alignment: .leading) {
                Color.clear
                if let onLeave {
                    Button(action: onLeave) {
                        Text("Leave")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.letterYellow)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                }
            }
            .frame(width: sideWidth, height: 44)

            Spacer(minLength: 0)
            Wordmark()
            Spacer(minLength: 0)

            MuteButton(audio: audio)
                .frame(width: sideWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 74)
        .background(Color.letterNavy)
    }
}

/// The Home tile logo at title-bar size, so every screen carries the same identity.
struct Wordmark: View {
    var body: some View {
        LogoView(tileSize: 20)
    }
}

/// Mutes and unmutes. Long-press to choose the music.
struct MuteButton: View {
    let audio: AudioManager

    var body: some View {
        Button {
            audio.toggleMute()
        } label: {
            Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(audio.isMuted ? Color.letterMuted : Color.letterYellow)
                .frame(width: 36, height: 36)
                .background(Color.letterSurface, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .accessibilityLabel(audio.isMuted ? "Unmute music and sounds" : "Mute music and sounds")
        .accessibilityHint("Touch and hold to choose the music")
        // Long-press to switch tracks from any screen; a tap still mutes.
        .contextMenu {
            Picker("Music", selection: Binding(get: { audio.track }, set: { audio.selectTrack($0) })) {
                ForEach(MusicTrack.allCases) { track in
                    Label(track.title, systemImage: "music.note").tag(track)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
