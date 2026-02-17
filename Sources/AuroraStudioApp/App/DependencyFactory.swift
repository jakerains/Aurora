import Foundation

enum DependencyFactory {
    @MainActor
    static func makeAppState() -> AppState {
        let credentialStore = KeychainCredentialStore()

        let userClient = LiveOpenRouterAPIClient {
            try credentialStore.loadUserAPIKey()
        }

        let oauthBootstrapClient = LiveOpenRouterAPIClient {
            try credentialStore.loadOAuthBootstrapKey()
        }

        let catalogService = LiveModelCatalogService(apiClient: userClient)
        let assetStore: AssetStore

        do {
            assetStore = try EncryptedFileAssetStore()
        } catch {
            fatalError("Unable to initialize encrypted asset storage: \(error.localizedDescription)")
        }

        let generationService = LiveGenerationService(
            apiClient: userClient,
            modelCatalogService: catalogService,
            assetStore: assetStore
        )

        let oauthService = LiveOAuthService(apiClient: oauthBootstrapClient)
        let imageExportService = LiveImageExportService()
        let historyStore: ResultHistoryStore

        do {
            historyStore = try FileResultHistoryStore(assetStore: assetStore)
        } catch {
            fatalError("Unable to initialize history store: \(error.localizedDescription)")
        }

        return AppState(
            generationService: generationService,
            oauthService: oauthService,
            credentialStore: credentialStore,
            imageExportService: imageExportService,
            historyStore: historyStore
        )
    }
}
