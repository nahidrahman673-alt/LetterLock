//
//  FinalResultsView.swift
//  LetterLock
//

import SwiftUI

struct FinalResultsView: View {
    let viewModel: GameViewModel

    var body: some View {
        let standings = viewModel.standings

        VStack(spacing: 18) {
            Text("FINAL RESULTS")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)
                .padding(.top, 8)

            let winners = viewModel.champions
            if !winners.isEmpty {
                Image(systemName: winners.count > 1 ? "medal.fill" : "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.letterYellow)
                Text(headline(for: winners))
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterCream)
                if winners.count > 1 {
                    Text("\(winners.map { $0.isLocal ? "You" : $0.name }.formatted(.list(type: .and))) share first place")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.letterMuted)
                } else if let winnerId = viewModel.suddenDeathWinnerId {
                    Text("Won Sudden Death in \(GameViewModel.formatSeconds(viewModel.suddenDeathSeconds(for: winnerId)))")
                        .font(.headline)
                        .foregroundStyle(Color.letterCoral)
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(standings, id: \.player.id) { entry in
                        // Equal totals share a place (1, 1, 3), unless Sudden Death split them.
                        let place = viewModel.finalPlace(for: entry.player.id, total: entry.total)
                        HStack(spacing: 12) {
                            Text("\(place)")
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(place == 1 ? Color.letterYellow : Color.letterMuted)
                                .frame(width: 24)
                            Text(entry.player.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.letterCream)
                            if entry.player.isHost { HostBadge() }
                            Spacer()
                            Text("\(entry.total)")
                                .font(.system(.title3, design: .rounded, weight: .heavy))
                                .foregroundStyle(Color.letterCream)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(Color.letterSurface, in: .rect(cornerRadius: 12))
                    }
                }
            }

            HostActionButton(
                viewModel: viewModel,
                title: "Play Again",
                waitingText: "Waiting for the host"
            ) { hostId in
                viewModel.playAgain(by: hostId)
            }

            Button("Home") {
                viewModel.resetToHome()
            }
            .buttonStyle(OutlinedGameButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
    }

    /// Ties go to Sudden Death; after 3 tries with no winner, the tied players share the win.
    private func headline(for winners: [Player]) -> String {
        guard winners.count == 1, let winner = winners.first else { return "Shared win!" }
        return winner.isLocal ? "You win!" : "\(winner.name) wins!"
    }
}

#Preview {
    FinalResultsView(viewModel: .preview(.finalResults))
}

#if DEBUG
#Preview("Tie goes to Sudden Death") {
    let viewModel = GameViewModel()
    viewModel.showFinalResultsDemo(draw: true)
    return SuddenDeathView(viewModel: viewModel)
}
#endif
