import CryptoKit
import Foundation

struct AssetMetadata: Sendable, Hashable, Codable {
    let role: String
    let format: String
    let width: Int
    let height: Int
}

struct EncryptedAssetRef: Sendable, Codable, Hashable {
    let id: UUID
    let encryptedPath: String
    let checksum: String
    let metadata: AssetMetadata
}

protocol AssetStore: Sendable {
    func save(assetData: Data, metadata: AssetMetadata) async throws -> EncryptedAssetRef
    func load(ref: EncryptedAssetRef) async throws -> Data
}

actor EncryptedFileAssetStore: AssetStore {
    private let keyManager: LocalEncryptionKeyManager
    private let fileManager: FileManager
    private let baseDirectory: URL

    init(
        keyManager: LocalEncryptionKeyManager = LocalEncryptionKeyManager(),
        fileManager: FileManager = .default
    ) throws {
        self.keyManager = keyManager
        self.fileManager = fileManager

        let supportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.baseDirectory = supportDirectory
            .appendingPathComponent("AuroraStudio", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)

        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func save(assetData: Data, metadata: AssetMetadata) async throws -> EncryptedAssetRef {
        let key = try keyManager.loadOrCreateKey()

        let sealedBox = try AES.GCM.seal(assetData, using: key)
        guard let combined = sealedBox.combined else {
            throw AppError.storageFailure("Failed to serialize encrypted payload")
        }

        let id = UUID()
        let fileName = id.uuidString + ".bin"
        let fileURL = baseDirectory.appendingPathComponent(fileName)

        try combined.write(to: fileURL, options: .atomic)

        let checksum = SHA256.hash(data: assetData).compactMap { String(format: "%02x", $0) }.joined()

        return EncryptedAssetRef(
            id: id,
            encryptedPath: fileURL.path,
            checksum: checksum,
            metadata: metadata
        )
    }

    func load(ref: EncryptedAssetRef) async throws -> Data {
        let encryptedData = try Data(contentsOf: URL(fileURLWithPath: ref.encryptedPath))
        let key = try keyManager.loadOrCreateKey()

        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
