import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging
import GoogleSignIn
import UserNotifications
import UIKit

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    private static let cachedFcmTokenKey = "cachedFcmRegistrationToken"
    private static let approvalCategoryId = "APPROVAL_ACTIONS"
    private static let approvalAllowActionId = "APPROVAL_ALLOW"
    private static let approvalDenyActionId = "APPROVAL_DENY"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()
        configurePushNotifications(application)
        return true
    }

    private func configurePushNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        let allow = UNNotificationAction(
            identifier: Self.approvalAllowActionId,
            title: "Allow",
            options: []
        )
        let deny = UNNotificationAction(
            identifier: Self.approvalDenyActionId,
            title: "Deny",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.approvalCategoryId,
            actions: [allow, deny],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        // Request permission (best-effort; user can change later in Settings).
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            #if DEBUG
            if let err { print("[Push] requestAuthorization error: \(err)") }
            print("[Push] permission granted=\(granted)")
            #endif
        }

        application.registerForRemoteNotifications()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[Push] didFailToRegisterForRemoteNotifications: \(error)")
        #endif
    }

    private func upsertFcmTokenIfPossible(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Cache always; we'll upsert once auth is available.
        UserDefaults.standard.set(trimmed, forKey: Self.cachedFcmTokenKey)

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            return
        }

        let db = Firestore.firestore()
        let ref = db.collection("fcmTokens").document()
        let now = FieldValue.serverTimestamp()
        ref.setData([
            "uid": uid,
            "token": trimmed,
            "platform": "ios",
            "updatedAt": now,
            "createdAt": now,
        ], merge: true)
    }
}

extension FirebaseAppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions
    {
        // Show banners while app is foregrounded.
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        let type = userInfo["type"] as? String
        let chatId = userInfo["chatId"] as? String
        let approvalId = userInfo["approvalId"] as? String

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            if type == "approval", let chatId {
                NotificationCenter.default.post(name: .openChatFromPush, object: nil, userInfo: ["chatId": chatId])
            }
        case Self.approvalAllowActionId:
            await submitApprovalDecision(choice: "allow", chatId: chatId, approvalId: approvalId)
        case Self.approvalDenyActionId:
            await submitApprovalDecision(choice: "deny", chatId: chatId, approvalId: approvalId)
        default:
            break
        }
    }

    private func submitApprovalDecision(choice: String, chatId: String?, approvalId: String?) async {
        guard let chatId, let approvalId else { return }
        // Auth is required by the callable; if user is signed out, do nothing.
        guard Auth.auth().currentUser != nil else { return }
        do {
            let callable = Functions.functions(region: "us-central1").httpsCallable("chat_submitApprovalDecision")
            _ = try await callable.call([
                "chatId": chatId,
                "approvalId": approvalId,
                "choice": choice,
            ])
        } catch {
            #if DEBUG
            print("[Push] submitApprovalDecision failed chatId=\(chatId) approvalId=\(approvalId) choice=\(choice) err=\(error)")
            #endif
        }
    }
}

extension FirebaseAppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        #if DEBUG
        print("[Push] didReceiveRegistrationToken token=\(fcmToken)")
        #endif
        upsertFcmTokenIfPossible(fcmToken)
    }
}

