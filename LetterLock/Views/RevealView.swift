//
//  RevealView.swift
//  LetterLock
//

import SwiftUI

/// One category per page. Each player's answer appears in turn, then the category's points.
struct RevealView: View {
    let viewModel: GameViewModel

    @State private var isPickingMatch = false

    var body: some View {
        VStack(spacing: 14) {
            header

            Group {
                if viewModel.isShowingRoundScores {
                    roundScores
                        .transition(.push(from: .trailing))
                } else if let category = viewModel.revealCategory {
                    categoryPage(category)
                        .id(category.id)
                        .transition(.push(from: .trailing))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.snappy(duration: 0.35), value: viewModel.revealCategoryIndex)

            if !viewModel.isShowingRoundScores {
                if let category = viewModel.revealCategory, viewModel.isCategoryScored {
                    matchBar(for: category)
                }
                reactionBar
            }

            hostButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .overlay {
            FloatingReactions(reactions: viewModel.reactions)
                .allowsHitTesting(false)
        }
        .sheet(item: voteBinding) { _ in
            VetoVoteSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isPickingMatch) {
            if let category = viewModel.revealCategory {
                MatchPickerSheet(viewModel: viewModel, category: category)
            }
        }
    }

    // MARK: - Same answer?

    /// The app's suggestion (two answers that look or sound alike), or a way to pick two yourself.
    @ViewBuilder
    private func matchBar(for category: Category) -> some View {
        let suggestion = viewModel.suggestedMatches(in: category.id).first
        HStack(spacing: 10) {
            if let (first, second) = suggestion {
                Button {
                    viewModel.flagMatch(first.id, second.id)
                } label: {
                    Label("\u{201C}\(first.text)\u{201D} = \u{201C}\(second.text)\u{201D}?", systemImage: "equal.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.letterNavy)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Color.letterLilac, in: .capsule)
                }
                .accessibilityLabel("Vote on whether \(first.text) and \(second.text) are the same answer")
            }
            Spacer(minLength: 0)
            Button(suggestion == nil ? "Same answer?" : "Other") {
                isPickingMatch = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.letterLilac)
            .frame(minHeight: 44)
            .disabled(viewModel.activeVote != nil)
        }
        .transition(.opacity)
    }

    // MARK: - Header

    /// Compact so the answers get most of the screen.
    private var header: some View {
        HStack(spacing: 12) {
            LetterTile(letter: viewModel.currentLetter, size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.letterYellow)
                Text(viewModel.revealCategory?.name ?? "Round scores")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterCream)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(.snappy, value: viewModel.revealCategoryIndex)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private var subtitle: String {
        let round = "ROUND \(viewModel.currentRound)/\(viewModel.totalRounds)"
        guard !viewModel.isShowingRoundScores else { return round }
        return "\(round) · CATEGORY \(viewModel.revealCategoryIndex + 1)/\(viewModel.categories.count)"
    }

    // MARK: - Category page

    /// Rows stretch to fill the space down to the reactions, so answers read big.
    private func categoryPage(_ category: Category) -> some View {
        let answers = viewModel.answers(for: category.id)
        let spacing: CGFloat = 10

        return GeometryReader { geometry in
            let count = CGFloat(max(answers.count, 1))
            let fitted = (geometry.size.height - spacing * (count - 1)) / count
            let rowHeight = min(150, max(84, fitted))

            ScrollView {
                VStack(spacing: spacing) {
                    ForEach(Array(answers.enumerated()), id: \.element.id) { position, answer in
                        answerRow(answer, isNext: position == viewModel.revealedAnswerCount)
                            .frame(height: rowHeight)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.revealedAnswerCount)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.isCategoryScored)
        .animation(.snappy, value: viewModel.roundAnswers)
    }

    private func answerRow(_ answer: RoundAnswer, isNext: Bool) -> some View {
        let name = viewModel.player(answer.playerId)?.name ?? ""
        let isRevealed = viewModel.isRevealed(answer)
        // Wrong-letter answers look like vetoed ones: crossed out and greyed.
        let isRejected = answer.verdict == .rejected || answer.hasWrongLetter

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.letterMuted)
                    .lineLimit(1)

                Group {
                    if isRevealed {
                        Text(answer.isBlank ? "No answer" : answer.text)
                            .font(.system(size: answer.isBlank ? 24 : 34, weight: .heavy, design: .rounded))
                            .strikethrough(isRejected)
                            .foregroundStyle(answer.isBlank || isRejected ? Color.letterMuted : Color.letterCream)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        Text("• • •")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(isNext ? Color.letterYellow : Color.letterBorder)
                            .phaseAnimator([0.35, 1.0]) { content, phase in
                                content.opacity(isNext ? phase : 1)
                            } animation: { _ in .easeInOut(duration: 0.5) }
                            .accessibilityLabel("Hidden")
                    }
                }

                if isRevealed, answer.wasCutOff, !answer.hasWrongLetter {
                    Label("Cut off at 0:00", systemImage: "scissors")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.letterLilac)
                }
                if isRevealed, answer.mergedKey != nil, viewModel.isCategoryScored {
                    Label("Voted the same answer", systemImage: "equal.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.letterMint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isRevealed, viewModel.canVeto(answer) {
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
                .accessibilityLabel("Veto \(answer.text) by \(name)")
            } else if isRevealed, answer.hasWrongLetter {
                Text("Wrong letter")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.letterCoral)
            } else if answer.wasVoted {
                Text(isRejected ? "Rejected" : "Upheld")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isRejected ? Color.letterCoral : Color.letterMint)
            }

            if viewModel.isCategoryScored {
                PointsPill(points: answer.points)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
        .background(Color.letterSurface, in: .rect(cornerRadius: 16))
        .overlay {
            if isNext && !viewModel.isCategoryScored {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.letterYellow.opacity(0.5), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Round scores

    private var roundScores: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(viewModel.standings.enumerated()), id: \.element.player.id) { rank, entry in
                    HStack(spacing: 12) {
                        Text("\(rank + 1)")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(rank == 0 ? Color.letterYellow : Color.letterMuted)
                            .frame(width: 24)
                        Text(entry.player.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.letterCream)
                        Spacer()
                        Text("+\(viewModel.roundPoints(for: entry.player.id))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.letterMint)
                        Text("\(entry.total)")
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(Color.letterCream)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(Color.letterSurface, in: .rect(cornerRadius: 12))
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Reactions and controls

    private var reactionBar: some View {
        HStack(spacing: 6) {
            ForEach(GameViewModel.reactionEmoji, id: \.self) { emoji in
                Button {
                    viewModel.react(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 26))
                        .frame(width: 50, height: 46)
                        .contentShape(.rect)
                }
                .accessibilityLabel("React \(emoji)")
            }
        }
        .padding(.horizontal, 6)
        .background(Color.letterSurface, in: .capsule)
    }

    @ViewBuilder
    private var hostButton: some View {
        if viewModel.isShowingRoundScores {
            HostActionButton(
                viewModel: viewModel,
                title: viewModel.isLastRound ? "See Final Results" : "Next Round",
                waitingText: "Waiting for the host"
            ) { hostId in
                viewModel.nextRound(by: hostId)
            }
        } else if !viewModel.isCategoryScored {
            // While answers are still appearing, the host can skip to all of them at once.
            HostActionButton(
                viewModel: viewModel,
                title: "Skip",
                waitingText: "Waiting for the host",
                isEnabled: viewModel.activeVote == nil
            ) { hostId in
                viewModel.skipCategoryReveal(by: hostId)
            }
        } else {
            HostActionButton(
                viewModel: viewModel,
                title: viewModel.isLastRevealCategory ? "Show Round Scores" : "Next Category",
                waitingText: "Waiting for the host",
                isEnabled: viewModel.canMoveOnFromCategory && viewModel.activeVote == nil
            ) { hostId in
                viewModel.nextCategory(by: hostId)
            }
        }
    }

    private var voteBinding: Binding<VetoVote?> {
        Binding(
            get: { viewModel.activeVote },
            set: { if $0 == nil { viewModel.dismissVote() } }
        )
    }
}

// MARK: - Floating reactions

private struct FloatingReactions: View {
    let reactions: [Reaction]

    var body: some View {
        GeometryReader { geometry in
            ForEach(reactions) { reaction in
                FloatingReactionView(reaction: reaction)
                    .position(x: reaction.lane * geometry.size.width, y: geometry.size.height - 170)
            }
        }
    }
}

private struct FloatingReactionView: View {
    let reaction: Reaction

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRising = false
    @State private var isFading = false

    var body: some View {
        VStack(spacing: 0) {
            Text(reaction.emoji)
                .font(.system(size: 40))
            Text(reaction.playerName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.letterCream)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.letterSurface.opacity(0.8), in: .capsule)
        }
        .scaleEffect(isRising ? 1.1 : 0.5)
        .offset(y: isRising && !reduceMotion ? -280 : 0)
        .opacity(isFading ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 2.4)) { isRising = true }
            withAnimation(.easeIn(duration: 0.9).delay(1.4)) { isFading = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Points and voting

private struct PointsPill: View {
    let points: Int

    var body: some View {
        HStack(spacing: 2) {
            if points == GameViewModel.pointsOriginal {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.bold))
            }
            Text(points > 0 ? "+\(points)" : "0")
        }
        .font(.system(.headline, design: .rounded, weight: .heavy))
        .foregroundStyle(Color.letterNavy)
        .frame(minWidth: 52, minHeight: 34)
        .padding(.horizontal, 6)
        .background(fill, in: .capsule)
    }

    private var fill: Color {
        switch points {
        case GameViewModel.pointsOriginal: .letterYellow
        case GameViewModel.pointsShared: .letterMint
        default: .letterBorder
        }
    }
}

/// Shared by the reveal and Sudden Death.
struct VetoVoteSheet: View {
    let viewModel: GameViewModel

    var body: some View {
        if let vote = viewModel.activeVote, let answer = viewModel.answer(vote.answerId) {
            let other = vote.matchAnswerId.flatMap(viewModel.answer)
            VStack(alignment: .leading, spacing: 18) {
                Text(other == nil ? "VETO VOTE" : "SAME ANSWER?")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(other == nil ? Color.letterCoral : Color.letterLilac)

                VStack(alignment: .leading, spacing: 6) {
                    if let other {
                        Text("Are \u{201C}\(answer.text)\u{201D} and \u{201C}\(other.text)\u{201D} the same answer?")
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Color.letterCream)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(viewModel.player(answer.playerId)?.name ?? "") and \(viewModel.player(other.playerId)?.name ?? "") · \(viewModel.categoryName(for: answer.categoryId))")
                            .font(.subheadline)
                            .foregroundStyle(Color.letterMuted)
                        Text("If most say Same, they count as a match and the points change.")
                            .font(.footnote)
                            .foregroundStyle(Color.letterMuted)
                    } else {
                        Text("Does \u{201C}\(answer.text)\u{201D} count?")
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Color.letterCream)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(viewModel.player(answer.playerId)?.name ?? "") · \(viewModel.categoryName(for: answer.categoryId)) · \(viewModel.currentLetter)")
                            .font(.subheadline)
                            .foregroundStyle(Color.letterMuted)
                        if answer.wasCutOff {
                            Label("Cut off at 0:00", systemImage: "scissors")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Color.letterLilac)
                        }
                    }
                }

                VStack(spacing: 6) {
                    ForEach(vote.voterIds, id: \.self) { voterId in
                        ballotRow(vote: vote, voterId: voterId)
                    }
                }

                Spacer(minLength: 0)

                if vote.isComplete {
                    if vote.isMatchVote {
                        Text(vote.isSameAnswer
                             ? "Same \(vote.acceptCount)–\(vote.rejectCount). They now count as a match."
                             : "Different \(vote.rejectCount)–\(vote.acceptCount). They keep their points.")
                            .font(.headline)
                            .foregroundStyle(vote.isSameAnswer ? Color.letterMint : Color.letterLilac)
                    } else {
                        let isSuddenDeath = viewModel.gameState == .suddenDeath
                        Text(vote.verdict == .rejected
                             ? "Rejected \(vote.rejectCount)–\(vote.acceptCount). \(isSuddenDeath ? "It's out." : "It scores 0.")"
                             : "Upheld \(vote.acceptCount)–\(vote.rejectCount). \(isSuddenDeath ? "It stands." : "It keeps its points.")")
                            .font(.headline)
                            .foregroundStyle(vote.verdict == .rejected ? Color.letterCoral : Color.letterMint)
                    }

                    Button("Done") {
                        viewModel.dismissVote()
                    }
                    .buttonStyle(FilledGameButtonStyle())
                } else if !viewModel.hasLocalVoted() {
                    HStack(spacing: 12) {
                        Button(vote.isMatchVote ? "Different" : "Reject") { viewModel.castVote(accept: false) }
                            .buttonStyle(FilledGameButtonStyle(fill: .letterCoral))
                        Button(vote.isMatchVote ? "Same" : "Accept") { viewModel.castVote(accept: true) }
                            .buttonStyle(FilledGameButtonStyle(fill: .letterMint))
                    }
                } else {
                    Text("Waiting for everyone to vote…")
                        .font(.headline)
                        .foregroundStyle(Color.letterMuted)
                        .frame(maxWidth: .infinity, minHeight: 58)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.letterNavy)
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(!vote.isComplete)
            .animation(.snappy, value: vote)
        }
    }

    private func ballotRow(vote: VetoVote, voterId: UUID) -> some View {
        let ballot = vote.ballots[voterId]
        return HStack {
            Text(viewModel.player(voterId)?.name ?? "")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.letterCream)
            Spacer()
            switch ballot {
            case .some(true):
                Label(vote.isMatchVote ? "Same" : "Accept", systemImage: "checkmark.circle.fill").foregroundStyle(Color.letterMint)
            case .some(false):
                Label(vote.isMatchVote ? "Different" : "Reject", systemImage: "xmark.circle.fill").foregroundStyle(Color.letterCoral)
            case .none:
                Text("Voting…").foregroundStyle(Color.letterMuted)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.letterSurface, in: .rect(cornerRadius: 10))
    }
}

/// Pick any two answers in this category to ask everyone whether they're the same answer
/// (for pairs the app didn't spot, like "NYC" and "New York").
private struct MatchPickerSheet: View {
    let viewModel: GameViewModel
    let category: Category

    @Environment(\.dismiss) private var dismiss
    @State private var picked: [UUID] = []

    private var candidates: [RoundAnswer] { viewModel.answers(for: category.id).filter(\.canScore) }

    private var canStart: Bool {
        guard picked.count == 2, let first = viewModel.answer(picked[0]), let second = viewModel.answer(picked[1]) else { return false }
        return viewModel.canFlagMatch(first, second)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SAME ANSWER?")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.letterLilac)
            Text("Pick the two answers that mean the same thing.")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterCream)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(candidates) { answer in
                        let isPicked = picked.contains(answer.id)
                        Button {
                            if isPicked {
                                picked.removeAll { $0 == answer.id }
                            } else {
                                picked = Array((picked + [answer.id]).suffix(2))
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.player(answer.playerId)?.name.uppercased() ?? "")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.letterMuted)
                                    Text(answer.text)
                                        .font(.system(.title3, design: .rounded, weight: .heavy))
                                        .foregroundStyle(Color.letterCream)
                                }
                                Spacer()
                                Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isPicked ? Color.letterLilac : Color.letterBorder)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 56)
                            .background(Color.letterSurface, in: .rect(cornerRadius: 12))
                        }
                        .accessibilityAddTraits(isPicked ? .isSelected : [])
                    }
                }
            }

            if picked.count == 2, !canStart {
                Text("Those two already count as the same, or were voted on already.")
                    .font(.footnote)
                    .foregroundStyle(Color.letterMuted)
            }

            Button("Ask everyone") {
                let pair = picked
                dismiss()
                viewModel.flagMatch(pair[0], pair[1])
            }
            .buttonStyle(FilledGameButtonStyle(fill: .letterLilac))
            .disabled(!canStart)
            .opacity(canStart ? 1 : 0.4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .presentationDetents([.large])
    }
}

#Preview {
    RevealView(viewModel: .preview(.reveal))
}
