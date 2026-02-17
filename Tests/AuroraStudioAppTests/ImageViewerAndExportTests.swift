import Foundation
import XCTest
@testable import AuroraStudioApp

private struct TestOpenRouterAPIClient: OpenRouterAPIClient {
    var models: [OpenRouterModel] = []

    func fetchModels() async throws -> [OpenRouterModel] {
        models
    }

    func fetchUserModels() async throws -> [OpenRouterModel] {
        models
    }

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

private actor TestAssetStore: AssetStore {
    func save(assetData: Data, metadata: AssetMetadata) async throws -> EncryptedAssetRef {
        EncryptedAssetRef(
            id: UUID(),
            encryptedPath: "/tmp/mock",
            checksum: "mock",
            metadata: metadata
        )
    }

    func load(ref: EncryptedAssetRef) async throws -> Data {
        Data()
    }
}

private actor TestOAuthService: OAuthService {
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

private struct TestCredentialStore: CredentialStore {
    func loadUserAPIKey() throws -> String { "mock-key" }
    func saveUserAPIKey(_ key: String) throws {}
    func clearUserAPIKey() {}
    func loadOAuthBootstrapKey() throws -> String { "mock-bootstrap" }
    func saveOAuthBootstrapKey(_ key: String) throws {}
}

@MainActor
private final class TestImageExportService: ImageExportService {
    func export(imageData: Data, suggestedName: String) async throws {}
}

private actor TestHistoryStore: ResultHistoryStore {
    func loadResults() async throws -> [GenerationResult] { [] }
    func upsert(_ result: GenerationResult) async throws {}
}

@MainActor
private func makeAppStateForViewerTests() -> AppState {
    let apiClient = TestOpenRouterAPIClient()
    let modelCatalog = LiveModelCatalogService(apiClient: apiClient, bundle: .module)
    let generationService = LiveGenerationService(
        apiClient: apiClient,
        modelCatalogService: modelCatalog,
        assetStore: TestAssetStore()
    )

    return AppState(
        generationService: generationService,
        oauthService: TestOAuthService(),
        credentialStore: TestCredentialStore(),
        imageExportService: TestImageExportService(),
        historyStore: TestHistoryStore()
    )
}

final class ImageViewerAndExportTests: XCTestCase {
    @MainActor
    func testAppStateViewerNavigationClampsAtBounds() {
        let appState = makeAppStateForViewerTests()
        appState.latestResults = [mockResult(imageBase64: ["aGVsbG8=", "d29ybGQ=", "dGVzdA=="])]

        appState.openViewer(resultIndex: 0, imageIndex: 99)
        XCTAssertTrue(appState.isViewerPresented)
        XCTAssertEqual(appState.viewerImageIndex, 2)

        appState.viewerNextImage()
        XCTAssertEqual(appState.viewerImageIndex, 2)

        appState.viewerPreviousImage()
        XCTAssertEqual(appState.viewerImageIndex, 1)

        appState.viewerSelectImage(-10)
        XCTAssertEqual(appState.viewerImageIndex, 0)

        appState.closeViewer()
        XCTAssertFalse(appState.isViewerPresented)
        XCTAssertNil(appState.viewerResultIndex)
    }

    @MainActor
    func testAppStateViewerIgnoresEmptyOrInvalidSelections() {
        let appState = makeAppStateForViewerTests()
        appState.latestResults = [
            GenerationResult(
                jobID: UUID(),
                modelID: "openai/gpt-5-image",
                generatedAt: .now,
                text: "",
                images: [],
                storedAssets: []
            )
        ]

        appState.openViewer(resultIndex: 0, imageIndex: 0)
        XCTAssertFalse(appState.isViewerPresented)

        appState.openViewer(resultIndex: 8, imageIndex: 0)
        XCTAssertFalse(appState.isViewerPresented)
    }

    @MainActor
    func testCurrentViewerImageDataDecodesValidBase64() {
        let appState = makeAppStateForViewerTests()
        appState.latestResults = [mockResult(imageBase64: ["aGVsbG8="])]

        appState.openViewer(resultIndex: 0, imageIndex: 0)
        XCTAssertEqual(appState.currentViewerImageData, Data("hello".utf8))

        appState.latestResults = [mockResult(imageBase64: ["%%%invalid%%%"])]
        appState.openViewer(resultIndex: 0, imageIndex: 0)
        XCTAssertNil(appState.currentViewerImageData)
    }

    @MainActor
    func testOpenViewerByJobIDFindsExistingResult() {
        let appState = makeAppStateForViewerTests()
        let result = mockResult(imageBase64: ["aGVsbG8=", "d29ybGQ="])
        appState.latestResults = [result]

        appState.openViewer(jobID: result.jobID, imageIndex: 1)

        XCTAssertTrue(appState.isViewerPresented)
        XCTAssertEqual(appState.viewerResultIndex, 0)
        XCTAssertEqual(appState.viewerImageIndex, 1)
    }

    func testExportImageFormatMappingsAreStable() {
        XCTAssertEqual(ExportImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ExportImageFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ExportImageFormat.webp.fileExtension, "webp")

        XCTAssertNotNil(ExportImageFormat.png.bitmapType)
        XCTAssertNotNil(ExportImageFormat.jpeg.bitmapType)
        XCTAssertNil(ExportImageFormat.webp.bitmapType)

        XCTAssertEqual(ExportImageFormat.png.utType.preferredFilenameExtension, "png")
        XCTAssertEqual(ExportImageFormat.webp.utType.preferredFilenameExtension, "webp")
    }

    private func mockResult(imageBase64: [String]) -> GenerationResult {
        GenerationResult(
            jobID: UUID(),
            modelID: "openai/gpt-5-image",
            generatedAt: .now,
            text: "result",
            images: imageBase64.map { GeneratedImage(mimeType: "image/png", base64Data: $0) },
            storedAssets: []
        )
    }
}
