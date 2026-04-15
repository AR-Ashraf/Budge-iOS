import SwiftUI
import UIKit

/// A UITextField wrapper that:
/// - disables the iOS input assistant bar (avoids AutoLayout spam in some OS versions)
/// - supports chaining "Next" to another field by tag
/// - supports "Go/Done" submit via closure
struct ChainedTextField: UIViewRepresentable {
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ChainedTextField

        init(parent: ChainedTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let nextTag = parent.nextTag,
               let next = textField.window?.viewWithTag(nextTag) as? UITextField {
                next.becomeFirstResponder()
                return false
            }

            parent.onSubmit?()
            return false
        }
    }

    @Binding var text: String

    let placeholder: String
    let tag: Int
    var nextTag: Int?

    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var isSecureTextEntry: Bool = false
    var returnKeyType: UIReturnKeyType = .default
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.tag = tag
        tf.delegate = context.coordinator
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = UIColor.label

        // Disable input assistant bar per-instance.
        let emptyGroups: [UIBarButtonItemGroup] = []
        tf.inputAssistantItem.leadingBarButtonGroups = emptyGroups
        tf.inputAssistantItem.trailingBarButtonGroups = emptyGroups

        applyConfiguration(tf)
        tf.text = text
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        applyConfiguration(uiView)

        // Re-apply in case UIKit resets it.
        let emptyGroups: [UIBarButtonItemGroup] = []
        uiView.inputAssistantItem.leadingBarButtonGroups = emptyGroups
        uiView.inputAssistantItem.trailingBarButtonGroups = emptyGroups
    }

    private func applyConfiguration(_ tf: UITextField) {
        if tf.placeholder != placeholder { tf.placeholder = placeholder }
        if tf.keyboardType != keyboardType { tf.keyboardType = keyboardType }
        if tf.textContentType != textContentType { tf.textContentType = textContentType }
        if tf.autocorrectionType != .no { tf.autocorrectionType = .no }
        if tf.spellCheckingType != .no { tf.spellCheckingType = .no }
        if tf.autocapitalizationType != autocapitalizationType { tf.autocapitalizationType = autocapitalizationType }
        if tf.returnKeyType != returnKeyType { tf.returnKeyType = returnKeyType }
        if tf.isSecureTextEntry != isSecureTextEntry { tf.isSecureTextEntry = isSecureTextEntry }
    }
}

