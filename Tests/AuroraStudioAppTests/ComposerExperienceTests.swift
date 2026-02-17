import Foundation
import XCTest
@testable import AuroraStudioApp

private struct ComposerTestAPIClient: OpenRouterAPIClient {
    func fetchModels() async throws -> [OpenRouterModel] { [] }
    func fetchUserModels() async throws -> [OpenRouterModel] { [] }

    func createChatCompletion(_ request: ChatCompletionsRequest) async throws -> ChatCompletionsResponse {
        throw AppError.unknown("not used")
    }

    func createAuthCode(
        callbackURL: URL,
        codeChallenge: String,
        codeChallengeMethod: String,
        limit: Double?
    ) async throws -> OAuthAuthCodeResponse {
        throw AppError.unknown("not used")
    }

    func exchangeAuthCode(
        code: String,
        codeVerifier: String,
        codeChallengeMethod: String
    ) async throws -> OAuthExchangeResponse {
        throw AppError.unknown("not used")
    }
}

private actor ComposerTestAssetStore: AssetStore {
    func save(assetData: Data, metadata: AssetMetadata) async throws -> EncryptedAssetRef {
        EncryptedAssetRef(id: UUID(), encryptedPath: "/tmp/mock", checksum: "mock", metadata: metadata)
    }

    func load(ref: EncryptedAssetRef) async throws -> Data {
        Data()
    }
}

private actor ComposerTestOAuthService: OAuthService {
    func beginAuthorization(callbackURL: URL) async throws -> OAuthAuthorizationSession {
        OAuthAuthorizationSession(
            callbackURL: callbackURL,
            codeVerifier: "verifier",
            codeChallengeMethod: "S256",
            authorizationURL: callbackURL
        )
    }

    func exchangeAuthorizationCode(_ code: String, session: OAuthAuthorizationSession) async throws -> String {
        "mock-key"
    }
}

private struct ComposerTestCredentialStore: CredentialStore {
    func loadUserAPIKey() throws -> String { "mock-key" }
    func saveUserAPIKey(_ key: String) throws {}
    func clearUserAPIKey() {}
    func loadOAuthBootstrapKey() throws -> String { "mock-bootstrap" }
    func saveOAuthBootstrapKey(_ key: String) throws {}
}

@MainActor
private final class ComposerTestImageExportService: ImageExportService {
    func export(imageData: Data, suggestedName: String) async throws {}
}

private actor ComposerTestHistoryStore: ResultHistoryStore {
    func loadResults() async throws -> [GenerationResult] { [] }
    func upsert(_ result: GenerationResult) async throws {}
}

@MainActor
private func makeComposerTestAppState() -> AppState {
    let apiClient = ComposerTestAPIClient()
    let modelCatalog = LiveModelCatalogService(apiClient: apiClient, bundle: .module)
    let generationService = LiveGenerationService(
        apiClient: apiClient,
        modelCatalogService: modelCatalog,
        assetStore: ComposerTestAssetStore()
    )

    return AppState(
        generationService: generationService,
        oauthService: ComposerTestOAuthService(),
        credentialStore: ComposerTestCredentialStore(),
        imageExportService: ComposerTestImageExportService(),
        historyStore: ComposerTestHistoryStore()
    )
}

private func makeTestCatalogEntry(
    id: String,
    displayName: String,
    imageOptionSupport: ImageOptionSupport
) -> ModelCatalogEntry {
    ModelCatalogEntry(
        id: id,
        displayName: displayName,
        description: "",
        modalitySignature: "text->image",
        outputModalities: ["image"],
        inputModalities: ["text"],
        pricePerImage: nil,
        pricePerImageRaw: nil,
        priceDisplayOverride: nil,
        imageCapabilityProfile: .imageOnly,
        supportsImageInput: false,
        supportsImageConfig: true,
        supportedParameters: [],
        imageOptionSupport: imageOptionSupport,
        supportsAdvancedImageOptions: imageOptionSupport.supportsAdvancedImageOptions,
        popularityRank: nil
    )
}

final class ComposerExperienceTests: XCTestCase {
    @MainActor
    func testDefaultCreateExperienceModeIsFocusHero() {
        let appState = makeComposerTestAppState()

        XCTAssertEqual(appState.createExperienceMode, .focusHero)
        XCTAssertTrue(appState.shouldUseFocusHero)
    }

    @MainActor
    func testComposerCanSubmitPromptRespectsPromptAndBusyState() {
        let appState = makeComposerTestAppState()
        appState.prompt = ""

        XCTAssertFalse(appState.canSubmitPrompt)

        appState.prompt = "A test prompt"
        XCTAssertTrue(appState.canSubmitPrompt)

        let job = GenerationJob(mode: .textToImage, prompt: "A test prompt", modelID: "bytedance-seed/seedream-4.5")
        appState.lastSubmittedJobID = job.id
        appState.queueSnapshot = QueueSnapshot(
            running: GenerationQueueItem(job: job, status: .running),
            queued: [],
            completed: []
        )

        XCTAssertTrue(appState.isComposerBusy)
        XCTAssertFalse(appState.canSubmitPrompt)
    }

    @MainActor
    func testComposerPhaseMapsQueueStates() {
        let appState = makeComposerTestAppState()
        let job = GenerationJob(mode: .textToImage, prompt: "A test prompt", modelID: "bytedance-seed/seedream-4.5")

        appState.lastSubmittedJobID = job.id
        appState.queueSnapshot = QueueSnapshot(running: nil, queued: [GenerationQueueItem(job: job, status: .queued)], completed: [])

        switch appState.composerPhase {
        case let .queued(position):
            XCTAssertEqual(position, 1)
        default:
            XCTFail("Expected queued composer phase")
        }

        appState.queueSnapshot = QueueSnapshot(running: GenerationQueueItem(job: job, status: .running), queued: [], completed: [])

        switch appState.composerPhase {
        case let .running(modelID, imageCount):
            XCTAssertEqual(modelID, "bytedance-seed/seedream-4.5")
            XCTAssertEqual(imageCount, 1)
        default:
            XCTFail("Expected running composer phase")
        }
    }

    @MainActor
    func testSelectModelSanitizesUnsupportedOptions() {
        let appState = makeComposerTestAppState()
        let wideSupport = ImageOptionSupport.baseline
        let constrainedSupport = ImageOptionSupport(
            allowedAspectRatios: ["1:1"],
            allowedImageSizes: ["1K"],
            minImageCount: 1,
            maxImageCount: 1,
            supportsImageCount: false,
            supportsFontInputs: false,
            supportsSuperResolutionReferences: false
        )

        appState.modelCatalog = [
            makeTestCatalogEntry(id: "model/wide", displayName: "Wide", imageOptionSupport: wideSupport),
            makeTestCatalogEntry(id: "model/constrained", displayName: "Constrained", imageOptionSupport: constrainedSupport)
        ]
        appState.selectModel("model/wide")
        appState.aspectRatio = "16:9"
        appState.imageSize = "4K"
        appState.imageCount = 4
        appState.fontInputs = [FontInput(fontURL: "https://example.com/font.ttf", text: "Aurora")]

        appState.selectModel("model/constrained")

        XCTAssertEqual(appState.aspectRatio, "1:1")
        XCTAssertEqual(appState.imageSize, "1K")
        XCTAssertEqual(appState.imageCount, 1)
        XCTAssertTrue(appState.fontInputs.isEmpty)
    }
}
