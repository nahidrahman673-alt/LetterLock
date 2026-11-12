//
//  NameEntryView.swift
//  LetterLock
//

import SwiftUI

/// "What should we call you?" Shown the first time someone starts or joins a game, and again
/// when they tap their own name in the lobby. The name is saved on the phone.
struct NameEntryView: View {
    let viewModel: GameViewModel
    var buttonTitle = "Let's play"
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isFocused = true

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.letterYellow)
                    .frame(minWidth: 44, minHeight: 44)
            }

            Text("What should we call you?")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.letterCream)

            Text("Shown to other players in the lobby and on the scores.")
                .font(.body)
                .foregroundStyle(Color.letterMuted)

            Text("YOUR NAME")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.letterMuted)
                .padding(.top, 10)

            GameTextField(
                text: $name,
                isFocused: $isFocused,
                placeholder: "Your name",
                returnKey: .done,
                characterLimit: GameViewModel.playerNameLimit,
                onSubmit: save
            )
            .accessibilityLabel("Your name")
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .background(Color.letterSurface, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isFocused ? Color.letterYellow : Color.letterBorder, lineWidth: isFocused ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 14))
            .onTapGesture { isFocused = true }

            Spacer()

            Button(buttonTitle, action: save)
                .buttonStyle(FilledGameButtonStyle(
                    fill: canSave ? .letterYellow : .letterBorder,
                    text: canSave ? .letterNavy : .letterMuted
                ))
                .disabled(!canSave)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.letterNavy)
        .onAppear { name = viewModel.playerName }
    }

    private func save() {
        guard canSave else { return }
        viewModel.setPlayerName(name)
        dismiss()
        onDone()
    }
}

#Preview {
    NameEntryView(viewModel: GameViewModel()) {}
}
