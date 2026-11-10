//
//  GameBoardView.swift
//  LetterLock
//

import SwiftUI

struct GameBoardView: View {
    let viewModel: GameViewModel

    @FocusState private var focusedCategoryID: UUID?

    /// The header shrinks while the keyboard is up so more of the list stays visible.
    private var isTyping: Bool { focusedCategoryID != nil }

    var body: some View {
        VStack(spacing: 12) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(viewModel.categories) { category in
                            answerField(for: category)
                                .id(category.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedCategoryID) {
                    scrollToFocusedField(with: proxy)
                }
                // The keyboard and compact header resize the list after focus changes,
                // so re-center once the final height is known.
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { _ in
                    scrollToFocusedField(with: proxy)
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: isTyping)
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
            LetterTile(letter: viewModel.currentLetter, size: isTyping ? 44 : 84)
                .accessibilityLabel("Letter \(viewModel.currentLetter)")

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.timeRemaining)")
                    .font(.system(size: isTyping ? 36 : 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(viewModel.timeRemaining <= 10 ? Color.letterCoral : Color.letterCream)
                if !isTyping {
                    Text("SECONDS LEFT")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(Color.letterMuted)
                }
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
            .submitLabel(category == viewModel.categories.last ? .done : .next)
            .focused($focusedCategoryID, equals: category.id)
            .onSubmit { focusField(after: category) }
            .disabled(viewModel.isInputFrozen)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Color.letterSurface, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        focusedCategoryID == category.id ? Color.letterYellow : Color.letterBorder,
                        lineWidth: focusedCategoryID == category.id ? 2 : 1
                    )
            }
            // Make the whole box tappable, not just the line of text inside it.
            .contentShape(.rect(cornerRadius: 12))
            .onTapGesture {
                guard !viewModel.isInputFrozen else { return }
                focusedCategoryID = category.id
            }
        }
    }

    private func scrollToFocusedField(with proxy: ScrollViewProxy) {
        guard let focusedCategoryID else { return }
        withAnimation(.snappy(duration: 0.25)) {
            proxy.scrollTo(focusedCategoryID, anchor: .center)
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
