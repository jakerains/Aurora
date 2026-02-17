import AppKit
import SwiftUI

struct HistoryGalleryView: View {
    @Bindable var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 420), spacing: 16)
    ]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: appState.designSystem.spacing.md) {
                    Text("Recent Outputs")
                        .font(.largeTitle.bold())

                    if appState.latestResults.isEmpty {
                        ContentUnavailableView(
                            "No generated images yet",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Run a generation from the Create tab and your outputs will appear here.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(appState.latestResults.enumerated()), id: \.element.jobID) { resultIndex, result in
                                HistoryCard(result: result) {
                                    appState.openViewer(resultIndex: resultIndex, imageIndex: 0)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct HistoryCard: View {
    let result: GenerationResult
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                if let first = result.images.first,
                   let nsImage = imageFromBase64(first.base64Data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 12))
                }

                HStack {
                    Text(result.modelID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if result.images.count > 1 {
                        Label("\(result.images.count)", systemImage: "square.stack.3d.up")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(result.text.isEmpty ? "Generated image" : result.text)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func imageFromBase64(_ value: String) -> NSImage? {
        guard let data = Data(base64Encoded: value) else { return nil }
        return NSImage(data: data)
    }
}
