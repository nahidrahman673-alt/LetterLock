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

            Group {
                switch viewModel.shuffleStyle {
                case .rain:
                    RainShuffle(
                        letter: viewModel.currentLetter,
                        isShuffling: viewModel.isShuffling,
                        hasChosen: viewModel.hasChosenLetter
                    )
                case .pile:
                    DominoShuffle(
                        letter: viewModel.currentLetter,
                        isShuffling: viewModel.isShuffling,
                        hasChosen: viewModel.hasChosenLetter
                    )
                }
            }
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

/// A tight pile of tiles that rub and jostle against each other, like dominoes being mixed
/// on a table. When the letter is chosen, the winning tile pops out of the pile and the rest scatter.
private struct DominoShuffle: View {
    let letter: String
    let isShuffling: Bool
    let hasChosen: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tileCount = 7
    private static let tileSize: CGFloat = 112
    /// How far tiles can drift from the centre of the pile. Smaller than a tile, so they always overlap.
    private static let pileRadius = CGSize(width: 100, height: 84)
    private static let edges: [Color] = [.letterYellow, .letterMint, .letterCoral, .letterLilac, .letterMint, .letterYellow, .letterCoral]
    /// A neat pile for before the first shuffle.
    private static let restingOffsets: [CGSize] = [
        .zero, CGSize(width: -78, height: -40), CGSize(width: 78, height: -32), CGSize(width: -70, height: 48),
        CGSize(width: 70, height: 52), CGSize(width: 4, height: -70), CGSize(width: -4, height: 70),
    ]
    private static let restingTilts: [Double] = [0, -12, 10, 8, -9, 4, -5]

    @State private var offsets = DominoShuffle.restingOffsets
    @State private var tilts = DominoShuffle.restingTilts
    @State private var layers = (0..<DominoShuffle.tileCount).map(Double.init)
    @State private var letters = Array(repeating: "?", count: DominoShuffle.tileCount)

    var body: some View {
        ZStack {
            ForEach(0..<Self.tileCount, id: \.self) { index in
                let isWinner = index == 0
                let isPoppedOut = hasChosen && isWinner
                let isScattered = hasChosen && !isWinner

                LetterTile(
                    letter: isPoppedOut ? letter : letters[index],
                    size: isPoppedOut ? 220 : Self.tileSize,
                    edge: isPoppedOut ? .letterYellow : Self.edges[index],
                    tilt: isPoppedOut ? 0 : tilts[index]
                )
                .offset(
                    isPoppedOut
                        ? .zero
                        : isScattered ? CGSize(width: offsets[index].width * 3, height: offsets[index].height * 3 + 40) : offsets[index]
                )
                .scaleEffect(isScattered ? 0.6 : 1)
                .opacity(isScattered ? 0 : 1)
                .zIndex(isPoppedOut ? 100 : layers[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.42, dampingFraction: 0.48), value: hasChosen)
        .onChange(of: letter) {
            if letter == "?" {
                reset()
            } else if isShuffling {
                flick()
            }
        }
        .task(id: isShuffling) {
            // Keep the pile rubbing between letter changes so it never sits still while shuffling.
            guard isShuffling, !reduceMotion else { return }
            while !Task.isCancelled {
                jostle()
                try? await Task.sleep(for: .milliseconds(85))
            }
        }
    }

    /// A letter change: the tiles show new faces and the pile shifts.
    private func flick() {
        letters = (0..<Self.tileCount).map { index in
            index == 0 ? letter : (GameViewModel.letterPool.randomElement() ?? "A")
        }
        if !reduceMotion { jostle() }
    }

    /// Nudges every tile to a new spot and angle inside the pile, and reorders which sits on top.
    private func jostle() {
        withAnimation(.spring(response: 0.14, dampingFraction: 0.55)) {
            offsets = (0..<Self.tileCount).map { _ in
                CGSize(
                    width: Double.random(in: -Self.pileRadius.width...Self.pileRadius.width),
                    height: Double.random(in: -Self.pileRadius.height...Self.pileRadius.height)
                )
            }
            tilts = (0..<Self.tileCount).map { _ in Double.random(in: -28...28) }
            layers = layers.shuffled()
        }
    }

    private func reset() {
        offsets = Self.restingOffsets
        tilts = Self.restingTilts
        layers = (0..<Self.tileCount).map(Double.init)
        letters = Array(repeating: "?", count: Self.tileCount)
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

#Preview("Pile on repeat") {
    let viewModel = GameViewModel()
    viewModel.shuffleStyle = .pile
    viewModel.runShuffleDemo()
    return LetterChoiceView(viewModel: viewModel)
}
