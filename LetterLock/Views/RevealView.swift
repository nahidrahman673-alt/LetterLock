//
//  RevealView.swift
//  LetterLock
//

import SwiftUI

/// Every category and every player's answer on one scrolling page.
struct RevealView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                LetterTile(letter: viewModel.currentLetter, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROUND \(viewModel.currentRound) OF \(viewModel.totalRounds)")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(Color.letterMuted)
                    Text("Answer reveal")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.letterCream)
                }
                Spacer()
            }
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    standings

                    Text("Tap Veto on an answer you doubt and everyone votes. Spelling is your call.")
                        .font(.footnote)
                        .foregroundStyle(Color.letterMuted)

                    ForEach(viewModel.categories) { category in
                        categorySection(category)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            HostActionButton(
                viewModel: viewModel,
                title: viewModel.isLastRound ? "See Final Results" : "Next Round",
                waitingText: "Waiting for the host",
                isEnabled: viewModel.activeVote == nil
            ) { hostId in
                viewModel.nextRound(by: hostId)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .sheet(item: voteBinding) { _ in
            VetoVoteSheet(viewModel: viewModel)
        }
    }

    private var voteBinding: Binding<VetoVote?> {
        Binding(
            get: { viewModel.activeVote },
            set: { if $0 == nil { viewModel.dismissVote() } }
        )
    }

    private var standings: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(viewModel.standings, id: \.player.id) { entry in
                    VStack(spacing: 2) {
                        Text(entry.player.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.letterMuted)
                        Text("\(entry.total)")
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(Color.letterCream)
                            .contentTransition(.numericText())
                        Text("+\(viewModel.roundPoints(for: entry.player.id))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.letterMint)
                    }
                    .frame(minWidth: 64)
                    .padding(.vertical, 8)
                    .background(Color.letterSurface, in: .rect(cornerRadius: 12))
                }
            }
        }
        .scrollIndicators(.hidden)
        .animation(.snappy, value: viewModel.roundAnswers)
    }

    private func categorySection(_ category: Category) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.name.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.letterYellow)

            VStack(spacing: 0) {
                let answers = viewModel.answers(for: category.id)
                ForEach(answers) { answer in
                    answerRow(answer)
                    if answer.id != answers.last?.id {
                        Divider().overlay(Color.letterBorder)
                    }
                }
            }
            .background(Color.letterSurface, in: .rect(cornerRadius: 12))
        }
    }

    private func answerRow(_ answer: RoundAnswer) -> some View {
        let name = viewModel.player(answer.playerId)?.name ?? ""
        let isRejected = answer.verdict == .rejected

        return HStack(spacing: 10) {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Color.letterMuted)
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)

            Text(answer.isBlank ? "No answer" : answer.text)
                .font(.body.weight(.semibold))
                .strikethrough(isRejected)
                .foregroundStyle(answer.isBlank || isRejected ? Color.letterMuted : Color.letterCream)
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
                .accessibilityLabel("Veto \(answer.text) by \(name)")
            } else if answer.wasVoted {
                Text(isRejected ? "Rejected" : "Upheld")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isRejected ? Color.letterCoral : Color.letterMint)
            }

            PointsPill(points: answer.points)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
    }
}

private struct PointsPill: View {
    let points: Int

    var body: some View {
        Text(points > 0 ? "+\(points)" : "0")
            .font(.system(.footnote, design: .rounded, weight: .heavy))
            .foregroundStyle(Color.letterNavy)
            .frame(width: 40, height: 26)
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

private struct VetoVoteSheet: View {
    let viewModel: GameViewModel

    var body: some View {
        if let vote = viewModel.activeVote, let answer = viewModel.answer(vote.answerId) {
            VStack(alignment: .leading, spacing: 18) {
                Text("VETO VOTE")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.letterCoral)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Does \u{201C}\(answer.text)\u{201D} count?")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.letterCream)
                    Text("\(viewModel.player(answer.playerId)?.name ?? "") · \(viewModel.categoryName(for: answer.categoryId)) · \(viewModel.currentLetter)")
                        .font(.subheadline)
                        .foregroundStyle(Color.letterMuted)
                }

                VStack(spacing: 6) {
                    ForEach(vote.voterIds, id: \.self) { voterId in
                        ballotRow(vote: vote, voterId: voterId)
                    }
                }

                Spacer(minLength: 0)

                if vote.isComplete {
                    Text(vote.verdict == .rejected
                         ? "Rejected \(vote.rejectCount)–\(vote.acceptCount). It scores 0."
                         : "Upheld \(vote.acceptCount)–\(vote.rejectCount). It keeps its points.")
                        .font(.headline)
                        .foregroundStyle(vote.verdict == .rejected ? Color.letterCoral : Color.letterMint)

                    Button("Done") {
                        viewModel.dismissVote()
                    }
                    .buttonStyle(FilledGameButtonStyle())
                } else if !viewModel.hasLocalVoted() {
                    HStack(spacing: 12) {
                        Button("Reject") { viewModel.castVote(accept: false) }
                            .buttonStyle(FilledGameButtonStyle(fill: .letterCoral))
                        Button("Accept") { viewModel.castVote(accept: true) }
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
                Label("Accept", systemImage: "checkmark.circle.fill").foregroundStyle(Color.letterMint)
            case .some(false):
                Label("Reject", systemImage: "xmark.circle.fill").foregroundStyle(Color.letterCoral)
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

#Preview {
    RevealView(viewModel: .preview(.reveal))
}
