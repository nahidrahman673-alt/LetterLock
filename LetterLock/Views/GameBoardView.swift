//
//  GameBoardView.swift
//  LetterLock
//

import SwiftUI

struct GameBoardView: View {
    let viewModel: GameViewModel

    @State private var page = 0
    @FocusState private var focusedCategoryID: UUID?

    private var categories: [Category] { viewModel.categories }

    var body: some View {
        VStack(spacing: 14) {
            header
            lockInStatus
            pageDots

            TabView(selection: $page) {
                ForEach(categories.indices, id: \.self) { index in
                    categoryPage(categories[index], index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: page) {
                // Keep the keyboard up when paging so typing can carry on.
                if focusedCategoryID != nil, categories.indices.contains(page) {
                    focusedCategoryID = categories[page].id
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .safeAreaInset(edge: .bottom) {
            lockInButton
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.letterNavy)
        }
        .onChange(of: viewModel.isLocalLockedIn) {
            if viewModel.isLocalLockedIn { focusedCategoryID = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            LetterTile(letter: viewModel.currentLetter, size: 56)
                .accessibilityLabel("Letter \(viewModel.currentLetter)")

            Text("ROUND \(viewModel.currentRound)/\(viewModel.totalRounds)")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)
                .padding(.leading, 6)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(viewModel.timeRemaining)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: viewModel.timeRemaining)
                    .foregroundStyle(viewModel.timeRemaining <= 10 ? Color.letterCoral : Color.letterCream)
                Text("SECONDS")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(Color.letterMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.timeRemaining) seconds left")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var lockInStatus: some View {
        let locked = viewModel.lockedInPlayerIds.count
        let text = viewModel.wasTimerCut
            ? "\(locked) players locked in. \(GameViewModel.lockInCutSeconds) seconds left!"
            : "\(locked) of \(viewModel.players.count) locked in · \(GameViewModel.lockInsToCutTimer) cuts the clock to \(GameViewModel.lockInCutSeconds)s"
        return HStack(spacing: 6) {
            Image(systemName: "lock.fill")
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(viewModel.wasTimerCut ? Color.letterNavy : Color.letterMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(viewModel.wasTimerCut ? Color.letterCoral : Color.letterSurface, in: .capsule)
        .animation(.snappy, value: viewModel.wasTimerCut)
    }

    /// One dot per category. Filled once answered; tap to jump to it.
    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(categories.indices, id: \.self) { index in
                let isAnswered = !(viewModel.answers[categories[index].id] ?? "")
                    .trimmingCharacters(in: .whitespaces).isEmpty
                Capsule()
                    .fill(isAnswered ? Color.letterMint : Color.letterBorder)
                    .frame(width: index == page ? 22 : 10, height: 10)
                    .overlay {
                        if index == page {
                            Capsule().strokeBorder(Color.letterYellow, lineWidth: 2)
                        }
                    }
                    .frame(height: 44)
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy) { page = index }
                    }
                    .accessibilityLabel("\(categories[index].name), \(isAnswered ? "answered" : "empty")")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .animation(.snappy, value: page)
    }

    // MARK: - Pages

    private func categoryPage(_ category: Category, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(index + 1) OF \(categories.count)")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)

            Text(category.name)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterCream)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            TextField(
                category.name,
                text: answerBinding(for: category),
                prompt: Text("Starts with \(viewModel.currentLetter)").foregroundStyle(Color.letterMuted)
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.letterCream)
            .tint(Color.letterYellow)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(index == categories.count - 1 ? .done : .next)
            .focused($focusedCategoryID, equals: category.id)
            .onSubmit { goToPage(index + 1, keepTyping: true) }
            .disabled(viewModel.isInputFrozen)
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .background(Color.letterSurface, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        focusedCategoryID == category.id ? Color.letterYellow : Color.letterBorder,
                        lineWidth: focusedCategoryID == category.id ? 2 : 1
                    )
            }
            .contentShape(.rect(cornerRadius: 14))
            .onTapGesture {
                guard !viewModel.isInputFrozen else { return }
                focusedCategoryID = category.id
            }

            HStack {
                Button {
                    goToPage(index - 1, keepTyping: focusedCategoryID != nil)
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(minHeight: 44)
                }
                .opacity(index == 0 ? 0 : 1)
                .disabled(index == 0)

                Spacer()

                Button {
                    goToPage(index + 1, keepTyping: focusedCategoryID != nil)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(minHeight: 44)
                }
                .opacity(index == categories.count - 1 ? 0 : 1)
                .disabled(index == categories.count - 1)
            }
            .font(.headline)
            .foregroundStyle(Color.letterYellow)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Lock in

    @ViewBuilder
    private var lockInButton: some View {
        if viewModel.isLocalLockedIn {
            Label("Locked in. Waiting for the clock", systemImage: "lock.fill")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.letterMint)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Color.letterSurface, in: .rect(cornerRadius: 16))
        } else {
            Button {
                viewModel.lockIn()
            } label: {
                Label("Lock In", systemImage: "lock.open.fill")
            }
            .buttonStyle(FilledGameButtonStyle(fill: .letterCoral))
        }
    }

    // MARK: - Helpers

    private func goToPage(_ target: Int, keepTyping: Bool) {
        guard categories.indices.contains(target) else {
            focusedCategoryID = nil
            return
        }
        withAnimation(.snappy) { page = target }
        focusedCategoryID = keepTyping ? categories[target].id : nil
    }

    private func answerBinding(for category: Category) -> Binding<String> {
        Binding(
            get: { viewModel.answers[category.id] ?? "" },
            set: { viewModel.answers[category.id] = $0 }
        )
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

#Preview {
    GameBoardView(viewModel: .preview(.playing))
}
