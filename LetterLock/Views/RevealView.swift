//
//  RevealView.swift
//  LetterLock
//

import SwiftUI

struct RevealView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                LetterTile(letter: viewModel.currentLetter, size: 56)

                Text("Round over")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterCream)

                Spacer()
            }
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.roundAnswers) { answer in
                        answerRow(answer)
                    }
                }
            }

            Button("Next Round") {
                viewModel.startRound()
            }
            .buttonStyle(FilledGameButtonStyle())

            Button("Home") {
                viewModel.resetToHome()
            }
            .buttonStyle(OutlinedGameButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
    }

    private func answerRow(_ answer: RoundAnswer) -> some View {
        HStack {
            Text(viewModel.categoryName(for: answer.categoryId))
                .font(.subheadline)
                .foregroundStyle(Color.letterMuted)

            Spacer()

            Text(answer.text.isEmpty ? "No answer" : answer.text)
                .font(.body.weight(.semibold))
                .foregroundStyle(answer.text.isEmpty ? Color.letterMuted : Color.letterCream)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.letterSurface, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    RevealView(viewModel: .preview(.reveal))
}
