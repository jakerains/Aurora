import Foundation

final actor LiveGenerationService {
    private let apiClient: OpenRouterAPIClient
    private let modelCatalogService: ModelCatalogService
    private let assetStore: AssetStore
    private var modelEntriesByID: [String: ModelCatalogEntry] = [:]
    private lazy var queueService: GenerationQueueService = {
        GenerationQueueService { [weak self] job in
            guard let self else {
                return .failure(AppError.unknown("Generation service unavailable"))
            }

            do {
                return .success(try await self.execute(job: job))
            } catch {
                return .failure(error)
            }
        }
    }()

    init(
        apiClient: OpenRouterAPIClient,
        modelCatalogService: ModelCatalogService,
        assetStore: AssetStore
    ) {
        self.apiClient = apiClient
        self.modelCatalogService = modelCatalogService
        self.assetStore = assetStore
    }

    func enqueue(job: GenerationJob) async -> UUID {
        await queueService.enqueue(job)
    }

    func cancel(jobID: UUID) async {
        await queueService.cancel(jobID: jobID)
    }

    func snapshots() async -> AsyncStream<QueueSnapshot> {
        await queueService.snapshots()
    }

    func refreshCatalog() async throws -> [ModelCatalogEntry] {
        let entries = try await modelCatalogService.refreshCatalog()
        modelEntriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        return entries
    }

    func cachedCatalog() async -> [ModelCatalogEntry] {
        await modelCatalogService.cachedCatalog()
    }

    private func execute(job: GenerationJob) async throws -> GenerationResult {
        let selectedModelEntry = modelEntriesByID[job.modelID]
        let profile = selectedModelEntry?.imageCapabilityProfile ?? .imageAndText
        let request = ChatCompletionsRequest.from(job: job, profile: profile, modelEntry: selectedModelEntry)

        let response: ChatCompletionsResponse
        do {
            response = try await apiClient.createChatCompletion(request)
        } catch let AppError.httpStatus(code, body)
            where body.localizedCaseInsensitiveContains("image_config") {
            throw AppError.unknown(
                "The model \(job.modelID) rejected one or more image options. Try adjusting model-specific settings and retrying. (HTTP \(code))"
            )
        } catch {
            throw error
        }

        guard let message = response.choices.first?.message else {
            throw AppError.invalidResponse
        }

        guard let imagePayloads = message.images, !imagePayloads.isEmpty else {
            throw AppError.missingImages
        }

        var generated: [GeneratedImage] = []
        var stored: [EncryptedAssetRef] = []

        for payload in imagePayloads {
            guard let parsed = DataURL(rawValue: payload.imageURL.url) else { continue }
            let image = GeneratedImage(mimeType: parsed.mimeType, base64Data: parsed.base64Data)
            generated.append(image)

            if let data = parsed.decodeData() {
                let ref = try await assetStore.save(
                    assetData: data,
                    metadata: AssetMetadata(
                        role: "output",
                        format: parsed.mimeType,
                        width: 0,
                        height: 0
                    )
                )
                stored.append(ref)
            }
        }

        guard !generated.isEmpty else {
            throw AppError.missingImages
        }

        return GenerationResult(
            jobID: job.id,
            modelID: job.modelID,
            generatedAt: .now,
            text: message.content ?? "",
            images: generated,
            storedAssets: stored
        )
    }
}
