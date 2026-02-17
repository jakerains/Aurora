import Foundation

protocol ResultHistoryStore: Sendable {
    func loadResults() async throws -> [GenerationResult]
    func upsert(_ result: GenerationResult) async throws
}

actor FileResultHistoryStore: ResultHistoryStore {
    private struct PersistedHistoryRecord: Codable, Hashable {
        let jobID: UUID
        let modelID: String
        let generatedAt: Date
        let text: String
        let storedAssets: [EncryptedAssetRef]
    }

    private let assetStore: AssetStore
    private let fileManager: FileManager
    private let historyFileURL: URL

    init(
        assetStore: AssetStore,
        fileManager: FileManager = .default,
        baseDirectoryOverride: URL? = nil
    ) throws {
        self.assetStore = assetStore
        self.fileManager = fileManager

        let baseDirectory: URL
        if let baseDirectoryOverride {
            baseDirectory = baseDirectoryOverride
        } else {
            let supportDirectory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            baseDirectory = supportDirectory
                .appendingPathComponent("AuroraStudio", isDirectory: true)
        }

        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        historyFileURL = baseDirectory.appendingPathComponent("history.json")
    }

    func loadResults() async throws -> [GenerationResult] {
        let records = try loadRecords()
        if records.isEmpty { return [] }

        var results: [GenerationResult] = []
        results.reserveCapacity(records.count)

        for record in records.sorted(by: { $0.generatedAt > $1.generatedAt }) {
            var images: [GeneratedImage] = []
            images.reserveCapacity(record.storedAssets.count)

            for ref in record.storedAssets {
                guard let data = try? await assetStore.load(ref: ref) else { continue }
                images.append(
                    GeneratedImage(
                        mimeType: ref.metadata.format,
                        base64Data: data.base64EncodedString()
                    )
                )
            }

            if images.isEmpty { continue }

            results.append(
                GenerationResult(
                    jobID: record.jobID,
                    modelID: record.modelID,
                    generatedAt: record.generatedAt,
                    text: record.text,
                    images: images,
                    storedAssets: record.storedAssets
                )
            )
        }

        return results
    }

    func upsert(_ result: GenerationResult) async throws {
        var records = try loadRecords()

        records.removeAll { $0.jobID == result.jobID }
        records.insert(
            PersistedHistoryRecord(
                jobID: result.jobID,
                modelID: result.modelID,
                generatedAt: result.generatedAt,
                text: result.text,
                storedAssets: result.storedAssets
            ),
            at: 0
        )

        try saveRecords(records)
    }

    private func loadRecords() throws -> [PersistedHistoryRecord] {
        guard fileManager.fileExists(atPath: historyFileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: historyFileURL)
            return try JSONDecoder().decode([PersistedHistoryRecord].self, from: data)
        } catch {
            throw AppError.storageFailure("Unable to load history metadata: \(error.localizedDescription)")
        }
    }

    private func saveRecords(_ records: [PersistedHistoryRecord]) throws {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            throw AppError.storageFailure("Unable to save history metadata: \(error.localizedDescription)")
        }
    }
}
