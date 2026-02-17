import AppKit
import SwiftUI

struct ImageViewerOverlayView: View {
    @Bindable var appState: AppState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var isViewerFocused: Bool

    var body: some View {
        if appState.isViewerPresented, let result = appState.currentViewerResult {
            ZStack {
                Color.black.opacity(reduceTransparency ? 0.5 : 0.68)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.closeViewer()
                    }

                VStack(alignment: .leading, spacing: 14) {
                    controls
                    mainImage
                    filmstrip(for: result)
                }
                .padding(16)
                .frame(maxWidth: 1100, maxHeight: 760)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(32)
            }
            .focusable()
            .focused($isViewerFocused)
            .onAppear {
                isViewerFocused = true
            }
            .onExitCommand {
                appState.closeViewer()
            }
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    appState.viewerPreviousImage()
                case .right:
                    appState.viewerNextImage()
                default:
                    break
                }
            }
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity)
            )
        }
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    appState.closeViewer()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Close image viewer")

                Button {
                    toggleFullScreen()
                } label: {
                    Label("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Toggle fullscreen")

                Button {
                    Task { await appState.exportCurrentViewerImage() }
                } label: {
                    Label("Save As", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Save current image")

                Spacer(minLength: 8)

                if let result = appState.currentViewerResult {
                    Text(result.modelID)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var mainImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(reduceTransparency ? 0.12 : 0.24))

            if let data = appState.currentViewerImageData,
               let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 14))
                    .padding(20)
                    .accessibilityLabel("Generated image preview")
            } else {
                ContentUnavailableView(
                    "Preview unavailable",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("Aurora couldn't decode this image for preview.")
                )
                .padding(30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .leading) {
            navigationButton(systemImage: "chevron.left", action: appState.viewerPreviousImage)
                .padding(.leading, 14)
        }
        .overlay(alignment: .trailing) {
            navigationButton(systemImage: "chevron.right", action: appState.viewerNextImage)
                .padding(.trailing, 14)
        }
    }

    private func filmstrip(for result: GenerationResult) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(result.images.enumerated()), id: \.element.id) { index, image in
                    Button {
                        appState.viewerSelectImage(index)
                    } label: {
                        thumbnail(for: image)
                    }
                    .buttonStyle(.plain)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                index == appState.viewerImageIndex
                                    ? Color.accentColor
                                    : Color.white.opacity(0.2),
                                lineWidth: index == appState.viewerImageIndex ? 2 : 1
                            )
                    }
                    .accessibilityLabel("Select image \(index + 1)")
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 82)
        .scrollIndicators(.hidden)
    }

    private func thumbnail(for image: GeneratedImage) -> some View {
        Group {
            if let data = Data(base64Encoded: image.base64Data) ?? DataURL(rawValue: image.base64Data)?.decodeData(),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.black.opacity(0.2)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 100, height: 70)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func navigationButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
    }

    private func toggleFullScreen() {
        let candidateWindow = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: \.isVisible)
        candidateWindow?.toggleFullScreen(nil)
    }
}
