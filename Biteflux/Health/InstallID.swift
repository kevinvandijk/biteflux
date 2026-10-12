import Foundation
import Security

/// A random ID for Biteflux on this iPhone, so it knows which logged food it writes to Apple Health.
/// It lives in the Keychain, which keeps it through a reinstall on the same iPhone but never hands
/// it to another device, the way iCloud sync or a backup restore would.
enum InstallID {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.kevinvandijk.biteflux.install",
        kSecAttrAccount as String: "install-id",
    ]
    /// Where an earlier build kept the ID, and the fallback if the Keychain can't be written.
    private static let defaultsKey = "installID"

    static func current() -> String {
        if let id = stored() { return id }
        let id = UserDefaults.standard.string(forKey: defaultsKey) ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: defaultsKey)
        var item = query
        item[kSecValueData as String] = Data(id.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
        return id
    }

    private static func stored() -> String? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
