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
                .padding(.top, 24)

            if let winner = standings.first {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.letterYellow)
                Text(winner.player.isLocal ? "You win!" : "\(winner.player.name) wins!")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterCream)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(standings.enumerated()), id: \.element.player.id) { rank, entry in
                        HStack(spacing: 12) {
                            Text("\(rank + 1)")
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(rank == 0 ? Color.letterYellow : Color.letterMuted)
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
}

#Preview {
    FinalResultsView(viewModel: .preview(.finalResults))
}
