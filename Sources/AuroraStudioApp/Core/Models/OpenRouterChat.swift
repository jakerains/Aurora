import Foundation

struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: MessageContent
    }

    enum MessageContent: Encodable {
        case text(String)
        case parts([ContentPart])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .text(value):
                try container.encode(value)
            case let .parts(parts):
                try container.encode(parts)
            }
        }
    }

    struct ContentPart: Encodable {
        struct ImageURL: Encodable {
            let url: String

            enum CodingKeys: String, CodingKey {
                case url
            }
        }

        let type: String
        let text: String?
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }

        static func text(_ text: String) -> ContentPart {
            ContentPart(type: "text", text: text, imageURL: nil)
        }

        static func image(_ dataURL: String) -> ContentPart {
            ContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: dataURL))
        }
    }

    let model: String
    let messages: [Message]
    let modalities: [String]
    let stream: Bool
    let imageConfig: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case modalities
        case stream
        case imageConfig = "image_config"
    }
}

struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        let message: AssistantMessage
    }

    struct AssistantMessage: Decodable {
        struct ImagePayload: Decodable {
            struct ImageURLPayload: Decodable {
                let url: String
            }

            let type: String?
            let imageURL: ImageURLPayload

            enum CodingKeys: String, CodingKey {
                case type
                case imageURL = "image_url"
            }
        }

        let role: String?
        let content: String?
        let images: [ImagePayload]?
    }

    let id: String?
    let choices: [Choice]
}

extension ChatCompletionsRequest {
    static func from(
        job: GenerationJob,
        profile: ImageCapabilityProfile,
        modelEntry: ModelCatalogEntry?
    ) -> ChatCompletionsRequest {
        var parts: [ContentPart] = [.text(job.prompt)]

        for input in job.inputs {
            parts.append(.image(input.dataURL))
        }

        let filteredImageConfig = filteredImageConfig(from: job.imageConfig, for: modelEntry)

        return ChatCompletionsRequest(
            model: job.modelID,
            messages: [
                Message(role: "user", content: .parts(parts))
            ],
            modalities: profile.defaultModalities,
            stream: false,
            imageConfig: filteredImageConfig.isEmpty ? nil : filteredImageConfig
        )
    }

    private static func filteredImageConfig(
        from imageConfig: ImageConfig,
        for modelEntry: ModelCatalogEntry?
    ) -> [String: JSONValue] {
        guard let modelEntry else { return imageConfig.payload }
        guard modelEntry.supportsImageConfig else { return [:] }

        let support = modelEntry.imageOptionSupport
        var payload: [String: JSONValue] = [:]

        if support.supportsAspectRatio,
           let aspectRatio = imageConfig.aspectRatio,
           support.allowedAspectRatios.contains(aspectRatio) {
            payload["aspect_ratio"] = .string(aspectRatio)
        }

        if support.supportsImageSize,
           let imageSize = imageConfig.imageSize,
           support.allowedImageSizes.contains(imageSize) {
            payload["image_size"] = .string(imageSize)
        }

        if support.supportsImageCount,
           let imageCount = imageConfig.imageCount {
            payload["n"] = .number(Double(support.clampedImageCount(imageCount)))
        }

        if support.supportsFontInputs {
            let fontPayloads = imageConfig.fontInputs
                .prefix(2)
                .compactMap(\.payloadObject)
                .map(JSONValue.object)

            if !fontPayloads.isEmpty {
                payload["font_inputs"] = .array(fontPayloads)
            }
        }

        if support.supportsSuperResolutionReferences {
            let references = imageConfig.superResolutionReferences
                .prefix(4)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map(JSONValue.string)

            if !references.isEmpty {
                payload["super_resolution_references"] = .array(references)
            }
        }

        for (key, value) in imageConfig.additional where payload[key] == nil {
            payload[key] = value
        }

        return payload
    }
}
