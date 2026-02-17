import AppKit
import Foundation
import Observation

enum SubmissionVisualState {
    case idle
    case queued(position: Int)
    case running(modelID: String, imageCount: Int)
    case completed(result: GenerationResult)
    case failed(message: String)
    case canceled
}

enum CreateExperienceMode: String, Codable, CaseIterable, Equatable {
    case focusHero
    case workspace
}

enum ComposerPhase: Equatable {
    case hero
    case queued(position: Int)
    case running(modelID: String, imageCount: Int)
    case completed(result: GenerationResult)
    case failed(message: String)
    case canceled
}

@MainActor
@Observable
final class AppState {
    var designSystem = AppDesignSystem.cinematic
    var liquidPolicy: LiquidGlassPolicy = .systemFirstPremium
    var preferences = UserPreferences()

    var modelCatalog: [ModelCatalogEntry] = []
    var selectedModelID: String = "bytedance-seed/seedream-4.5"

    var queueSnapshot: QueueSnapshot = .empty
    var latestResults: [GenerationResult] = []
    var lastSubmittedJobID: UUID?
    var isViewerPresented: Bool = false
    var viewerResultIndex: Int?
    var viewerImageIndex: Int = 0

    var prompt: String = "Cinematic product shot of a translucent glass cube with warm rim light and dramatic studio shadows."
    var aspectRatio: String = "16:9"
    var imageSize: String = "2K"
    var imageCount: Int = 1
    var fontInputs: [FontInput] = []
    var superResolutionReferences: [String] = []

    var isOnboardingPresented = true
    var onboardingError: String?
    var globalErrorMessage: String?
    var isRefreshingModels = false

    var oauthCodeInput: String = ""
    var oauthBootstrapKeyInput: String = ""
    var oauthCallbackURLInput: String = "http://localhost:3000"
    var activeOAuthSession: OAuthAuthorizationSession?

    @ObservationIgnored private let generationService: LiveGenerationService
    @ObservationIgnored private let oauthService: OAuthService
    @ObservationIgnored private let credentialStore: CredentialStore
    @ObservationIgnored private let imageExportService: ImageExportService
    @ObservationIgnored private let historyStore: ResultHistoryStore
    @ObservationIgnored private var queueTask: Task<Void, Never>?

    init(
        generationService: LiveGenerationService,
        oauthService: OAuthService,
        credentialStore: CredentialStore,
        imageExportService: ImageExportService,
        historyStore: ResultHistoryStore
    ) {
        self.generationService = generationService
        self.oauthService = oauthService
        self.credentialStore = credentialStore
        self.imageExportService = imageExportService
        self.historyStore = historyStore
    }

    var currentViewerResult: GenerationResult? {
        guard let viewerResultIndex, latestResults.indices.contains(viewerResultIndex) else { return nil }
        return latestResults[viewerResultIndex]
    }

    var currentViewerImage: GeneratedImage? {
        guard let currentViewerResult, currentViewerResult.images.indices.contains(viewerImageIndex) else { return nil }
        return currentViewerResult.images[viewerImageIndex]
    }

    var currentViewerImageData: Data? {
        guard let currentViewerImage else { return nil }

        if let data = Data(base64Encoded: currentViewerImage.base64Data) {
            return data
        }

        return DataURL(rawValue: currentViewerImage.base64Data)?.decodeData()
    }

    var createExperienceMode: CreateExperienceMode {
        get { preferences.createExperienceMode }
        set { preferences.createExperienceMode = newValue }
    }

    var shouldUseFocusHero: Bool {
        createExperienceMode == .focusHero
    }

    var currentModelOptionSupport: ImageOptionSupport? {
        modelCatalog.first(where: { $0.id == selectedModelID })?.imageOptionSupport
    }

    var canSubmitPrompt: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isComposerBusy
    }

    var isComposerBusy: Bool {
        switch submissionVisualState {
        case .queued, .running:
            return true
        case .idle, .completed, .failed, .canceled:
            return false
        }
    }

    var composerPhase: ComposerPhase {
        switch submissionVisualState {
        case .idle:
            return .hero
        case let .queued(position):
            return .queued(position: position)
        case let .running(modelID, imageCount):
            return .running(modelID: modelID, imageCount: imageCount)
        case let .completed(result):
            return .completed(result: result)
        case let .failed(message):
            return .failed(message: message)
        case .canceled:
            return .canceled
        }
    }

    var submissionVisualState: SubmissionVisualState {
        guard let lastSubmittedJobID else { return .idle }

        if let running = queueSnapshot.running, running.id == lastSubmittedJobID {
            return .running(
                modelID: running.job.modelID,
                imageCount: max(1, running.job.imageConfig.imageCount ?? 1)
            )
        }

        if let index = queueSnapshot.queued.firstIndex(where: { $0.id == lastSubmittedJobID }) {
            return .queued(position: index + 1)
        }

        if let completed = queueSnapshot.completed.first(where: { $0.id == lastSubmittedJobID }) {
            switch completed.status {
            case .succeeded:
                if let result = completed.result {
                    return .completed(result: result)
                }
                return .failed(message: "Generation completed without image payload.")
            case .failed:
                return .failed(message: completed.errorMessage ?? "Generation failed.")
            case .canceled:
                return .canceled
            case .queued, .running:
                return .idle
            }
        }

        if let persisted = latestResults.first(where: { $0.jobID == lastSubmittedJobID }) {
            return .completed(result: persisted)
        }

        return .idle
    }

    func bootstrap() {
        startQueueObservation()
        Task { await restoreHistory() }

        do {
            _ = try credentialStore.loadUserAPIKey()
            isOnboardingPresented = false
            Task { await refreshModels() }
        } catch {
            isOnboardingPresented = true
        }
    }

    func saveManualAPIKey(_ key: String) {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onboardingError = "API key cannot be empty."
            return
        }

        do {
            try credentialStore.saveUserAPIKey(key.trimmingCharacters(in: .whitespacesAndNewlines))
            onboardingError = nil
            isOnboardingPresented = false
            Task { await refreshModels() }
        } catch {
            onboardingError = error.localizedDescription
        }
    }

    func saveOAuthBootstrapKey() {
        do {
            try credentialStore.saveOAuthBootstrapKey(oauthBootstrapKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
            onboardingError = nil
        } catch {
            onboardingError = error.localizedDescription
        }
    }

    func beginOAuth() async {
        do {
            let callbackURL = URL(string: oauthCallbackURLInput) ?? URL(string: "http://localhost:3000")!
            let session = try await oauthService.beginAuthorization(callbackURL: callbackURL)
            activeOAuthSession = session
            NSWorkspace.shared.open(session.authorizationURL)
            onboardingError = nil
        } catch {
            onboardingError = error.localizedDescription
        }
    }

    func exchangeOAuthCode() async {
        guard let activeOAuthSession else {
            onboardingError = "Start OAuth before exchanging a code."
            return
        }

        guard !oauthCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onboardingError = "Paste the authorization code first."
            return
        }

        do {
            let key = try await oauthService.exchangeAuthorizationCode(
                oauthCodeInput.trimmingCharacters(in: .whitespacesAndNewlines),
                session: activeOAuthSession
            )
            try credentialStore.saveUserAPIKey(key)
            onboardingError = nil
            isOnboardingPresented = false
            await refreshModels()
        } catch {
            onboardingError = error.localizedDescription
        }
    }

    func refreshModels() async {
        isRefreshingModels = true
        defer { isRefreshingModels = false }

        do {
            let entries = try await generationService.refreshCatalog()
            modelCatalog = entries

            if entries.contains(where: { $0.id == selectedModelID }) {
                selectModel(selectedModelID)
            } else if let firstEntryID = entries.first?.id {
                selectModel(firstEntryID)
            }
        } catch {
            globalErrorMessage = error.localizedDescription
        }
    }

    func selectModel(_ id: String) {
        guard modelCatalog.contains(where: { $0.id == id }) else { return }
        selectedModelID = id
        sanitizeComposerOptionsForSelectedModel()
    }

    func sanitizeComposerOptionsForSelectedModel() {
        guard let support = currentModelOptionSupport else { return }

        if support.supportsAspectRatio {
            if !support.allowedAspectRatios.contains(aspectRatio), let fallback = support.allowedAspectRatios.first {
                aspectRatio = fallback
            }
        } else {
            aspectRatio = ""
        }

        if support.supportsImageSize {
            if !support.allowedImageSizes.contains(imageSize), let fallback = support.allowedImageSizes.first {
                imageSize = fallback
            }
        } else {
            imageSize = ""
        }

        if support.supportsImageCount {
            imageCount = support.clampedImageCount(imageCount)
        } else {
            imageCount = 1
        }

        if support.supportsFontInputs {
            if fontInputs.count > 2 {
                fontInputs = Array(fontInputs.prefix(2))
            }
        } else {
            fontInputs.removeAll()
        }

        if support.supportsSuperResolutionReferences {
            if superResolutionReferences.count > 4 {
                superResolutionReferences = Array(superResolutionReferences.prefix(4))
            }
        } else {
            superResolutionReferences.removeAll()
        }
    }

    func enqueueGeneration() async {
        sanitizeComposerOptionsForSelectedModel()
        let optionSupport = currentModelOptionSupport ?? .baseline
        let imageConfig = ImageConfig(
            aspectRatio: optionSupport.supportsAspectRatio ? aspectRatio : nil,
            imageSize: optionSupport.supportsImageSize ? imageSize : nil,
            imageCount: optionSupport.supportsImageCount ? imageCount : nil,
            fontInputs: optionSupport.supportsFontInputs ? Array(fontInputs.prefix(2)) : [],
            superResolutionReferences: optionSupport.supportsSuperResolutionReferences ? Array(superResolutionReferences.prefix(4)) : []
        )

        let job = GenerationJob(
            mode: .textToImage,
            prompt: prompt,
            modelID: selectedModelID,
            inputs: [],
            imageConfig: imageConfig,
            uiPresentationHint: .highlightPrimaryResult
        )

        let jobID = await generationService.enqueue(job: job)
        lastSubmittedJobID = jobID
    }

    func returnToPromptComposer(clearPrompt: Bool = false) {
        lastSubmittedJobID = nil
        if clearPrompt {
            prompt = ""
        }
    }

    func cancelJob(jobID: UUID) async {
        await generationService.cancel(jobID: jobID)
    }

    func openViewer(resultIndex: Int, imageIndex: Int = 0) {
        guard latestResults.indices.contains(resultIndex) else { return }
        let result = latestResults[resultIndex]
        guard !result.images.isEmpty else { return }

        viewerResultIndex = resultIndex
        viewerImageIndex = min(max(imageIndex, 0), result.images.count - 1)
        isViewerPresented = true
    }

    func openViewer(jobID: UUID, imageIndex: Int = 0) {
        if let index = latestResults.firstIndex(where: { $0.jobID == jobID }) {
            openViewer(resultIndex: index, imageIndex: imageIndex)
            return
        }

        if let result = queueSnapshot.completed.first(where: { $0.id == jobID })?.result,
           !latestResults.contains(where: { $0.jobID == result.jobID }) {
            latestResults.insert(result, at: 0)
            openViewer(resultIndex: 0, imageIndex: imageIndex)

            Task {
                try? await historyStore.upsert(result)
            }
        }
    }

    func closeViewer() {
        isViewerPresented = false
        viewerResultIndex = nil
        viewerImageIndex = 0
    }

    func viewerNextImage() {
        guard let result = currentViewerResult else { return }
        let maxIndex = max(0, result.images.count - 1)
        viewerImageIndex = min(maxIndex, viewerImageIndex + 1)
    }

    func viewerPreviousImage() {
        guard currentViewerResult != nil else { return }
        viewerImageIndex = max(0, viewerImageIndex - 1)
    }

    func viewerSelectImage(_ index: Int) {
        guard let result = currentViewerResult, !result.images.isEmpty else { return }
        viewerImageIndex = min(max(index, 0), result.images.count - 1)
    }

    func exportCurrentViewerImage() async {
        guard let imageData = currentViewerImageData,
              let result = currentViewerResult else {
            globalErrorMessage = "No image is selected to export."
            return
        }

        let modelName = result.modelID.replacingOccurrences(of: "/", with: "-")
        let suggestedName = "aurora-\(modelName)-\(Self.exportNameDateFormatter.string(from: result.generatedAt))-\(viewerImageIndex + 1)"

        do {
            try await imageExportService.export(imageData: imageData, suggestedName: suggestedName)
        } catch {
            globalErrorMessage = error.localizedDescription
        }
    }

    private func startQueueObservation() {
        guard queueTask == nil else { return }

        queueTask = Task { [weak self] in
            guard let self else { return }
            let stream = await generationService.snapshots()

            for await snapshot in stream {
                if Task.isCancelled { break }
                self.queueSnapshot = snapshot

                if let completedResult = snapshot.completed.first?.result,
                   latestResults.first?.jobID != completedResult.jobID {
                    if let viewerResultIndex {
                        self.viewerResultIndex = viewerResultIndex + 1
                    }
                    latestResults.insert(completedResult, at: 0)

                    do {
                        try await historyStore.upsert(completedResult)
                    } catch {
                        self.globalErrorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func restoreHistory() async {
        do {
            let restored = try await historyStore.loadResults()
            if !restored.isEmpty {
                latestResults = restored
            }
        } catch {
            globalErrorMessage = error.localizedDescription
        }
    }

    private static let exportNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
