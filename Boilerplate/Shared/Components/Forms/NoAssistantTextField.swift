import SwiftUI
import UIKit

struct NoAssistantTextField: UIViewRepresentable {
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NoAssistantTextField

        init(parent: NoAssistantTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Intentionally no logs. (We used this temporarily to diagnose keyboard warnings.)
        }
    }

    @Binding var text: String
    let placeholder: String

    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var isSecureTextEntry: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.delegate = context.coordinator
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textColor = UIColor.label

        applyConfiguration(tf)
        tf.text = text

        // Hard-disable the assistant bar per-instance.
        let emptyGroups: [UIBarButtonItemGroup] = []
        tf.inputAssistantItem.leadingBarButtonGroups = emptyGroups
        tf.inputAssistantItem.trailingBarButtonGroups = emptyGroups

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
        tf.placeholder = placeholder
        tf.keyboardType = keyboardType
        tf.textContentType = textContentType
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.isSecureTextEntry = isSecureTextEntry
        tf.autocapitalizationType = autocapitalizationType
    }
}

