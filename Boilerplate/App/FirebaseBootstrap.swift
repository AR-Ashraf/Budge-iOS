import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        // Debug visibility: if Firebase isn't configured, everything downstream (Auth/Functions) will fail.
        if FirebaseApp.app() != nil {
            Logger.shared.app("Firebase already configured", level: .debug)
            return
        }

        let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        Logger.shared.app("Firebase configureIfNeeded starting. GoogleService-Info.plist in bundle: \(plistPath != nil)", level: .debug)

        let configureBlock = {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }

            if let app = FirebaseApp.app() {
                Logger.shared.app("Firebase configured. ProjectID=\(app.options.projectID ?? "nil") BundleID=\(Bundle.main.bundleIdentifier ?? "nil")", level: .debug)
            } else {
                Logger.shared.app("Firebase configure() completed but FirebaseApp.app() is still nil", level: .error)
            }
        }

        if Thread.isMainThread {
            configureBlock()
        } else {
            DispatchQueue.main.sync(execute: configureBlock)
        }
    }
}

