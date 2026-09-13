import Foundation

extension Notification.Name {
    static let nt365PushTokenDidChange = Notification.Name("nt365PushTokenDidChange")
}

final class PushTokenStore {
    static let shared = PushTokenStore()
    private let key = "nt365.firebase.push-token"

    private init() {}

    var token: String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    func update(_ newToken: String) {
        let value = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != token else { return }
        UserDefaults.standard.set(value, forKey: key)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .nt365PushTokenDidChange, object: value)
        }
    }
}
