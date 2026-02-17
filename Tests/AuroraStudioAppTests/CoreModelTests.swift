import XCTest
@testable import AuroraStudioApp

final class CoreModelTests: XCTestCase {
    func testDataURLRoundTrip() {
        let raw = "data:image/png;base64,aGVsbG8="
        let parsed = DataURL(rawValue: raw)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.mimeType, "image/png")
        XCTAssertEqual(parsed?.base64Data, "aGVsbG8=")
        XCTAssertEqual(parsed?.decodeData(), Data("hello".utf8))
    }

    func testImageCapabilityMapping() {
        let model = OpenRouterModel(
            id: "openai/gpt-5-image",
            canonicalSlug: "openai/gpt-5-image",
            name: "GPT-5 Image",
            created: nil,
            description: "High quality image model",
            contextLength: 8192,
            architecture: .init(
                modality: "text+image->text+image",
                inputModalities: ["text", "image"],
                outputModalities: ["image", "text"],
                tokenizer: "GPT",
                instructType: nil
            ),
            pricing: .init(prompt: "0.0", completion: "0.0", request: "0", image: "0.01"),
            topProvider: nil,
            supportedParameters: ["temperature", "top_p", "modalities"]
        )

        let entry = model.asCatalogEntry(popularityRank: 1)

        XCTAssertEqual(entry.imageCapabilityProfile, .imageAndText)
        XCTAssertTrue(entry.supportsImageInput)
        XCTAssertTrue(entry.supportsImageConfig)
        XCTAssertEqual(entry.supportedParameters, ["temperature", "top_p", "modalities"])
        XCTAssertEqual(entry.popularityRank, 1)
    }

    func testImageCapabilityFallbackFromModalitySignature() {
        let model = OpenRouterModel(
            id: "vendor/new-image-model",
            canonicalSlug: nil,
            name: "New Image Model",
            created: nil,
            description: nil,
            contextLength: nil,
            architecture: .init(
                modality: "text+image->image",
                inputModalities: nil,
                outputModalities: nil,
                tokenizer: nil,
                instructType: nil
            ),
            pricing: .init(prompt: nil, completion: nil, request: nil, image: "0.01"),
            topProvider: nil,
            supportedParameters: nil
        )

        XCTAssertTrue(model.supportsImageGeneration)
        let entry = model.asCatalogEntry(popularityRank: nil)
        XCTAssertEqual(entry.outputModalities, ["image"])
        XCTAssertEqual(entry.inputModalities.sorted(), ["image", "text"])
        XCTAssertEqual(entry.pricePerImageDisplay, "$0.01")
        XCTAssertEqual(entry.imageOptionSupport.allowedImageSizes, ["1K", "2K", "4K"])
        XCTAssertTrue(entry.imageOptionSupport.supportsImageCount)
    }

    func testImageConfigIncludesImageCount() {
        let config = ImageConfig(aspectRatio: "1:1", imageSize: "2K", imageCount: 3)
        let payload = config.payload

        XCTAssertEqual(payload["aspect_ratio"], .string("1:1"))
        XCTAssertEqual(payload["image_size"], .string("2K"))
        XCTAssertEqual(payload["n"], .number(3))
    }

    func testImageConfigIncludesAdvancedTypedOptions() {
        let config = ImageConfig(
            fontInputs: [
                FontInput(fontURL: "https://example.com/font1.ttf", text: "Aurora"),
                FontInput(fontURL: "https://example.com/font2.ttf", text: "Studio")
            ],
            superResolutionReferences: [
                "https://example.com/ref-a.jpg",
                "https://example.com/ref-b.jpg"
            ]
        )

        let payload = config.payload

        XCTAssertEqual(
            payload["font_inputs"],
            .array([
                .object([
                    "font_url": .string("https://example.com/font1.ttf"),
                    "text": .string("Aurora")
                ]),
                .object([
                    "font_url": .string("https://example.com/font2.ttf"),
                    "text": .string("Studio")
                ])
            ])
        )
        XCTAssertEqual(
            payload["super_resolution_references"],
            .array([
                .string("https://example.com/ref-a.jpg"),
                .string("https://example.com/ref-b.jpg")
            ])
        )
    }

    func testChatRequestFiltersUnsupportedImageOptions() {
        let support = ImageOptionSupport(
            allowedAspectRatios: ["1:1"],
            allowedImageSizes: ["1K"],
            minImageCount: 1,
            maxImageCount: 1,
            supportsImageCount: false,
            supportsFontInputs: false,
            supportsSuperResolutionReferences: false
        )
        let modelEntry = makeCatalogEntry(id: "model/limited", support: support)

        let job = GenerationJob(
            mode: .textToImage,
            prompt: "Test prompt",
            modelID: "model/limited",
            imageConfig: ImageConfig(
                aspectRatio: "16:9",
                imageSize: "4K",
                imageCount: 4,
                fontInputs: [FontInput(fontURL: "https://example.com/font.ttf", text: "Hello")]
            )
        )

        let request = ChatCompletionsRequest.from(job: job, profile: .imageOnly, modelEntry: modelEntry)
        XCTAssertNil(request.imageConfig)
    }

    func testChatRequestKeepsSupportedImageOptions() throws {
        let support = ImageOptionSupport(
            allowedAspectRatios: ["16:9", "1:1"],
            allowedImageSizes: ["1K", "2K"],
            minImageCount: 1,
            maxImageCount: 4,
            supportsImageCount: true,
            supportsFontInputs: true,
            supportsSuperResolutionReferences: false
        )
        let modelEntry = makeCatalogEntry(id: "sourceful/riverflow-v2-pro", support: support)

        let job = GenerationJob(
            mode: .textToImage,
            prompt: "Test prompt",
            modelID: "sourceful/riverflow-v2-pro",
            imageConfig: ImageConfig(
                aspectRatio: "16:9",
                imageSize: "2K",
                imageCount: 7,
                fontInputs: [
                    FontInput(fontURL: "https://example.com/font.ttf", text: "Hello")
                ]
            )
        )

        let request = ChatCompletionsRequest.from(job: job, profile: .imageOnly, modelEntry: modelEntry)
        let imageConfig = try XCTUnwrap(request.imageConfig)

        XCTAssertEqual(imageConfig["aspect_ratio"], .string("16:9"))
        XCTAssertEqual(imageConfig["image_size"], .string("2K"))
        XCTAssertEqual(imageConfig["n"], .number(4))
        XCTAssertEqual(
            imageConfig["font_inputs"],
            .array([
                .object([
                    "font_url": .string("https://example.com/font.ttf"),
                    "text": .string("Hello")
                ])
            ])
        )
    }

    private func makeCatalogEntry(id: String, support: ImageOptionSupport) -> ModelCatalogEntry {
        ModelCatalogEntry(
            id: id,
            displayName: id,
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
            imageOptionSupport: support,
            supportsAdvancedImageOptions: support.supportsAdvancedImageOptions,
            popularityRank: nil
        )
    }
}
