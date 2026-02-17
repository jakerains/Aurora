import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ExportImageFormat: String, CaseIterable, Identifiable {
    case png
    case jpeg
    case webp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        }
    }

    var utType: UTType {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .webp:
            return .webP
        }
    }

    var bitmapType: NSBitmapImageRep.FileType? {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .webp:
            return nil
        }
    }
}

protocol ImageExportService: Sendable {
    @MainActor
    func export(imageData: Data, suggestedName: String) async throws
}

@MainActor
final class LiveImageExportService: ImageExportService {
    func export(imageData: Data, suggestedName: String) async throws {
        guard let image = NSImage(data: imageData) else {
            throw AppError.decodingFailure("Unable to decode image payload for export.")
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.prompt = "Save"

        let accessory = ExportAccessoryView()
        panel.accessoryView = accessory
        panel.allowedContentTypes = [accessory.selectedFormat.utType]
        panel.nameFieldStringValue = "\(suggestedName).\(accessory.selectedFormat.fileExtension)"

        accessory.onFormatChange = { [weak panel] format in
            guard let panel else { return }
            panel.allowedContentTypes = [format.utType]
            panel.nameFieldStringValue = Self.replaceExtension(
                in: panel.nameFieldStringValue,
                with: format.fileExtension
            )
        }

        let response = await panel.begin()
        guard response == .OK, let selectedURL = panel.url else { return }

        let format = accessory.selectedFormat
        let destinationURL = Self.ensureExtension(on: selectedURL, for: format)
        let outputData = try encode(image: image, as: format, jpegQuality: accessory.jpegQuality)

        do {
            try outputData.write(to: destinationURL, options: .atomic)
        } catch {
            throw AppError.storageFailure("Unable to save exported image: \(error.localizedDescription)")
        }
    }

    private func encode(image: NSImage, as format: ExportImageFormat, jpegQuality: Double) throws -> Data {
        switch format {
        case .png, .jpeg:
            return try encodeBitmap(image: image, as: format, jpegQuality: jpegQuality)
        case .webp:
            return try encodeWebP(image: image, jpegQuality: jpegQuality)
        }
    }

    private func encodeBitmap(image: NSImage, as format: ExportImageFormat, jpegQuality: Double) throws -> Data {
        guard let fileType = format.bitmapType else {
            throw AppError.encodingFailure("Unsupported bitmap export type.")
        }

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            throw AppError.decodingFailure("Unable to create bitmap image for export.")
        }

        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpeg {
            properties[.compressionFactor] = max(0.0, min(jpegQuality, 1.0))
        }

        guard let output = bitmap.representation(using: fileType, properties: properties) else {
            throw AppError.encodingFailure("Unable to encode \(format.displayName) image.")
        }

        return output
    }

    private func encodeWebP(image: NSImage, jpegQuality: Double) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AppError.decodingFailure("Unable to rasterize image for WebP export.")
        }

        let supportedTypes = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        guard supportedTypes.contains(UTType.webP.identifier) else {
            throw AppError.storageFailure("WebP export is not supported on this macOS runtime.")
        }

        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data,
                UTType.webP.identifier as CFString,
                1,
                nil
            )
        else {
            throw AppError.encodingFailure("Unable to initialize WebP export destination.")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.0, min(jpegQuality, 1.0))
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw AppError.encodingFailure("Unable to finalize WebP export.")
        }

        return data as Data
    }

    private static func ensureExtension(on url: URL, for format: ExportImageFormat) -> URL {
        if url.pathExtension.lowercased() == format.fileExtension {
            return url
        }

        let baseURL = url.deletingPathExtension()
        return baseURL.appendingPathExtension(format.fileExtension)
    }

    private static func replaceExtension(in fileName: String, with newExtension: String) -> String {
        let url = URL(fileURLWithPath: fileName)
        return url.deletingPathExtension().lastPathComponent + "." + newExtension
    }
}

private final class ExportAccessoryView: NSView {
    var onFormatChange: ((ExportImageFormat) -> Void)?

    private let formatPopup = NSPopUpButton()
    private let qualitySlider = NSSlider(value: 0.92, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let qualityValueLabel = NSTextField(labelWithString: "92%")

    var selectedFormat: ExportImageFormat {
        guard let title = formatPopup.selectedItem?.title else { return .png }
        return ExportImageFormat.allCases.first(where: { $0.displayName == title }) ?? .png
    }

    var jpegQuality: Double {
        qualitySlider.doubleValue
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false

        let formatLabel = NSTextField(labelWithString: "Format:")
        formatLabel.alignment = .right

        let qualityLabel = NSTextField(labelWithString: "JPEG Quality:")
        qualityLabel.alignment = .right

        formatPopup.addItems(withTitles: ExportImageFormat.allCases.map(\.displayName))
        formatPopup.selectItem(withTitle: ExportImageFormat.png.displayName)
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)

        qualitySlider.target = self
        qualitySlider.action = #selector(qualityChanged)
        qualitySlider.isContinuous = true

        let qualityRow = NSStackView(views: [qualitySlider, qualityValueLabel])
        qualityRow.orientation = .horizontal
        qualityRow.spacing = 8
        qualityRow.alignment = .centerY

        let grid = NSGridView(views: [
            [formatLabel, formatPopup],
            [qualityLabel, qualityRow]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 12

        addSubview(grid)

        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor),
            grid.topAnchor.constraint(equalTo: topAnchor),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 320)
        ])

        updateQualityVisibility()
    }

    @objc
    private func formatChanged() {
        updateQualityVisibility()
        onFormatChange?(selectedFormat)
    }

    @objc
    private func qualityChanged() {
        let value = Int((qualitySlider.doubleValue * 100).rounded())
        qualityValueLabel.stringValue = "\(value)%"
    }

    private func updateQualityVisibility() {
        let showQuality = selectedFormat == .jpeg || selectedFormat == .webp
        qualitySlider.isEnabled = showQuality
        qualitySlider.alphaValue = showQuality ? 1.0 : 0.45
        qualityValueLabel.alphaValue = showQuality ? 1.0 : 0.45
    }
}
