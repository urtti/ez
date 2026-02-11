import Foundation
import Security

enum KeychainError: Error {
    case duplicateKey
    case notFound
    case authenticationFailed
    case unexpectedError(OSStatus)

    var message: String {
        switch self {
        case .duplicateKey:
            return "Secret already exists. Use --force to overwrite."
        case .notFound:
            return "Secret not found in keychain."
        case .authenticationFailed:
            return "Authentication failed."
        case .unexpectedError(let status):
            return "Keychain error: \(status)"
        }
    }
}

enum KeychainManager {
    private static let service = "com.urtti.ez"

    static func addSecret(key: String, value: String, force: Bool) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.unexpectedError(errSecParam)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            if !force {
                throw KeychainError.duplicateKey
            }
            // Update existing item
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: valueData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainError.unexpectedError(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedError(status)
        }
    }

    static func readSecret(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedError(errSecDecode)
            }
            return value
        case errSecItemNotFound:
            throw KeychainError.notFound
        case errSecUserCanceled, errSecAuthFailed:
            throw KeychainError.authenticationFailed
        default:
            throw KeychainError.unexpectedError(status)
        }
    }

    static func removeSecret(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.notFound
        default:
            throw KeychainError.unexpectedError(status)
        }
    }
}
