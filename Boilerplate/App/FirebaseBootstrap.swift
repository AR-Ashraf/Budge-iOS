import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        if FirebaseApp.app() != nil { return }

        let configureBlock = {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
        }

        if Thread.isMainThread {
            configureBlock()
        } else {
            DispatchQueue.main.sync(execute: configureBlock)
        }
    }
}

