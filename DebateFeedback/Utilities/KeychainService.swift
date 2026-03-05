//
//  KeychainService.swift
//  DebateFeedback
//
//

import Foundation
import Security

protocol KeychainStoring {
    func saveAuthToken(_ token: String) -> Bool
    func getAuthToken() -> String?
    @discardableResult
    func deleteAuthToken() -> Bool
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.debatefeedback.auth"
    private let account = "auth_token"

    private init() {}

    func saveAuthToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        var newItem = query
        newItem[kSecValueData as String] = data
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    func getAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func deleteAuthToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

extension KeychainService: KeychainStoring {}
