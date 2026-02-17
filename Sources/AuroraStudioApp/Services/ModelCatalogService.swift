import Foundation

struct PopularModelSeed: Codable {
    let id: String
    let displayName: String
    let rank: Int
    let tags: [String]
}

struct CuratedImageModelSeed: Codable {
    let id: String
    let displayName: String
    let description: String
    let priceSummary: String
    let allowedAspectRatios: [String]?
    let allowedImageSizes: [String]?
    let minImageCount: Int?
    let maxImageCount: Int?
    let supportsImageCount: Bool?
    let supportsFontInputs: Bool?
    let supportsSuperResolutionReferences: Bool?
}

protocol ModelCatalogService: Sendable {
    func refreshCatalog() async throws -> [ModelCatalogEntry]
    func cachedCatalog() async -> [ModelCatalogEntry]
}

actor LiveModelCatalogService: ModelCatalogService {
    private let apiClient: OpenRouterAPIClient
    private let popularityMap: [String: Int]
    private let curatedModels: [CuratedImageModelSeed]
    private var cache: [ModelCatalogEntry] = []

    init(apiClient: OpenRouterAPIClient, bundle: Bundle = .module) {
        self.apiClient = apiClient
        self.popularityMap = Self.loadPopularityMap(bundle: bundle)
        self.curatedModels = Self.loadCuratedImageModels(bundle: bundle)
    }

    func refreshCatalog() async throws -> [ModelCatalogEntry] {
        let models = try await fetchBestAvailableModelList()

        var entriesByID = Dictionary(
            uniqueKeysWithValues: models
                .filter { $0.supportsImageGeneration }
                .map { model in
                    let entry = model.asCatalogEntry(popularityRank: popularityMap[model.id])
                    return (entry.id, entry)
                }
        )

        let curatedByID = Dictionary(uniqueKeysWithValues: curatedModels.map { ($0.id, $0) })

        for curated in curatedModels {
            if var existing = entriesByID[curated.id] {
                if existing.pricePerImageRaw == nil || existing.pricePerImageRaw?.isEmpty == true {
                    existing = existing.withPriceDisplayOverride(curated.priceSummary)
                }
                existing = applyCapabilityRules(to: existing, curated: curated)
                entriesByID[curated.id] = existing
            } else {
                var entry = ModelCatalogEntry(
                    id: curated.id,
                    displayName: curated.displayName,
                    description: curated.description,
                    modalitySignature: nil,
                    outputModalities: ["image"],
                    inputModalities: ["text", "image"],
                    pricePerImage: nil,
                    pricePerImageRaw: nil,
                    priceDisplayOverride: curated.priceSummary,
                    imageCapabilityProfile: .imageOnly,
                    supportsImageInput: true,
                    supportsImageConfig: true,
                    supportedParameters: [],
                    imageOptionSupport: .baseline,
                    supportsAdvancedImageOptions: false,
                    popularityRank: popularityMap[curated.id]
                )

                entry = applyCapabilityRules(to: entry, curated: curated)
                entriesByID[curated.id] = entry
            }
        }

        for id in Array(entriesByID.keys) {
            guard var entry = entriesByID[id] else { continue }
            if let curated = curatedByID[id] {
                entry = applyCapabilityRules(to: entry, curated: curated)
            } else {
                entry = applyCapabilityRules(to: entry, curated: nil)
            }
            entriesByID[id] = entry
        }

        let entries = entriesByID.values.sorted(by: sortEntries)
        cache = entries
        return entries
    }

    func cachedCatalog() async -> [ModelCatalogEntry] {
        cache
    }

    private func fetchBestAvailableModelList() async throws -> [OpenRouterModel] {
        do {
            let userModels = try await apiClient.fetchUserModels()
            if !userModels.isEmpty { return userModels }
        } catch {
            // Fallback to global models endpoint.
        }

        return try await apiClient.fetchModels()
    }

    private func applyCapabilityRules(to entry: ModelCatalogEntry, curated: CuratedImageModelSeed?) -> ModelCatalogEntry {
        var support = entry.imageOptionSupport

        // Sourceful fast/pro are documented to support custom font inputs and super-resolution references.
        if entry.id == "sourceful/riverflow-v2-fast" || entry.id == "sourceful/riverflow-v2-pro" {
            support = support.applying(
                supportsFontInputs: true,
                supportsSuperResolutionReferences: true
            )
        }

        if let curated {
            support = support.applying(
                allowedAspectRatios: curated.allowedAspectRatios,
                allowedImageSizes: curated.allowedImageSizes,
                minImageCount: curated.minImageCount,
                maxImageCount: curated.maxImageCount,
                supportsImageCount: curated.supportsImageCount,
                supportsFontInputs: curated.supportsFontInputs,
                supportsSuperResolutionReferences: curated.supportsSuperResolutionReferences
            )
        }

        if !entry.supportsImageConfig {
            support = .none
        }

        return entry.withImageOptionSupport(support)
    }

    private func sortEntries(_ lhs: ModelCatalogEntry, _ rhs: ModelCatalogEntry) -> Bool {
        switch (lhs.popularityRank, rhs.popularityRank) {
        case let (l?, r?):
            if l != r { return l < r }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    private static func loadPopularityMap(bundle: Bundle) -> [String: Int] {
        guard let url = bundle.url(forResource: "popular_models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seeds = try? JSONDecoder().decode([PopularModelSeed].self, from: data) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: seeds.map { ($0.id, $0.rank) })
    }

    private static func loadCuratedImageModels(bundle: Bundle) -> [CuratedImageModelSeed] {
        guard let url = bundle.url(forResource: "curated_image_models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seeds = try? JSONDecoder().decode([CuratedImageModelSeed].self, from: data) else {
            return []
        }

        return seeds
    }
}
