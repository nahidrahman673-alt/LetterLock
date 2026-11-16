//
//  HomeView.swift
//  LetterLock
//

import SwiftUI

struct HomeView: View {
    let viewModel: GameViewModel

    @State private var isShowingHowToPlay = false
    @State private var isShowingJoinPrompt = false
    @State private var joinCode = ""
    /// What to do once the player has given their name (asked only the first time).
    @State private var afterName: HomeAction?

    private enum HomeAction: Identifiable {
        case start, join
        var id: Self { self }
    }

    private func perform(_ action: HomeAction) {
        switch action {
        case .start:
            viewModel.startNewGame()
        case .join:
            joinCode = ""
            isShowingJoinPrompt = true
        }
    }

    private func request(_ action: HomeAction) {
        if viewModel.hasPlayerName { perform(action) } else { afterName = action }
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 16)

            LogoView()

            // "No witnesses." in yellow to match the ASSASSIN tiles in the title.
            Text("One letter. Ten targets.\n\(Text("No witnesses.").foregroundStyle(Color.letterYellow))")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.letterCream)
                .padding(.top, 12)

            ViewThatFits {
                HStack(spacing: 8) { scoringPills }
                VStack(spacing: 8) { scoringPills }
            }
            .padding(.top, 6)

            Spacer(minLength: 16)

            Button("Start a game") {
                request(.start)
            }
            .buttonStyle(FilledGameButtonStyle())

            Button("Join with a code") {
                request(.join)
            }
            .buttonStyle(OutlinedGameButtonStyle())

            Button {
                isShowingHowToPlay = true
            } label: {
                Text("How to play")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.letterYellow)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .sheet(isPresented: $isShowingHowToPlay) {
            HowToPlaySheet()
        }
        // Its own page, the first time only. Carries on with Start or Join once the name is saved.
        .fullScreenCover(item: $afterName) { action in
            NameEntryView(viewModel: viewModel) {
                // Wait for the page to close before moving on, so the join prompt can appear.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { perform(action) }
            }
        }
        .alert("Join a game", isPresented: $isShowingJoinPrompt) {
            TextField("Room code", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Join") {
                viewModel.joinGame(code: joinCode)
            }
            .disabled(!GameViewModel.isValidRoomCode(joinCode))
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the 4-character code from your host.")
        }
    }

    @ViewBuilder
    private var scoringPills: some View {
        ScoringPill(text: "+10 unseen", fill: .letterYellow)
        ScoringPill(text: "+5 shared", fill: .letterMint)
        ScoringPill(text: "0 if 3 match", fill: .letterCoral)
    }
}

/// The Alphabet Assassin logo on Home: the ninja A above ALPHABET (cream tiles) and ASSASSIN
/// (yellow tiles). The first time Home appears after the app opens, the pieces roll in one
/// after another with the rain shuffle's clack, and its landing thud once the last tile settles.
struct LogoView: View {
    @Environment(AudioManager.self) private var audio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The intro plays once per app launch, not every time a player comes back to Home.
    private static var hasPlayedIntro = false

    @State private var isIn = LogoView.hasPlayedIntro

    private static let tileSize: CGFloat = 36
    /// When the ninja A starts rolling in, then each tile follows this far apart.
    private static let firstTileDelay = 0.3
    private static let tileGap = 0.07

    var body: some View {
        VStack(spacing: 20) {
            NinjaMark(size: 150)
                .rollIn(isIn, delay: 0, distance: 140)

            AssassinTiles(tileSize: Self.tileSize) { index, tile in
                tile.rollIn(isIn, delay: Self.firstTileDelay + Double(index) * Self.tileGap)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alphabet Assassin")
        .accessibilityAddTraits(.isHeader)
        .task { await playIntro() }
    }

    private func playIntro() async {
        guard !Self.hasPlayedIntro else { return }
        Self.hasPlayedIntro = true
        // Reduce Motion: no rolling, the logo is simply there.
        guard !reduceMotion else {
            isIn = true
            return
        }

        isIn = true
        try? await Task.sleep(for: .seconds(Self.firstTileDelay))
        for _ in 0..<AssassinTiles<LetterTile>.count {
            audio.play(.clack)
            try? await Task.sleep(for: .seconds(Self.tileGap))
        }
        try? await Task.sleep(for: .seconds(0.25))
        audio.play(.land)
    }
}

/// ALPHABET over ASSASSIN in level letter tiles: 8 over 8, so the rows line up exactly.
/// `decorate` lets Home add its roll-in to each tile (numbered 0 to 15, left to right, top row first).
struct AssassinTiles<Tile: View>: View {
    static var count: Int { 16 }

    let tileSize: CGFloat
    var decorate: (Int, LetterTile) -> Tile

    private static var topEdges: [Color] { [.letterYellow, .letterMint, .letterCoral, .letterLilac] }

    var body: some View {
        let scale = tileSize / 36
        VStack(spacing: 10 * scale) {
            HStack(spacing: 4 * scale) {
                ForEach(Array("ALPHABET".enumerated()), id: \.offset) { index, letter in
                    decorate(index, LetterTile(letter: String(letter), size: tileSize, edge: Self.topEdges[index % 4]))
                }
            }
            HStack(spacing: 4 * scale) {
                ForEach(Array("ASSASSIN".enumerated()), id: \.offset) { index, letter in
                    decorate(8 + index, LetterTile(letter: String(letter), size: tileSize, fill: .letterYellow, edge: .letterCoral))
                }
            }
        }
    }
}

extension AssassinTiles where Tile == LetterTile {
    init(tileSize: CGFloat) {
        self.init(tileSize: tileSize) { _, tile in tile }
    }
}

private extension View {
    /// Canva's "Roll": slides in from the left while turning a full circle, settling with a small bounce.
    /// The piece turns solid almost at once (a slow fade left half see-through tiles overlapping their
    /// neighbours, which looked smeared and blurry), then finishes its roll.
    func rollIn(_ isIn: Bool, delay: Double, distance: CGFloat = 70) -> some View {
        self
            .rotationEffect(.degrees(isIn ? 0 : -360))
            .offset(x: isIn ? 0 : -distance)
            .animation(.spring(response: 0.55, dampingFraction: 0.72).delay(delay), value: isIn)
            .opacity(isIn ? 1 : 0)
            .animation(.easeOut(duration: 0.08).delay(delay), value: isIn)
    }
}

private struct ScoringPill: View {
    let text: String
    let fill: Color

    var body: some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .foregroundStyle(Color.letterNavy)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(fill, in: .capsule)
    }
}

private struct HowToPlaySheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps = [
        "2 to 8 players. 5 rounds (or 3, or 1 for a quick game) of 90 seconds (or 60). The host runs the game.",
        "Players take turns shuffling the tiles for the round's letter, A to Z. Don't like it? Watch an ad to reshuffle.",
        "Swipe through 10 targets (categories like Country or Food) and fill each one with a word starting with that letter.",
        "Done? Hit Lock In. Once 3 players lock in, the clock drops to 5 seconds.",
        "Answers are revealed one target at a time, one player at a time. An answer nobody else had goes UNDETECTED for 10 points. Blank answers score 0 and spelling is up to you.",
        "Doubt an answer? Veto it and everyone votes. Tap the emoji to react as answers land.",
        "Tied for first at the end? Sudden Death: one target, 10 seconds, fastest right answer wins. Same answer knocks you both out. After 3 tries with no winner, you share the win.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to play")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.letterCream)
                    Text("One letter. Ten targets. No witnesses.")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.letterYellow)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(steps.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1).")
                                .fontWeight(.bold)
                                .foregroundStyle(Color.letterYellow)
                                .frame(width: 24, alignment: .leading)
                            Text(steps[index])
                                .foregroundStyle(Color.letterCream)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ScoringRule(points: "+10", detail: "Unseen: nobody else had it", fill: .letterYellow)
                    ScoringRule(points: "+5", detail: "Shared: exactly 2 players matched", fill: .letterMint)
                    ScoringRule(points: "0", detail: "3 or more players matched", fill: .letterCoral)
                }

                Button("Got it") {
                    dismiss()
                }
                .buttonStyle(FilledGameButtonStyle())
            }
            .padding(24)
        }
        .background(Color.letterNavy)
        .presentationDetents([.large])
    }
}

private struct ScoringRule: View {
    let points: String
    let detail: String
    let fill: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(points)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterNavy)
                .frame(width: 52, height: 36)
                .background(fill, in: .capsule)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.letterCream)
        }
    }
}

#Preview {
    HomeView(viewModel: .preview(.home))
        .environment(AudioManager())
}

#Preview("How to play") {
    HowToPlaySheet()
}
