import Foundation

protocol CredentialStore: Sendable {
    func loadUserAPIKey() throws -> String
    func saveUserAPIKey(_ key: String) throws
    func clearUserAPIKey()
    func loadOAuthBootstrapKey() throws -> String
    func saveOAuthBootstrapKey(_ key: String) throws
}

struct KeychainCredentialStore: CredentialStore {
    private let service = "com.aurorastudio.openrouter"
    private let userAccount = "user-api-key"
    private let oauthBootstrapAccount = "oauth-bootstrap-api-key"

    func loadUserAPIKey() throws -> String {
        let data = try KeychainService.get(service: service, account: userAccount)
        guard let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            throw AppError.storageFailure("Stored API key is invalid")
        }
        return value
    }

    func saveUserAPIKey(_ key: String) throws {
        try KeychainService.set(data: Data(key.utf8), service: service, account: userAccount)
    }

    func clearUserAPIKey() {
        KeychainService.delete(service: service, account: userAccount)
    }

    func loadOAuthBootstrapKey() throws -> String {
        let data = try KeychainService.get(service: service, account: oauthBootstrapAccount)
        guard let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            throw AppError.storageFailure("Stored OAuth bootstrap key is invalid")
        }
        return value
    }

    func saveOAuthBootstrapKey(_ key: String) throws {
        try KeychainService.set(data: Data(key.utf8), service: service, account: oauthBootstrapAccount)
    }
}
