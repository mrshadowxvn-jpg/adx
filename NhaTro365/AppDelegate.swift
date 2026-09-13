import UIKit
import UserNotifications

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    private weak var webController: WebViewController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let controller = WebViewController()
        webController = controller
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.backgroundColor = UIColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1)
        window.makeKeyAndVisible()
        self.window = window

        configurePushNotifications(application)

        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let url = notificationURL(from: payload) {
            controller.queueNotificationURL(url)
        }
        return true
    }

    private func configurePushNotifications(_ application: UIApplication) {
        #if canImport(FirebaseCore) && canImport(FirebaseMessaging)
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("Nhà Trọ 365: chưa có GoogleService-Info.plist; thông báo Firebase đang tắt.")
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            guard granted, error == nil else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        #else
        print("Nhà Trọ 365: thêm FirebaseMessaging bằng Swift Package Manager để bật thông báo.")
        #endif
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Nhà Trọ 365: không đăng ký được APNs: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let url = notificationURL(from: userInfo), application.applicationState == .active {
            webController?.queueNotificationURL(url)
        }
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let url = notificationURL(from: response.notification.request.content.userInfo) {
            webController?.queueNotificationURL(url)
        }
        completionHandler()
    }

    private func notificationURL(from payload: [AnyHashable: Any]) -> URL? {
        guard let raw = payload["url"] as? String,
              let url = URL(string: raw),
              WebViewController.isAllowedInternalURL(url) else { return nil }
        return url
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        PushTokenStore.shared.update(fcmToken ?? "")
    }
}
#endif
