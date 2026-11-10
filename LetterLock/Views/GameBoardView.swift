//
//  GameBoardView.swift
//  LetterLock
//

import SwiftUI

struct GameBoardView: View {
    let viewModel: GameViewModel

    @FocusState private var focusedCategoryID: UUID?

    var body: some View {
        VStack(spacing: 16) {
            header

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.categories) { category in
                        answerField(for: category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .safeAreaInset(edge: .bottom) {
            Button("STOP THE BUS!") {
                viewModel.stopTheBus()
            }
            .buttonStyle(FilledGameButtonStyle(fill: .letterCoral))
            .disabled(viewModel.isInputFrozen)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.letterNavy)
        }
    }

    private var header: some View {
        HStack {
            LetterTile(letter: viewModel.currentLetter, size: 84)
                .accessibilityLabel("Letter \(viewModel.currentLetter)")

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.timeRemaining)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(viewModel.timeRemaining <= 10 ? Color.letterCoral : Color.letterCream)
                Text("SECONDS LEFT")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(Color.letterMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.timeRemaining) seconds left")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func answerField(for category: Category) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.letterMuted)

            TextField(
                category.name,
                text: answerBinding(for: category),
                prompt: Text("Starts with \(viewModel.currentLetter)").foregroundStyle(Color.letterMuted)
            )
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.letterCream)
            .tint(Color.letterYellow)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .focused($focusedCategoryID, equals: category.id)
            .onSubmit { focusField(after: category) }
            .disabled(viewModel.isInputFrozen)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.letterSurface, in: .rect(cornerRadius: 12))
        }
    }

    private func answerBinding(for category: Category) -> Binding<String> {
        Binding(
            get: { viewModel.answers[category.id] ?? "" },
            set: { viewModel.answers[category.id] = $0 }
        )
    }

    private func focusField(after category: Category) {
        guard let index = viewModel.categories.firstIndex(of: category),
              viewModel.categories.indices.contains(index + 1) else {
            focusedCategoryID = nil
            return
        }
        focusedCategoryID = viewModel.categories[index + 1].id
    }
}

#Preview {
    GameBoardView(viewModel: .preview(.playing))
}
