import Foundation
import Security

public final class KeychainHelper {
    public static let shared = KeychainHelper()

    private let service: String
    private let defaultTokenKey = "portmusic_auth_token"
    private let lock = NSLock()

    public init(service: String = "com.portmusic.ios.auth") {
        self.service = service
    }

    // MARK: - Token Komfort-Methoden

    @discardableResult
    public func saveToken(_ token: String) -> Bool {
        return set(token, forKey: defaultTokenKey)
    }

    public func getToken() -> String? {
        return get(forKey: defaultTokenKey)
    }

    @discardableResult
    public func deleteToken() -> Bool {
        return delete(forKey: defaultTokenKey)
    }

    // MARK: - Generische Keychain-Operationen

    @discardableResult
    public func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        return setData(data, forKey: key)
    }

    public func get(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func delete(forKey key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    public func setData(_ data: Data, forKey key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func getData(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return data
    }
}
