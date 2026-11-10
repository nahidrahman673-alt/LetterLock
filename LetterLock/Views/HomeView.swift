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

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 16)

            LogoView()

            Text("One letter. Every category.\nDon't think alike.")
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
                viewModel.startNewGame()
            }
            .buttonStyle(FilledGameButtonStyle())

            Button("Join with a code") {
                joinCode = ""
                isShowingJoinPrompt = true
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

private struct LogoView: View {
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

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(topRow.indices, id: \.self) { index in
                    LetterTile(
                        letter: topRow[index].letter,
                        edge: topRow[index].edge,
                        tilt: topRow[index].tilt
                    )
                }
            }

            HStack(spacing: 6) {
                ForEach(bottomRow.indices, id: \.self) { index in
                    LetterTile(
                        letter: bottomRow[index].letter,
                        fill: .letterYellow,
                        edge: .letterCream,
                        tilt: bottomRow[index].tilt
                    )
                }

                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.letterYellow)
                    .frame(width: 46, height: 53)
                    .background(Color.letterSurface, in: .rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.letterYellow, lineWidth: 2)
                    }
                    .rotationEffect(.degrees(6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Letter Lock")
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
        "A random letter is chosen for the round.",
        "Fill in every category with a word starting with that letter before the timer runs out.",
        "Finished first? Hit STOP THE BUS! to freeze everyone's answers.",
        "Answers are revealed and scored. The rarer yours is, the more it earns.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to play")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.letterCream)
                    Text("Think alike. Don't.")
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
