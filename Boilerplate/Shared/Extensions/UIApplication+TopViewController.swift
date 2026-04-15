import UIKit

extension UIApplication {
    var topMostViewController: UIViewController? {
        let scenes = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        let windows = scenes.flatMap { $0.windows }
        let keyWindow = windows.first(where: { $0.isKeyWindow }) ?? windows.first

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

