import CryptoKit
import Foundation

struct LocalEncryptionKeyManager {
    private let service = "com.aurorastudio.local-encryption"
    private let account = "asset-key"

    func loadOrCreateKey() throws -> SymmetricKey {
        do {
            let data = try KeychainService.get(service: service, account: account)
            return SymmetricKey(data: data)
        } catch KeychainServiceError.notFound {
            let key = SymmetricKey(size: .bits256)
            let data = key.withUnsafeBytes { Data($0) }
            try KeychainService.set(data: data, service: service, account: account)
            return key
        }
    }
}
