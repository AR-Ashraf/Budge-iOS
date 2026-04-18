import SwiftUI

/// Semantic colors aligned with web `charaTheme2.tsx` for chat and Budge mobile surfaces.
struct BudgeChatPalette {
    let colorScheme: ColorScheme

    // MARK: - Web `secondary.*` (single source for elevated chat chrome)

    /// Web Chakra `secondary.dark` (`#161617`) / `secondary.light` (`#FFFFFF`).
    /// Use for surfaces that should track theme: user message bubbles, chat composer shells/field well,
    /// starter cards, approval cards, and (in dark) the scroll-to-bottom FAB.
    var secondarySurface: Color {
        colorScheme == .dark ? Color(hex: "#161617") : Color(hex: "#FFFFFF")
    }

    /// Same as ``secondarySurface`` — chat cards and general elevated panels.
    var cardSurface: Color { secondarySurface }

    /// `primary.light` / `primary.dark`
    var screenBackground: Color {
        colorScheme == .dark ? Color(hex: "#1D1D1F") : Color(hex: "#F5F5F7")
    }

    /// Body / bubble text (`text.100` / `text.primary` family)
    var bodyText: Color {
        colorScheme == .dark ? Color(hex: "#F5FFF6") : Color(hex: "#163300")
    }

    var borderPrimary: Color {
        colorScheme == .dark ? Color(hex: "#333336") : Color(hex: "#D2D2D780")
    }

    var brandGreenPrimary: Color { Color(hex: "#71C635") }
    var brandGreenDarkText: Color { Color(hex: "#163300") }

    /// Currency pill: `green.100` tint
    var currencyPillBackground: Color {
        colorScheme == .dark ? Color(hex: "#009F2B").opacity(0.22) : Color(hex: "#009F2B").opacity(0.2)
    }

    /// `green.300`
    var currencyPillAccent: Color { Color(hex: "#04A10F") }

    /// Markdown `strong` — web `blue.500` / `blue.300`
    var markdownStrong: Color {
        colorScheme == .dark ? Color(hex: "#93C5FD") : Color(hex: "#0071E3")
    }

    /// Outer rounded composer shell — matches web input outer (`secondary` in dark).
    var inputOuterBackground: Color { secondarySurface }

    /// Inner text field / recording well — same as web inner field surface.
    var inputInnerBackground: Color { secondarySurface }

    var placeholder: Color {
        colorScheme == .dark ? Color(hex: "#F5FFF6").opacity(0.45) : Color(hex: "#163300").opacity(0.45)
    }

    var starterCardSubtitle: Color {
        colorScheme == .dark ? Color(hex: "#F5FFF6").opacity(0.75) : Color(hex: "#163300").opacity(0.75)
    }

    /// Scroll-to-bottom FAB fill. Dark uses ``secondarySurface`` (`#161617`); light uses a soft chip on the screen tint.
    var scrollFabBackground: Color {
        colorScheme == .dark ? secondarySurface : Color(hex: "#E5E5EA")
    }

    /// User-sent message bubble fill (web user `Card` uses `secondary`).
    var userMessageBubbleBackground: Color { secondarySurface }

    var secondaryIcon: Color {
        colorScheme == .dark ? Color(hex: "#F5FFF6").opacity(0.65) : Color(hex: "#163300").opacity(0.55)
    }
}
