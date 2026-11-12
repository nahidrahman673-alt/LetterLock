//
//  GameTextField.swift
//  LetterLock
//

import SwiftUI
import UIKit

/// A text box with every keyboard suggestion switched off: autocorrect, spell check, the predictive
/// word bar and the grey inline completions. SwiftUI's own TextField can only turn off autocorrect, and
/// on a real iPhone the predictive bar still appeared, nudging players towards the same common words.
struct GameTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    var capitalization: UITextAutocapitalizationType = .words
    var returnKey: UIReturnKeyType = .done
    var textStyle: UIFont.TextStyle = .title3
    var isEnabled = true
    var characterLimit: Int?
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> FocusingTextField {
        let field = FocusingTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        // The point of this view: no suggestions of any kind.
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.inlinePredictionType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.grammarCheckingType = .no
        field.writingToolsBehavior = .none
        field.keyboardAppearance = .dark

        field.font = UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(for: .systemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize, weight: .semibold))
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor(Color.letterCream)
        field.tintColor = UIColor(Color.letterYellow)
        // Lets SwiftUI decide the width instead of the text pushing the box wider.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: FocusingTextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.autocapitalizationType = capitalization
        field.returnKeyType = returnKey
        field.isEnabled = isEnabled
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(Color.letterMuted)]
        )
        field.wantsFocus = isFocused && isEnabled
    }

    /// Full width offered, but only as tall as one line of text (otherwise it stretches to fill the screen).
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FocusingTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width, height: uiView.intrinsicContentSize.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: GameTextField

        init(parent: GameTextField) { self.parent = parent }

        @objc func textChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let limit = parent.characterLimit else { return true }
            let current = field.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            return current.replacingCharacters(in: swiftRange, with: string).count <= limit
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

/// Takes or gives up the keyboard when asked, including when it only joins the screen later
/// (for example a category page that the pager hasn't built yet).
final class FocusingTextField: UITextField {
    var wantsFocus = false {
        didSet { applyFocus() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyFocus()
    }

    private func applyFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            if self.wantsFocus, !self.isFirstResponder {
                self.becomeFirstResponder()
            } else if !self.wantsFocus, self.isFirstResponder {
                self.resignFirstResponder()
            }
        }
    }
}
