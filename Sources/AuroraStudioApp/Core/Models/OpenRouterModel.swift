import Foundation

struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Decodable, Identifiable, Hashable {
    struct Architecture: Decodable, Hashable {
        let modality: String?
        let inputModalities: [String]?
        let outputModalities: [String]?
        let tokenizer: String?
        let instructType: String?

        enum CodingKeys: String, CodingKey {
            case modality
            case inputModalities = "input_modalities"
            case outputModalities = "output_modalities"
            case tokenizer
            case instructType = "instruct_type"
        }
    }

    struct Pricing: Decodable, Hashable {
        let prompt: String?
        let completion: String?
        let request: String?
        let image: String?
    }

    struct TopProvider: Decodable, Hashable {
        let contextLength: Int?
        let maxCompletionTokens: Int?
        let isModerated: Bool?

        enum CodingKeys: String, CodingKey {
            case contextLength = "context_length"
            case maxCompletionTokens = "max_completion_tokens"
            case isModerated = "is_moderated"
        }
    }

    let id: String
    let canonicalSlug: String?
    let name: String
    let created: TimeInterval?
    let description: String?
    let contextLength: Int?
    let architecture: Architecture
    let pricing: Pricing?
    let topProvider: TopProvider?
    let supportedParameters: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case canonicalSlug = "canonical_slug"
        case name
        case created
        case description
        case contextLength = "context_length"
        case architecture
        case pricing
        case topProvider = "top_provider"
        case supportedParameters = "supported_parameters"
    }
}

enum ImageCapabilityProfile: String, Codable, CaseIterable {
    case imageOnly
    case imageAndText
    case unknown

    var defaultModalities: [String] {
        switch self {
        case .imageOnly:
            return ["image"]
        case .imageAndText, .unknown:
            return ["image", "text"]
        }
    }
}

struct ImageOptionSupport: Hashable, Codable, Sendable {
    static let defaultAspectRatios = [
        "1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9"
    ]

    static let defaultImageSizes = ["1K", "2K", "4K"]

    static let baseline = ImageOptionSupport(
        allowedAspectRatios: defaultAspectRatios,
        allowedImageSizes: defaultImageSizes,
        minImageCount: 1,
        maxImageCount: 8,
        supportsImageCount: true,
        supportsFontInputs: false,
        supportsSuperResolutionReferences: false
    )

    static let none = ImageOptionSupport(
        allowedAspectRatios: [],
        allowedImageSizes: [],
        minImageCount: 1,
        maxImageCount: 1,
        supportsImageCount: false,
        supportsFontInputs: false,
        supportsSuperResolutionReferences: false
    )

    let allowedAspectRatios: [String]
    let allowedImageSizes: [String]
    let minImageCount: Int
    let maxImageCount: Int
    let supportsImageCount: Bool
    let supportsFontInputs: Bool
    let supportsSuperResolutionReferences: Bool

    init(
        allowedAspectRatios: [String],
        allowedImageSizes: [String],
        minImageCount: Int,
        maxImageCount: Int,
        supportsImageCount: Bool,
        supportsFontInputs: Bool,
        supportsSuperResolutionReferences: Bool
    ) {
        let normalizedMin = max(1, minImageCount)
        let normalizedMax = max(normalizedMin, maxImageCount)

        self.allowedAspectRatios = Self.uniquePreservingOrder(allowedAspectRatios)
        self.allowedImageSizes = Self.uniquePreservingOrder(allowedImageSizes)
        self.minImageCount = normalizedMin
        self.maxImageCount = normalizedMax
        self.supportsImageCount = supportsImageCount
        self.supportsFontInputs = supportsFontInputs
        self.supportsSuperResolutionReferences = supportsSuperResolutionReferences
    }

    var supportsAspectRatio: Bool { !allowedAspectRatios.isEmpty }
    var supportsImageSize: Bool { !allowedImageSizes.isEmpty }
    var supportsAdvancedImageOptions: Bool { supportsFontInputs || supportsSuperResolutionReferences }
    var imageCountRange: ClosedRange<Int> { minImageCount...maxImageCount }

    func clampedImageCount(_ value: Int) -> Int {
        min(max(value, minImageCount), maxImageCount)
    }

    func applying(
        allowedAspectRatios: [String]? = nil,
        allowedImageSizes: [String]? = nil,
        minImageCount: Int? = nil,
        maxImageCount: Int? = nil,
        supportsImageCount: Bool? = nil,
        supportsFontInputs: Bool? = nil,
        supportsSuperResolutionReferences: Bool? = nil
    ) -> ImageOptionSupport {
        ImageOptionSupport(
            allowedAspectRatios: allowedAspectRatios ?? self.allowedAspectRatios,
            allowedImageSizes: allowedImageSizes ?? self.allowedImageSizes,
            minImageCount: minImageCount ?? self.minImageCount,
            maxImageCount: maxImageCount ?? self.maxImageCount,
            supportsImageCount: supportsImageCount ?? self.supportsImageCount,
            supportsFontInputs: supportsFontInputs ?? self.supportsFontInputs,
            supportsSuperResolutionReferences: supportsSuperResolutionReferences ?? self.supportsSuperResolutionReferences
        )
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var unique: [String] = []
        for value in values {
            if seen.insert(value).inserted {
                unique.append(value)
            }
        }
        return unique
    }
}

struct ModelCatalogEntry: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let description: String
    let modalitySignature: String?
    let outputModalities: [String]
    let inputModalities: [String]
    let pricePerImage: Decimal?
    let pricePerImageRaw: String?
    let priceDisplayOverride: String?
    let imageCapabilityProfile: ImageCapabilityProfile
    let supportsImageInput: Bool
    let supportsImageConfig: Bool
    let supportedParameters: [String]
    let imageOptionSupport: ImageOptionSupport
    let supportsAdvancedImageOptions: Bool
    let popularityRank: Int?

    var isPopular: Bool { popularityRank != nil }
    var supportsImageGeneration: Bool { outputModalities.contains("image") }

    var pricePerImageDisplay: String {
        if let priceDisplayOverride, !priceDisplayOverride.isEmpty {
            return priceDisplayOverride
        }
        if let pricePerImageRaw, !pricePerImageRaw.isEmpty {
            return "$\(pricePerImageRaw)"
        }
        return "Not listed"
    }
}

extension ModelCatalogEntry {
    func withPriceDisplayOverride(_ override: String?) -> ModelCatalogEntry {
        ModelCatalogEntry(
            id: id,
            displayName: displayName,
            description: description,
            modalitySignature: modalitySignature,
            outputModalities: outputModalities,
            inputModalities: inputModalities,
            pricePerImage: pricePerImage,
            pricePerImageRaw: pricePerImageRaw,
            priceDisplayOverride: override,
            imageCapabilityProfile: imageCapabilityProfile,
            supportsImageInput: supportsImageInput,
            supportsImageConfig: supportsImageConfig,
            supportedParameters: supportedParameters,
            imageOptionSupport: imageOptionSupport,
            supportsAdvancedImageOptions: supportsAdvancedImageOptions,
            popularityRank: popularityRank
        )
    }

    func withImageOptionSupport(
        _ support: ImageOptionSupport,
        supportsImageConfig: Bool? = nil
    ) -> ModelCatalogEntry {
        ModelCatalogEntry(
            id: id,
            displayName: displayName,
            description: description,
            modalitySignature: modalitySignature,
            outputModalities: outputModalities,
            inputModalities: inputModalities,
            pricePerImage: pricePerImage,
            pricePerImageRaw: pricePerImageRaw,
            priceDisplayOverride: priceDisplayOverride,
            imageCapabilityProfile: imageCapabilityProfile,
            supportsImageInput: supportsImageInput,
            supportsImageConfig: supportsImageConfig ?? self.supportsImageConfig,
            supportedParameters: supportedParameters,
            imageOptionSupport: support,
            supportsAdvancedImageOptions: support.supportsAdvancedImageOptions,
            popularityRank: popularityRank
        )
    }
}

extension OpenRouterModel {
    private func parseModalitySignature(_ modality: String?) -> (input: [String], output: [String]) {
        guard let modality, !modality.isEmpty else { return ([], []) }

        let parts = modality.split(separator: "->", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return ([], []) }

        let input = parts[0].split(separator: "+").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let output = parts[1].split(separator: "+").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        return (input, output)
    }

    var supportsImageGeneration: Bool {
        let directOutput = architecture.outputModalities ?? []
        if directOutput.contains("image") { return true }

        let parsed = parseModalitySignature(architecture.modality)
        return parsed.output.contains("image")
    }

    func asCatalogEntry(popularityRank: Int?) -> ModelCatalogEntry {
        let parsed = parseModalitySignature(architecture.modality)
        let output = Array(Set((architecture.outputModalities ?? []) + parsed.output)).sorted()
        let input = Array(Set((architecture.inputModalities ?? []) + parsed.input)).sorted()
        let normalizedSupportedParameters = Self.normalizeParameters(supportedParameters)

        let capability: ImageCapabilityProfile = {
            if output.contains("image") && output.contains("text") {
                return .imageAndText
            }
            if output.contains("image") {
                return .imageOnly
            }
            return .unknown
        }()

        let pricePerImage = pricing?.image.flatMap { Decimal(string: $0) }
        let supportsImageConfig = supportsImageGeneration
        let optionSupport: ImageOptionSupport = {
            guard supportsImageGeneration else { return .none }
            guard supportsImageConfig else {
                return ImageOptionSupport.baseline.applying(
                    allowedAspectRatios: [],
                    allowedImageSizes: [],
                    minImageCount: 1,
                    maxImageCount: 1,
                    supportsImageCount: false
                )
            }
            return .baseline
        }()

        return ModelCatalogEntry(
            id: id,
            displayName: name,
            description: description ?? "",
            modalitySignature: architecture.modality,
            outputModalities: output,
            inputModalities: input,
            pricePerImage: pricePerImage,
            pricePerImageRaw: pricing?.image,
            priceDisplayOverride: nil,
            imageCapabilityProfile: capability,
            supportsImageInput: input.contains("image"),
            supportsImageConfig: supportsImageConfig,
            supportedParameters: normalizedSupportedParameters,
            imageOptionSupport: optionSupport,
            supportsAdvancedImageOptions: optionSupport.supportsAdvancedImageOptions,
            popularityRank: popularityRank
        )
    }

    private static func normalizeParameters(_ values: [String]?) -> [String] {
        guard let values else { return [] }

        var seen: Set<String> = []
        var normalized: [String] = []

        for value in values {
            let token = value.lowercased()
            if seen.insert(token).inserted {
                normalized.append(token)
            }
        }

        return normalized
    }
}
