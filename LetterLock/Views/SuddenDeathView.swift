//
//  SuddenDeathView.swift
//  LetterLock
//

import SwiftUI

/// The tie-break after the last round. The tied players race to answer one category in 10 seconds;
/// the fastest right answer wins. Everyone else watches and can Veto.
struct SuddenDeathView: View {
    let viewModel: GameViewModel

    @State private var isFieldFocused = false

    var body: some View {
        VStack(spacing: 16) {
            header

            switch viewModel.suddenDeathPhase {
            case .intro: intro
            case .answering: answering
            case .result: result
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.letterNavy)
        .animation(.snappy, value: viewModel.suddenDeathPhase)
        .onChange(of: viewModel.suddenDeathPhase) {
            isFieldFocused = viewModel.suddenDeathPhase == .answering && viewModel.isLocalInSuddenDeath
        }
        .onChange(of: viewModel.isLocalSuddenDeathLockedIn) {
            if viewModel.isLocalSuddenDeathLockedIn { isFieldFocused = false }
        }
        .sheet(item: voteBinding) { _ in
            VetoVoteSheet(viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("SUDDEN DEATH")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundStyle(Color.letterCoral)
            Text("Try \(viewModel.suddenDeathTry) of \(GameViewModel.suddenDeathTries)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.letterMuted)
        }
        .padding(.top, 6)
    }

    private var playerNames: String {
        viewModel.suddenDeathPlayers.map { $0.isLocal ? "You" : $0.name }.joined(separator: " vs ")
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Color.letterCoral)
                .symbolEffect(.pulse)
            Text(viewModel.suddenDeathTry == 1 ? "It's a tie!" : "Still tied!")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterCream)
            Text(playerNames)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterYellow)
                .multilineTextAlignment(.center)
            Text("One category. \(GameViewModel.suddenDeathSeconds) seconds.\nFastest right answer wins.\nSame answer? You're both out.")
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.letterMuted)
            if !viewModel.isLocalInSuddenDeath {
                Text("You're a judge. Get ready to Veto.")
                    .font(.headline)
                    .foregroundStyle(Color.letterMint)
            }
            Spacer()
        }
    }

    // MARK: - Answering

    private var answering: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                LetterTile(letter: viewModel.currentLetter, size: 56)
                    .accessibilityLabel("Letter \(viewModel.currentLetter)")
                Text(viewModel.suddenDeathCategory?.name ?? "")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterCream)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .padding(.leading, 6)
                Spacer()
                Text("\(viewModel.timeRemaining)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: viewModel.timeRemaining)
                    .foregroundStyle(Color.letterCoral)
                    .accessibilityLabel("\(viewModel.timeRemaining) seconds left")
            }

            racers

            if viewModel.isLocalInSuddenDeath {
                answerBox
            } else {
                Text("You're a judge. Answers show when time's up.")
                    .font(.headline)
                    .foregroundStyle(Color.letterMint)
                    .padding(.top, 20)
            }
            Spacer()
        }
    }

    /// One chip per tied player that turns coral when they lock in.
    private var racers: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.suddenDeathPlayers) { player in
                let isLocked = viewModel.lockedInPlayerIds.contains(player.id)
                Label(player.isLocal ? "You" : player.name, systemImage: isLocked ? "lock.fill" : "lock.open")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isLocked ? Color.letterNavy : Color.letterCream)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(isLocked ? Color.letterCoral : Color.letterSurface, in: .capsule)
            }
        }
        .animation(.snappy, value: viewModel.lockedInPlayerIds)
    }

    @ViewBuilder
    private var answerBox: some View {
        let isLocked = viewModel.isLocalSuddenDeathLockedIn
        GameTextField(
            text: Bindable(viewModel).suddenDeathAnswer,
            isFocused: $isFieldFocused,
            placeholder: "Starts with \(viewModel.currentLetter)",
            returnKey: .go,
            isEnabled: !isLocked,
            onSubmit: { viewModel.lockInSuddenDeath() }
        )
        .accessibilityLabel(viewModel.suddenDeathCategory?.name ?? "Answer")
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .background(Color.letterSurface, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isFieldFocused ? Color.letterYellow : Color.letterBorder, lineWidth: isFieldFocused ? 2 : 1)
        }

        if hasWrongLetter && !isLocked {
            Label("Must start with \(viewModel.currentLetter)", systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.letterCoral)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let localId = viewModel.localPlayer?.id, isLocked {
            Label("Locked in at \(GameViewModel.formatSeconds(viewModel.suddenDeathSeconds(for: localId)))", systemImage: "lock.fill")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterMint)
                .frame(maxWidth: .infinity, minHeight: 58)
        } else {
            // No confirm step: it's a race. The Go key on the keyboard also locks in.
            Button {
                viewModel.lockInSuddenDeath()
            } label: {
                Label("Lock In", systemImage: "lock.fill")
            }
            .buttonStyle(FilledGameButtonStyle(fill: .letterCoral))
        }
    }

    private var hasWrongLetter: Bool {
        let text = viewModel.suddenDeathAnswer.trimmingCharacters(in: .whitespaces)
        let waitingForMore = ["the", "a", "an"].contains(text.lowercased())
        return !text.isEmpty && !waitingForMore && !LetterRule.fits(text, letter: viewModel.currentLetter)
    }

    // MARK: - Result

    private var result: some View {
        VStack(spacing: 14) {
            resultHeadline
                .padding(.top, 4)

            Text("\(viewModel.suddenDeathCategory?.name ?? "") · \(viewModel.currentLetter)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.letterMuted)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.suddenDeathResults) { answer in
                        resultRow(answer)
                    }
                }
            }

            HostActionButton(
                viewModel: viewModel,
                title: hostButtonTitle,
                waitingText: "Waiting for the host",
                isEnabled: viewModel.canMoveOnFromSuddenDeath && viewModel.activeVote == nil
            ) { hostId in
                viewModel.finishSuddenDeathTry(by: hostId)
            }
        }
        .animation(.snappy, value: viewModel.suddenDeathAnswers)
    }

    @ViewBuilder
    private var resultHeadline: some View {
        if let winnerId = viewModel.suddenDeathLeaderId, let winner = viewModel.player(winnerId) {
            VStack(spacing: 2) {
                Text(winner.isLocal ? "You win!" : "\(winner.name) wins!")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterCream)
                Text(GameViewModel.formatSeconds(viewModel.suddenDeathSeconds(for: winnerId)))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.letterYellow)
            }
        } else {
            VStack(spacing: 4) {
                Text(viewModel.isLastSuddenDeathTry ? "Still tied!" : "No winner!")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterCream)
                Text(viewModel.isLastSuddenDeathTry ? "That was the last try, so you share the win." : "Nobody had a right answer of their own. Go again!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.letterMuted)
            }
        }
    }

    private var hostButtonTitle: String {
        if viewModel.suddenDeathLeaderId != nil || viewModel.isLastSuddenDeathTry { return "See Final Results" }
        return "Next Try"
    }

    private func resultRow(_ answer: RoundAnswer) -> some View {
        let player = viewModel.player(answer.playerId)
        let outcome = viewModel.suddenDeathOutcome(for: answer)
        let isOut = outcome != .winner && outcome != .slower
        let seconds = GameViewModel.formatSeconds(viewModel.suddenDeathSeconds(for: answer.playerId))

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text((player?.isLocal == true ? "You" : player?.name ?? "").uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.letterMuted)
                Text(answer.isBlank ? "No answer" : answer.text)
                    .font(.system(size: answer.isBlank ? 22 : 28, weight: .heavy, design: .rounded))
                    .strikethrough(isOut && !answer.isBlank)
                    .foregroundStyle(isOut ? Color.letterMuted : Color.letterCream)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(label(for: outcome))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(outcome == .winner ? Color.letterYellow : isOut ? Color.letterCoral : Color.letterMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.canVeto(answer) {
                Button("Veto") {
                    viewModel.veto(answer.id)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.letterCoral)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .overlay { Capsule().strokeBorder(Color.letterCoral, lineWidth: 1.5) }
                .frame(minHeight: 44)
                .contentShape(.rect)
                .accessibilityLabel("Veto \(answer.text)")
            }

            Text(seconds)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .strikethrough(isOut)
                .foregroundStyle(outcome == .winner ? Color.letterNavy : isOut ? Color.letterMuted : Color.letterCream)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(outcome == .winner ? Color.letterYellow : Color.letterBorder.opacity(0.4), in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.letterSurface, in: .rect(cornerRadius: 16))
        .overlay {
            if outcome == .winner {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.letterYellow, lineWidth: 2)
            }
        }
    }

    private func label(for outcome: SuddenDeathOutcome) -> String {
        switch outcome {
        case .winner: "Fastest right answer"
        case .slower: "Too slow"
        case .blank: "Out: no answer"
        case .wrongLetter: "Out: wrong letter"
        case .sameAnswer: "Out: same answer"
        case .rejected: "Out: vetoed"
        }
    }

    private var voteBinding: Binding<VetoVote?> {
        Binding(
            get: { viewModel.activeVote },
            set: { if $0 == nil { viewModel.dismissVote() } }
        )
    }
}

#if DEBUG
#Preview {
    let viewModel = GameViewModel()
    viewModel.showFinalResultsDemo(draw: true)
    return SuddenDeathView(viewModel: viewModel)
}
#endif
