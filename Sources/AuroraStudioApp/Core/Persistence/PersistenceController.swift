import Foundation
import SwiftData

enum PersistenceController {
    static func container(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            GenerationProjectEntity.self,
            GenerationRecordEntity.self,
            GenerationAssetEntity.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
