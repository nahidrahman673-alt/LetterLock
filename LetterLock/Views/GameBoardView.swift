//
//  GameBoardView.swift
//  LetterLock
//

import SwiftUI

struct GameBoardView: View {
    let viewModel: GameViewModel

    @State private var page = 0
    @State private var focusedCategoryID: UUID?
    @State private var isConfirmingLockIn = false

    private var categories: [Category] { viewModel.categories }

    /// While the keyboard is up, the screen tightens so the answer box and Back/Next
    /// stay clear of the Lock In button.
    private var isTyping: Bool { focusedCategoryID != nil }

    var body: some View {
        VStack(spacing: isTyping ? 6 : 14) {
            header
            // Hidden while typing to save room, unless the clock has just been cut.
            if !isTyping || viewModel.wasTimerCut {
                lockInStatus
            }
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
        .animation(.snappy(duration: 0.2), value: isTyping)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        // Next is the big button by the thumbs; Lock In sits higher up and asks first, because
        // playtesters kept hitting Lock In by accident when it was the big bottom button.
        .safeAreaInset(edge: .bottom) {
            nextButton
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.letterNavy)
        }
        .onChange(of: viewModel.isLocalLockedIn) {
            if viewModel.isLocalLockedIn { focusedCategoryID = nil }
        }
        .alert("Lock in your answers?", isPresented: $isConfirmingLockIn) {
            Button("Lock In") { viewModel.lockIn() }
            Button("Keep answering", role: .cancel) {}
        } message: {
            Text("You can't change them after this.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            LetterTile(letter: viewModel.currentLetter, size: isTyping ? 38 : 56)
                .accessibilityLabel("Letter \(viewModel.currentLetter)")

            Text("ROUND \(viewModel.currentRound)/\(viewModel.totalRounds)")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)
                .padding(.leading, 6)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(viewModel.timeRemaining)")
                    .font(.system(size: isTyping ? 32 : 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: viewModel.timeRemaining)
                    .foregroundStyle(viewModel.timeRemaining <= 10 ? Color.letterCoral : Color.letterCream)
                if !isTyping {
                    Text("SECONDS")
                        .font(.caption2.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(Color.letterMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.timeRemaining) seconds left")
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    /// One circle per player that lights up coral (with a little pop) when they lock in.
    /// Once the clock is cut, a coral warning takes over.
    @ViewBuilder
    private var lockInStatus: some View {
        let locked = viewModel.lockedInPlayerIds.count
        if viewModel.wasTimerCut {
            Label("\(locked) players locked in. \(GameViewModel.lockInCutSeconds) seconds left!", systemImage: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.letterNavy)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.letterCoral, in: .capsule)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.letterMuted)
                HStack(spacing: 6) {
                    ForEach(viewModel.players) { player in
                        LockInDot(
                            isLocked: viewModel.lockedInPlayerIds.contains(player.id),
                            isYou: player.isLocal
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.letterSurface, in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(locked) of \(viewModel.players.count) players locked in. \(GameViewModel.lockInsToCutTimer) cuts the clock to \(GameViewModel.lockInCutSeconds) seconds.")
        }
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
                    .frame(height: isTyping ? 28 : 44)
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
        VStack(alignment: .leading, spacing: isTyping ? 8 : 14) {
            Text("\(index + 1) OF \(categories.count)")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)

            Text(category.name)
                .font(.system(isTyping ? .title : .largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterCream)
                .minimumScaleFactor(0.6)
                .lineLimit(isTyping ? 1 : 2)

            GameTextField(
                text: answerBinding(for: category),
                isFocused: focusBinding(for: category),
                placeholder: "Starts with \(viewModel.currentLetter)",
                returnKey: index == categories.count - 1 ? .done : .next,
                isEnabled: !viewModel.isInputFrozen,
                onSubmit: { goToPage(index + 1, keepTyping: true) }
            )
            .accessibilityLabel(category.name)
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

                .font(.headline)
                .foregroundStyle(Color.letterYellow)

                Spacer()

                lockInButton
            }

            // The quote sits centred in the free space above Next. It hides while typing,
            // when that space is taken by the keyboard.
            ZStack {
                if !isTyping {
                    QuoteView()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Next and Lock In

    /// The big bottom button. On the last category it goes back to the first, so it never becomes Lock In.
    @ViewBuilder
    private var nextButton: some View {
        if viewModel.isLocalLockedIn {
            Label("Locked in. Waiting for the clock", systemImage: "lock.fill")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.letterMint)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Color.letterSurface, in: .rect(cornerRadius: 16))
        } else {
            let isLast = page >= categories.count - 1
            Button {
                goToPage(isLast ? 0 : page + 1, keepTyping: focusedCategoryID != nil)
            } label: {
                Label(isLast ? "Back to start" : "Next", systemImage: isLast ? "arrow.uturn.left" : "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .buttonStyle(FilledGameButtonStyle())
        }
    }

    /// Small coral button beside Back. Asks before locking in, since it can't be undone.
    @ViewBuilder
    private var lockInButton: some View {
        if !viewModel.isLocalLockedIn {
            Button {
                isConfirmingLockIn = true
            } label: {
                Label("Lock In", systemImage: "lock.open.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.letterNavy)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Color.letterCoral, in: .capsule)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .disabled(viewModel.isInputFrozen)
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

    private func focusBinding(for category: Category) -> Binding<Bool> {
        Binding(
            get: { focusedCategoryID == category.id },
            set: { focused in
                if focused {
                    focusedCategoryID = category.id
                } else if focusedCategoryID == category.id {
                    focusedCategoryID = nil
                }
            }
        )
    }

    private func answerBinding(for category: Category) -> Binding<String> {
        Binding(
            get: { viewModel.answers[category.id] ?? "" },
            set: { viewModel.answers[category.id] = $0 }
        )
    }
}

/// "Great minds ~~think alike.~~ Don't." The game rewards answers nobody else gives.
private struct QuoteView: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Great minds \(Text("think alike.").strikethrough(true, color: .letterMuted))")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.letterMuted)
            Text("Don't.")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.letterYellow)
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Great minds think alike. Don't.")
    }
}

/// A player's lock-in light: dim until they lock in, then coral with one quick pop (no flashing).
/// Your own has a cream ring so you can spot it.
private struct LockInDot: View {
    let isLocked: Bool
    let isYou: Bool

    var body: some View {
        Circle()
            .fill(isLocked ? Color.letterCoral : Color.letterBorder)
            .frame(width: 14, height: 14)
            .overlay {
                if isYou {
                    Circle().strokeBorder(Color.letterCream, lineWidth: 2)
                        .padding(-3)
                }
            }
            .shadow(color: isLocked ? Color.letterCoral.opacity(0.7) : .clear, radius: 5)
            // One pop when it lights up. (Dots only go dark again when a new round starts.)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: isLocked) { dot, scale in
                dot.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(CGFloat(1.6), duration: 0.15)
                    SpringKeyframe(CGFloat(1), duration: 0.35, spring: .bouncy)
                }
            }
            .animation(.easeOut(duration: 0.2), value: isLocked)
            .frame(width: 20, height: 20)
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
