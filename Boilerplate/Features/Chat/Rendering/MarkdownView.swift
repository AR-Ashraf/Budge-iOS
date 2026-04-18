import MarkdownUI
import SwiftUI

struct MarkdownView: View {
    enum Style {
        case plain
        /// Web parity: GFM blocks, lists, tables, fences — styled like `ReactMarkdown` + `remarkGfm` in `chat.tsx`.
        case assistantMarkdown
    }

    let text: String
    var style: Style = .plain

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = BudgeChatPalette(colorScheme: colorScheme)
        switch style {
        case .plain:
            if let attributed = try? AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
            ) {
                Text(attributed)
                    .textSelection(.enabled)
            } else {
                Text(text)
                    .textSelection(.enabled)
            }
        case .assistantMarkdown:
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyView()
            } else {
                Markdown(text)
                    .markdownTheme(.budgeAssistantMarkdown(palette))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
