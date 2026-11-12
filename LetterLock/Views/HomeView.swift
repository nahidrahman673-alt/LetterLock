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

            // "Lock it in." in yellow to match the LOCK tiles in the title.
            Text("One letter. Ten categories.\n\(Text("Lock it in.").foregroundStyle(Color.letterYellow))")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.letterCream)
                .padding(.top, 18)

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
        ScoringPill(text: "+10 original", fill: .letterYellow)
        ScoringPill(text: "+5 shared", fill: .letterMint)
        ScoringPill(text: "0 if 3 match", fill: .letterCoral)
    }
}

/// The LetterLock tile logo. Full size on Home; the title bar uses a small copy so the
/// identity is the same everywhere.
struct LogoView: View {
    /// 46 on Home. Everything else scales from this.
    var tileSize: CGFloat = 46

    private let topRow: [(letter: String, edge: Color, tilt: Double)] = [
        ("L", .letterYellow, -6),
        ("E", .letterMint, 3),
        ("T", .letterCoral, -2),
        ("T", .letterYellow, 5),
        ("E", .letterLilac, -4),
        ("R", .letterMint, 2),
    ]
    private let bottomRow: [(letter: String, tilt: Double)] = [
        ("L", 4),
        ("O", -3),
        ("C", 2),
        ("K", -5),
    ]

    private var scale: CGFloat { tileSize / 46 }

    var body: some View {
        VStack(spacing: 14 * scale) {
            HStack(spacing: 6 * scale) {
                ForEach(topRow.indices, id: \.self) { index in
                    LetterTile(
                        letter: topRow[index].letter,
                        size: tileSize,
                        edge: topRow[index].edge,
                        tilt: topRow[index].tilt
                    )
                }
            }

            HStack(spacing: 6 * scale) {
                ForEach(bottomRow.indices, id: \.self) { index in
                    LetterTile(
                        letter: bottomRow[index].letter,
                        size: tileSize,
                        fill: .letterYellow,
                        edge: .letterCream,
                        tilt: bottomRow[index].tilt
                    )
                }

                Image(systemName: "lock.fill")
                    .font(.system(size: 22 * scale, weight: .bold))
                    .foregroundStyle(Color.letterYellow)
                    .frame(width: tileSize, height: tileSize * 1.16)
                    .background(Color.letterSurface, in: .rect(cornerRadius: 10 * scale))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10 * scale)
                            .strokeBorder(Color.letterYellow, lineWidth: max(1, 2 * scale))
                    }
                    .rotationEffect(.degrees(6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LetterLock")
        .accessibilityAddTraits(.isHeader)
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
        "Swipe through 10 categories and fill each one with a word starting with that letter.",
        "Done? Hit Lock In. Once 3 players lock in, the clock drops to 5 seconds.",
        "Answers are revealed one category at a time, one player at a time. Blank answers score 0 and spelling is up to you.",
        "Doubt an answer? Veto it and everyone votes. Tap the emoji to react as answers land.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to play")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.letterCream)
                    Text("One letter. Ten categories.")
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
                    ScoringRule(points: "+10", detail: "Original: nobody else had it", fill: .letterYellow)
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
}

#Preview("How to play") {
    HowToPlaySheet()
}
