import MarkdownUI
import SwiftUI

extension Theme {
    /// GFM layout (lists, tables, fences) via GitHub-style blocks, tinted for Budge chat (`charaTheme2` parity).
    static func budgeAssistantMarkdown(_ palette: BudgeChatPalette) -> Theme {
        let muted = palette.starterCardSubtitle
        let codeFill = palette.colorScheme == .dark ? Color(hex: "#25262A") : Color(hex: "#EFEFF4")
        let tableStripe = palette.colorScheme == .dark ? Color(hex: "#232326").opacity(0.9) : Color(hex: "#ECECF1")

        return Theme.gitHub
            .text {
                ForegroundColor(palette.bodyText)
                BackgroundColor(.clear)
                FontSize(16)
            }
            .strong {
                FontWeight(.semibold)
                ForegroundColor(palette.markdownStrong)
            }
            .emphasis {
                FontStyle(.italic)
                ForegroundColor(muted)
            }
            .link {
                ForegroundColor(palette.markdownStrong)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                ForegroundColor(palette.bodyText)
                BackgroundColor(codeFill.opacity(0.88))
            }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativeLineSpacing(.em(0.12))
                        .markdownMargin(top: 20, bottom: 10)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.65))
                            ForegroundColor(palette.bodyText)
                        }
                    Divider()
                        .overlay(palette.borderPrimary.opacity(0.55))
                }
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativeLineSpacing(.em(0.12))
                        .markdownMargin(top: 18, bottom: 8)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.38))
                            ForegroundColor(palette.bodyText)
                        }
                    Divider()
                        .overlay(palette.borderPrimary.opacity(0.55))
                }
            }
            .heading3 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.12))
                    .markdownMargin(top: 16, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.2))
                        ForegroundColor(palette.bodyText)
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.12))
                    .markdownMargin(top: 14, bottom: 6)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.06))
                        ForegroundColor(palette.bodyText)
                    }
            }
            .heading5 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.12))
                    .markdownMargin(top: 12, bottom: 6)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.95))
                        ForegroundColor(palette.bodyText)
                    }
            }
            .heading6 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.12))
                    .markdownMargin(top: 12, bottom: 6)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.88))
                        ForegroundColor(muted)
                    }
            }
            .blockquote { configuration in
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(palette.markdownStrong.opacity(0.5))
                        .frame(width: 3)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(muted)
                            FontStyle(.italic)
                        }
                        .relativePadding(.horizontal, length: .em(0.9))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .codeBlock { configuration in
                ScrollView(.horizontal, showsIndicators: true) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.22))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                            ForegroundColor(palette.bodyText)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(codeFill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(palette.borderPrimary.opacity(0.55), lineWidth: 1)
                )
                .markdownMargin(top: 0, bottom: 14)
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: palette.borderPrimary))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(.clear, tableStripe)
                    )
                    .markdownMargin(top: 0, bottom: 14)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                            ForegroundColor(palette.bodyText)
                        }
                        BackgroundColor(nil)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 11)
                    .relativeLineSpacing(.em(0.25))
            }
            .thematicBreak {
                Divider()
                    .overlay(palette.borderPrimary.opacity(0.7))
                    .relativeFrame(height: .em(0.2))
                    .markdownMargin(top: 18, bottom: 18)
            }
    }
}
