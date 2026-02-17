import Foundation
import XCTest
@testable import AuroraStudioApp

private actor MockHistoryAssetStore: AssetStore {
    private let payloadsByID: [UUID: Data]

    init(payloadsByID: [UUID: Data]) {
        self.payloadsByID = payloadsByID
    }

    func save(assetData: Data, metadata: AssetMetadata) async throws -> EncryptedAssetRef {
        EncryptedAssetRef(
            id: UUID(),
            encryptedPath: "/tmp/mock",
            checksum: "mock",
            metadata: metadata
        )
    }

    func load(ref: EncryptedAssetRef) async throws -> Data {
        guard let data = payloadsByID[ref.id] else {
            throw AppError.storageFailure("missing payload")
        }
        return data
    }
}

final class ResultHistoryStoreTests: XCTestCase {
    func testUpsertAndLoadRoundTripRestoresImages() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aurora-history-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let assetID = UUID()
        let assetData = Data("hello-image".utf8)
        let ref = EncryptedAssetRef(
            id: assetID,
            encryptedPath: "/tmp/asset.bin",
            checksum: "checksum",
            metadata: AssetMetadata(role: "output", format: "image/png", width: 0, height: 0)
        )

        let store = try FileResultHistoryStore(
            assetStore: MockHistoryAssetStore(payloadsByID: [assetID: assetData]),
            fileManager: .default,
            baseDirectoryOverride: tempDirectory
        )

        let result = GenerationResult(
            jobID: UUID(),
            modelID: "openai/gpt-5-image",
            generatedAt: .now,
            text: "sample",
            images: [GeneratedImage(mimeType: "image/png", base64Data: "ignored")],
            storedAssets: [ref]
        )

        try await store.upsert(result)
        let loaded = try await store.loadResults()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].jobID, result.jobID)
        XCTAssertEqual(loaded[0].modelID, result.modelID)
        XCTAssertEqual(loaded[0].storedAssets, [ref])
        XCTAssertEqual(Data(base64Encoded: loaded[0].images[0].base64Data), assetData)
    }
}
