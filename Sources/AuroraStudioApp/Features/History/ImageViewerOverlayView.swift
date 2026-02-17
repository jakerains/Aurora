import AppKit
import SwiftUI

struct ImageViewerOverlayView: View {
    @Bindable var appState: AppState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var isViewerFocused: Bool
    @State private var shareAnchorView: NSView?

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
            .background(
                ShareAnchorView(anchorView: $shareAnchorView)
                    .frame(width: 0, height: 0)
            )
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

                Button {
                    copyCurrentImage()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Copy current image")
                .disabled(currentViewerNSImage == nil)

                Button {
                    shareCurrentImage()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Share current image")
                .disabled(currentViewerNSImage == nil)

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

            if let image = currentViewerNSImage {
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
        .contextMenu {
            Button {
                copyCurrentImage()
            } label: {
                Label("Copy Image", systemImage: "doc.on.doc")
            }
            .disabled(currentViewerNSImage == nil)

            Button {
                shareCurrentImage()
            } label: {
                Label("Share Image", systemImage: "square.and.arrow.up")
            }
            .disabled(currentViewerNSImage == nil)

            Button {
                Task { await appState.exportCurrentViewerImage() }
            } label: {
                Label("Save As…", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func filmstrip(for result: GenerationResult) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(result.images.enumerated()), id: \.element.id) { index, image in
                    let nsImage = decodedImage(from: image)
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
                    .contextMenu {
                        Button {
                            appState.viewerSelectImage(index)
                            copyImage(nsImage)
                        } label: {
                            Label("Copy Image", systemImage: "doc.on.doc")
                        }
                        .disabled(nsImage == nil)

                        Button {
                            appState.viewerSelectImage(index)
                            shareImage(nsImage)
                        } label: {
                            Label("Share Image", systemImage: "square.and.arrow.up")
                        }
                        .disabled(nsImage == nil)
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
        let nsImage = decodedImage(from: image)
        return Group {
            if let nsImage {
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

    private var currentViewerNSImage: NSImage? {
        guard let image = appState.currentViewerImage else { return nil }
        return decodedImage(from: image)
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

    private func decodedImage(from image: GeneratedImage) -> NSImage? {
        if let data = Data(base64Encoded: image.base64Data) {
            return NSImage(data: data)
        }
        if let data = DataURL(rawValue: image.base64Data)?.decodeData() {
            return NSImage(data: data)
        }
        return nil
    }

    private func copyCurrentImage() {
        copyImage(currentViewerNSImage)
    }

    private func copyImage(_ image: NSImage?) {
        guard let image else {
            appState.globalErrorMessage = "No image available to copy."
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didWrite = pasteboard.writeObjects([image])
        if !didWrite {
            appState.globalErrorMessage = "Unable to copy image to clipboard."
        }
    }

    private func shareCurrentImage() {
        shareImage(currentViewerNSImage)
    }

    private func shareImage(_ image: NSImage?) {
        guard let image else {
            appState.globalErrorMessage = "No image available to share."
            return
        }
        guard let anchorView = NSApp.keyWindow?.contentView ?? shareAnchorView else {
            appState.globalErrorMessage = "Unable to open share sheet."
            return
        }

        let picker = NSSharingServicePicker(items: [image])
        let sourceRect = NSRect(
            x: anchorView.bounds.midX,
            y: anchorView.bounds.midY,
            width: 1,
            height: 1
        )
        picker.show(
            relativeTo: sourceRect,
            of: anchorView,
            preferredEdge: .minY
        )
    }
}

private struct ShareAnchorView: NSViewRepresentable {
    @Binding var anchorView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            anchorView = view
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if anchorView !== nsView {
            DispatchQueue.main.async {
                anchorView = nsView
            }
        }
    }
}
