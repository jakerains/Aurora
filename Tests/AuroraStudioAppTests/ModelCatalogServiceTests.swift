import Foundation
import XCTest
@testable import AuroraStudioApp

private struct MockOpenRouterAPIClient: OpenRouterAPIClient {
    var models: [OpenRouterModel]

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

final class ModelCatalogServiceTests: XCTestCase {
    func testRefreshCatalogIncludesOnlyImageModels() async throws {
        let imageModel = OpenRouterModel(
            id: "image/model",
            canonicalSlug: nil,
            name: "Image Model",
            created: nil,
            description: nil,
            contextLength: nil,
            architecture: .init(modality: "text->image", inputModalities: ["text"], outputModalities: ["image"], tokenizer: nil, instructType: nil),
            pricing: nil,
            topProvider: nil,
            supportedParameters: nil
        )

        let textModel = OpenRouterModel(
            id: "text/model",
            canonicalSlug: nil,
            name: "Text Model",
            created: nil,
            description: nil,
            contextLength: nil,
            architecture: .init(modality: "text->text", inputModalities: ["text"], outputModalities: ["text"], tokenizer: nil, instructType: nil),
            pricing: nil,
            topProvider: nil,
            supportedParameters: nil
        )

        let service = LiveModelCatalogService(
            apiClient: MockOpenRouterAPIClient(models: [imageModel, textModel]),
            bundle: .module
        )

        let catalog = try await service.refreshCatalog()

        XCTAssertTrue(catalog.contains(where: { $0.id == "image/model" }))
        XCTAssertFalse(catalog.contains(where: { $0.id == "text/model" }))

        let curatedPro = try XCTUnwrap(catalog.first(where: { $0.id == "sourceful/riverflow-v2-pro" }))
        XCTAssertTrue(curatedPro.supportsAdvancedImageOptions)
        XCTAssertTrue(curatedPro.imageOptionSupport.supportsFontInputs)

        let curatedFast = try XCTUnwrap(catalog.first(where: { $0.id == "sourceful/riverflow-v2-fast" }))
        XCTAssertEqual(curatedFast.imageOptionSupport.allowedImageSizes, ["1K", "2K"])
        XCTAssertFalse(curatedFast.imageOptionSupport.allowedImageSizes.contains("4K"))
    }
}
