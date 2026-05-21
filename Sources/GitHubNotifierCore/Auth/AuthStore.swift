import Foundation
import LocalAuthentication
import Security

public actor AuthStore {
    public static let shared = AuthStore()

    public static let oauthKey = "github_oauth_access_token"
    private static let service = "com.samzong.GitHubNotifier.auth"

    private init() {}

    public func currentToken() -> String? {
        if let token = read(key: Self.oauthKey) {
            return token
        }
        guard let legacyToken = read(key: Self.oauthKey, service: nil) else {
            return nil
        }
        write(legacyToken, key: Self.oauthKey)
        delete(key: Self.oauthKey, service: nil)
        return legacyToken
    }

    public func saveToken(_ token: String) {
        write(token, key: Self.oauthKey)
    }

    public func clearToken() {
        delete(key: Self.oauthKey)
    }

    // MARK: - Migration: clean up legacy PAT keys on first launch

    public func cleanLegacyKeys() {
        delete(key: "github_personal_access_token", service: nil)
        delete(key: "github_auth_method", service: nil)
    }

    // MARK: - Low-level Keychain (ThisDeviceOnly)

    private func write(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(key: String, service: String? = AuthStore.service) -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true

        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
            kSecUseAuthenticationUI: "u_AuthUIF",
        ]
        if let service {
            query[kSecAttrService] = service
        }
        var ref: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private func delete(key: String, service: String? = AuthStore.service) -> Bool {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        if let service {
            query[kSecAttrService] = service
        }
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
