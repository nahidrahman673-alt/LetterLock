//
//  LetterChoiceView.swift
//  LetterLock
//

import SwiftUI

struct LetterChoiceView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("ROUND \(viewModel.currentRound) OF \(viewModel.totalRounds)")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)
                .padding(.top, 8)

            Text(headline)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.letterCream)

            RainShuffle(
                letter: viewModel.currentLetter,
                isShuffling: viewModel.isShuffling,
                hasChosen: viewModel.hasChosenLetter
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Falling tiles pass over the buttons on their way off the bottom of the screen,
            // without blocking taps.
            .zIndex(1)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                viewModel.hasChosenLetter ? "Letter \(viewModel.currentLetter)" : "Letter not chosen yet"
            )

            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.letterMuted)
                .frame(minHeight: 20)

            if viewModel.isLocalChooser {
                if viewModel.hasChosenLetter {
                    Button {
                        viewModel.watchAdToReshuffle()
                    } label: {
                        Label("Watch Ad to Reshuffle", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(OutlinedGameButtonStyle())
                } else {
                    Button {
                        viewModel.shuffleLetter()
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(FilledGameButtonStyle())
                    .disabled(viewModel.isShuffling)
                    .opacity(viewModel.isShuffling ? 0.4 : 1)
                }
            }

            HostActionButton(
                viewModel: viewModel,
                title: "Start Round",
                waitingText: "Waiting for the host to start",
                isEnabled: viewModel.hasChosenLetter && !viewModel.isShuffling
            ) { hostId in
                viewModel.startRound(by: hostId)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .fullScreenCover(isPresented: $viewModel.isShowingAd) {
            MockAdView(viewModel: viewModel)
                .interactiveDismissDisabled()
        }
    }

    private var headline: String {
        if viewModel.isLocalChooser { return "Your turn to pick the letter" }
        return "\(viewModel.letterChooser?.name ?? "Someone") is picking the letter"
    }

    private var statusText: String {
        if viewModel.isShuffling { return "Shuffling…" }
        if viewModel.hasChosenLetter { return "Locked in on \(viewModel.currentLetter)" }
        return viewModel.isLocalChooser ? "Tap Shuffle to pick from A to Z" : ""
    }
}

/// Prototype stand-in for a rewarded video ad.
private struct MockAdView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Ad")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.letterMuted, in: .capsule)
                    .foregroundStyle(Color.letterNavy)
                Spacer()
                Button {
                    viewModel.closeAd()
                } label: {
                    Group {
                        if viewModel.adSecondsRemaining > 0 {
                            Text("\(viewModel.adSecondsRemaining)")
                                .monospacedDigit()
                        } else {
                            Image(systemName: "xmark")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(Color.letterCream)
                    .frame(width: 44, height: 44)
                    .background(Color.letterSurface, in: .circle)
                }
                .disabled(viewModel.adSecondsRemaining > 0)
                .accessibilityLabel(
                    viewModel.adSecondsRemaining > 0
                        ? "Ad ends in \(viewModel.adSecondsRemaining) seconds"
                        : "Close ad and reshuffle"
                )
            }

            Spacer()

            Image(systemName: "play.tv.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.letterMuted)
            Text("Placeholder ad")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterCream)
            Text("A real rewarded video plays here. Close it to reshuffle your letter.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.letterMuted)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    LetterChoiceView(viewModel: .preview(.choosingLetter))
}
