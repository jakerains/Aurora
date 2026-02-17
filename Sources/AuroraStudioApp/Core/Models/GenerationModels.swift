import Foundation

enum GenerationMode: String, Codable, CaseIterable, Identifiable {
    case textToImage
    case imageToImage
    case inpaint
    case variations
    case upscale

    var id: String { rawValue }

    var label: String {
        switch self {
        case .textToImage: return "Text to Image"
        case .imageToImage: return "Image to Image"
        case .inpaint: return "Inpaint"
        case .variations: return "Variations"
        case .upscale: return "Upscale"
        }
    }
}

enum GenerationUIPresentationHint: String, Codable, CaseIterable {
    case neutral
    case morphFromPrevious
    case highlightPrimaryResult
    case expandedInspector
}

enum GenerationJobStatus: String, Codable, CaseIterable {
    case queued
    case running
    case succeeded
    case failed
    case canceled
}

struct GenerationInputAsset: Codable, Hashable, Identifiable, Sendable {
    enum Role: String, Codable {
        case source
        case mask
        case reference
    }

    let id: UUID
    let role: Role
    let mimeType: String
    let dataURL: String

    init(id: UUID = UUID(), role: Role, mimeType: String, dataURL: String) {
        self.id = id
        self.role = role
        self.mimeType = mimeType
        self.dataURL = dataURL
    }
}

struct FontInput: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var fontURL: String
    var text: String

    init(id: UUID = UUID(), fontURL: String, text: String) {
        self.id = id
        self.fontURL = fontURL
        self.text = text
    }

    var payloadObject: [String: JSONValue]? {
        let trimmedFontURL = fontURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFontURL.isEmpty, !trimmedText.isEmpty else { return nil }

        return [
            "font_url": .string(trimmedFontURL),
            "text": .string(trimmedText)
        ]
    }
}

struct ImageConfig: Codable, Hashable, Sendable {
    var aspectRatio: String?
    var imageSize: String?
    var imageCount: Int?
    var fontInputs: [FontInput]
    var superResolutionReferences: [String]
    var additional: [String: JSONValue]

    init(
        aspectRatio: String? = nil,
        imageSize: String? = nil,
        imageCount: Int? = nil,
        fontInputs: [FontInput] = [],
        superResolutionReferences: [String] = [],
        additional: [String: JSONValue] = [:]
    ) {
        self.aspectRatio = aspectRatio
        self.imageSize = imageSize
        self.imageCount = imageCount
        self.fontInputs = fontInputs
        self.superResolutionReferences = superResolutionReferences
        self.additional = additional
    }

    var payload: [String: JSONValue] {
        var data = additional

        if let aspectRatio {
            data["aspect_ratio"] = .string(aspectRatio)
        }

        if let imageSize {
            data["image_size"] = .string(imageSize)
        }

        if let imageCount {
            data["n"] = .number(Double(max(imageCount, 1)))
        }

        let validFontInputs = fontInputs.compactMap(\.payloadObject)
        if !validFontInputs.isEmpty {
            data["font_inputs"] = .array(validFontInputs.map(JSONValue.object))
        }

        let validReferences = superResolutionReferences
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !validReferences.isEmpty {
            data["super_resolution_references"] = .array(validReferences.map(JSONValue.string))
        }

        return data
    }
}

struct GenerationJob: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    var projectID: UUID?
    var mode: GenerationMode
    var prompt: String
    var modelID: String
    var inputs: [GenerationInputAsset]
    var imageConfig: ImageConfig
    var uiPresentationHint: GenerationUIPresentationHint
    var status: GenerationJobStatus

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        projectID: UUID? = nil,
        mode: GenerationMode,
        prompt: String,
        modelID: String,
        inputs: [GenerationInputAsset] = [],
        imageConfig: ImageConfig = ImageConfig(),
        uiPresentationHint: GenerationUIPresentationHint = .neutral,
        status: GenerationJobStatus = .queued
    ) {
        self.id = id
        self.createdAt = createdAt
        self.projectID = projectID
        self.mode = mode
        self.prompt = prompt
        self.modelID = modelID
        self.inputs = inputs
        self.imageConfig = imageConfig
        self.uiPresentationHint = uiPresentationHint
        self.status = status
    }
}

struct GenerationResult: Codable, Hashable, Sendable {
    let jobID: UUID
    let modelID: String
    let generatedAt: Date
    let text: String
    let images: [GeneratedImage]
    let storedAssets: [EncryptedAssetRef]
}

struct GeneratedImage: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let mimeType: String
    let base64Data: String

    init(id: UUID = UUID(), mimeType: String, base64Data: String) {
        self.id = id
        self.mimeType = mimeType
        self.base64Data = base64Data
    }
}
