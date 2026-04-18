import SwiftUI
import UIKit

/// Observes the nearest enclosing `UIScrollView` and reports how far the scroll position is from the bottom
/// (`maxOffset - contentOffset.y`). Near 0 when pinned to bottom; grows when the user scrolls up to read older messages.
/// This matches web “scroll to bottom” affordance more reliably than a `GeometryReader` on a `LazyVStack` top anchor
/// (which can disappear from the hierarchy when scrolled away).
struct ChatScrollOffsetReader: UIViewRepresentable {
    var onDistanceFromBottomChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDistanceFromBottomChange: onDistanceFromBottomChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDistanceFromBottomChange = onDistanceFromBottomChange
        context.coordinator.attachIfNeeded(anchorView: uiView)
    }

    final class Coordinator: NSObject {
        var onDistanceFromBottomChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var offsetObservation: NSKeyValueObservation?
        private var sizeObservation: NSKeyValueObservation?

        init(onDistanceFromBottomChange: @escaping (CGFloat) -> Void) {
            self.onDistanceFromBottomChange = onDistanceFromBottomChange
        }

        func attachIfNeeded(anchorView: UIView) {
            guard let scroll = Self.findEnclosingScrollView(from: anchorView) else {
                DispatchQueue.main.async { [weak self, weak anchorView] in
                    guard let self, let anchorView else { return }
                    self.attachIfNeeded(anchorView: anchorView)
                }
                return
            }

            guard scroll !== scrollView else {
                emit(scroll)
                return
            }

            scrollView = scroll
            tearDownObservations()

            offsetObservation = scroll.observe(\.contentOffset, options: [.initial, .new]) { [weak self] sv, _ in
                self?.emit(sv)
            }
            sizeObservation = scroll.observe(\.contentSize, options: [.initial, .new]) { [weak self] sv, _ in
                self?.emit(sv)
            }
            emit(scroll)
        }

        private func tearDownObservations() {
            offsetObservation?.invalidate()
            sizeObservation?.invalidate()
            offsetObservation = nil
            sizeObservation = nil
        }

        private func emit(_ sv: UIScrollView) {
            let maxOffsetY = max(0, sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom)
            let distanceFromBottom = maxOffsetY - sv.contentOffset.y
            DispatchQueue.main.async { [onDistanceFromBottomChange] in
                onDistanceFromBottomChange(distanceFromBottom)
            }
        }

        private static func findEnclosingScrollView(from view: UIView) -> UIScrollView? {
            var current: UIView? = view.superview
            while let c = current {
                if let scroll = c as? UIScrollView {
                    return scroll
                }
                current = c.superview
            }
            return nil
        }

        deinit {
            tearDownObservations()
        }
    }
}
