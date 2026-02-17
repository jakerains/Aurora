import Foundation
import SwiftData

@Model
final class GenerationProjectEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var defaultModelID: String

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        defaultModelID: String = "bytedance-seed/seedream-4.5"
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.defaultModelID = defaultModelID
    }
}

@Model
final class GenerationRecordEntity {
    @Attribute(.unique) var id: UUID
    var projectID: UUID?
    var modelID: String
    var prompt: String
    var mode: String
    var status: String
    var createdAt: Date
    var finishedAt: Date?
    var latencyMS: Double?
    var costUSD: Double?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        modelID: String,
        prompt: String,
        mode: GenerationMode,
        status: GenerationJobStatus,
        createdAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.modelID = modelID
        self.prompt = prompt
        self.mode = mode.rawValue
        self.status = status.rawValue
        self.createdAt = createdAt
    }
}

@Model
final class GenerationAssetEntity {
    @Attribute(.unique) var id: UUID
    var recordID: UUID
    var role: String
    var format: String
    var width: Int
    var height: Int
    var localEncryptedPath: String
    var checksum: String

    init(
        id: UUID = UUID(),
        recordID: UUID,
        role: String,
        format: String,
        width: Int,
        height: Int,
        localEncryptedPath: String,
        checksum: String
    ) {
        self.id = id
        self.recordID = recordID
        self.role = role
        self.format = format
        self.width = width
        self.height = height
        self.localEncryptedPath = localEncryptedPath
        self.checksum = checksum
    }
}
