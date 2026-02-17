import AppKit
import SwiftUI

private enum ComposerGlassSlot {
    static let heroPromptCard = 0
    static let heroAccessories = 1
    static let generationStage = 2
    static let generationStatusBadge = 3
    static let resultActionChip = 4
}

struct ComposerView: View {
    @Bindable var appState: AppState
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isPromptFocused: Bool
    @State private var isAdvancedPopoverPresented = false

    private let starterPrompts = [
        "Cinematic product hero shot with dramatic rim light and reflective floor",
        "Editorial portrait with soft diffusion, vivid color grading, and crisp detail",
        "Futuristic city at dusk, volumetric fog, neon accents, ultra-realistic style",
        "Luxury brand campaign image, premium lighting, centered composition"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: appState.designSystem.spacing.xl) {
                heroIntro
                phaseSurface
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 34)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: appState.queueSnapshot.running?.id)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: appState.queueSnapshot.queued.count)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: appState.queueSnapshot.completed.count)
        .onAppear {
            isPromptFocused = true
        }
        .onChange(of: appState.composerPhase) { _, newValue in
            if case .hero = newValue {
                isPromptFocused = true
            }
        }
        .onChange(of: appState.selectedModelID) { _, _ in
            isAdvancedPopoverPresented = false
        }
    }

    private var heroIntro: some View {
        VStack(spacing: 10) {
            Text("Aurora Studio")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: .capsule)

            Text("What will you create today?")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, appState.designSystem.colors.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Start with a clear prompt, then watch Aurora render in real time.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 980)
    }

    @ViewBuilder
    private var phaseSurface: some View {
        switch appState.composerPhase {
        case .hero:
            heroPromptSurface
        case let .queued(position):
            generationStageSurface {
                GenerationQueuedSurface(position: position)
            }
        case let .running(modelID, imageCount):
            let statusBadgeGlass = shouldUseCustomGlass(surface: .generationStatusBadge, slot: ComposerGlassSlot.generationStatusBadge)
                ? glassStyle(for: .generationStatusBadge)
                : nil
            generationStageSurface {
                GenerationRunningSurface(modelID: modelID, imageCount: imageCount, statusBadgeGlass: statusBadgeGlass)
            }
        case let .completed(result):
            let resultActionGlass = shouldUseCustomGlass(surface: .resultActionChip, slot: ComposerGlassSlot.resultActionChip)
                ? glassStyle(for: .resultActionChip)
                : nil
            generationStageSurface {
                GenerationCompletedSurface(
                    result: result,
                    prompt: $appState.prompt,
                    onOpenViewer: { appState.openViewer(jobID: result.jobID, imageIndex: 0) },
                    onGenerateMore: { Task { await appState.enqueueGeneration() } },
                    onStartOver: { appState.returnToPromptComposer() },
                    actionGlass: resultActionGlass
                )
            }
        case let .failed(message):
            generationStageSurface {
                GenerationFailureSurface(message: message) {
                    Task { await appState.enqueueGeneration() }
                }
            }
        case .canceled:
            generationStageSurface {
                GenerationFailureSurface(message: "Generation canceled") {
                    Task { await appState.enqueueGeneration() }
                }
            }
        }
    }

    @ViewBuilder
    private var heroPromptSurface: some View {
        let optionSupport = appState.currentModelOptionSupport ?? .baseline

        let card = VStack(alignment: .leading, spacing: appState.designSystem.spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Prompt")
                    .font(.headline)

                Spacer(minLength: 8)

                Menu {
                    if !popularModelEntries.isEmpty {
                        Section("Popular") {
                            ForEach(popularModelEntries.prefix(8)) { entry in
                                modelMenuItem(entry)
                            }
                        }
                    }

                    Section("All Models") {
                        ForEach(otherModelEntries) { entry in
                            modelMenuItem(entry)
                        }
                    }

                    Divider()

                    Button {
                        Task { await appState.refreshModels() }
                    } label: {
                        Label("Sync Model List", systemImage: "arrow.clockwise")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(modelDisplayName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.18), in: .capsule)
                }
                .menuStyle(.button)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.prompt)
                    .font(.title3)
                    .padding(14)
                    .frame(minHeight: 190)
                    .scrollContentBackground(.hidden)
                    .focused($isPromptFocused)

                if appState.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Describe the subject, style, camera, mood, lighting, and any text to render.")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 22)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.black.opacity(0.22), in: .rect(cornerRadius: appState.designSystem.radius.actionChip))

            starterPromptRow

            let accessoryControls = GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    if optionSupport.supportsAspectRatio {
                        Menu {
                            ForEach(optionSupport.allowedAspectRatios, id: \.self) { value in
                                Button(value) { appState.aspectRatio = value }
                            }
                        } label: {
                            Label(appState.aspectRatio, systemImage: "aspectratio")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                    }

                    if optionSupport.supportsImageSize {
                        Menu {
                            ForEach(optionSupport.allowedImageSizes, id: \.self) { value in
                                Button(value) { appState.imageSize = value }
                            }
                        } label: {
                            Label(appState.imageSize, systemImage: "rectangle.expand.vertical")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                    }

                    if optionSupport.supportsImageCount {
                        Menu {
                            ForEach(Array(optionSupport.imageCountRange), id: \.self) { count in
                                Button("\(count)") { appState.imageCount = count }
                            }
                        } label: {
                            Label("\(appState.imageCount)x", systemImage: "photo.stack")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                    }

                    if currentModelEntry?.supportsAdvancedImageOptions == true {
                        Button {
                            isAdvancedPopoverPresented.toggle()
                        } label: {
                            Label("Advanced", systemImage: "slider.horizontal.3")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                        .popover(isPresented: $isAdvancedPopoverPresented, arrowEdge: .bottom) {
                            advancedImageOptionsPopover(optionSupport: optionSupport)
                        }
                    }

                    Button {
                        Task { await appState.refreshModels() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.glass)

                    Spacer(minLength: 10)

                    Button {
                        appState.prompt = ""
                    } label: {
                        Label("Reset", systemImage: "arrow.uturn.backward")
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.glass)

                    Button {
                        Task { await appState.enqueueGeneration() }
                    } label: {
                        Label("Generate", systemImage: "sparkles")
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!appState.canSubmitPrompt)
                    .opacity(appState.canSubmitPrompt ? 1 : 0.55)
                }
            }

            if shouldUseCustomGlass(surface: .heroAccessoryControls, slot: ComposerGlassSlot.heroAccessories) {
                accessoryControls
                    .padding(8)
                    .glassEffect(glassStyle(for: .heroAccessoryControls), in: .rect(cornerRadius: appState.designSystem.radius.actionChip))
            } else {
                accessoryControls
                    .padding(8)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: appState.designSystem.radius.actionChip))
            }
        }
        .padding(20)
        .frame(maxWidth: 980)
        .background(
            LinearGradient(
                colors: [
                    appState.designSystem.colors.panel.opacity(0.84),
                    appState.designSystem.colors.accent.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: appState.designSystem.radius.heroPrompt)
        )
        .glassEffectID("composer-stage-card", in: namespace)
        .glassEffectTransition(reduceMotion ? .materialize : .matchedGeometry)

        if shouldUseCustomGlass(surface: .heroPromptCard, slot: ComposerGlassSlot.heroPromptCard) {
            card.glassEffect(glassStyle(for: .heroPromptCard), in: .rect(cornerRadius: appState.designSystem.radius.heroPrompt))
        } else {
            card.background(.ultraThinMaterial, in: .rect(cornerRadius: appState.designSystem.radius.heroPrompt))
        }
    }

    private var starterPromptRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(starterPrompts, id: \.self) { sample in
                    Button {
                        appState.prompt = sample
                    } label: {
                        Text(sample)
                            .lineLimit(1)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    private func generationStageSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let card = VStack(alignment: .leading, spacing: appState.designSystem.spacing.md) {
            content()
        }
        .padding(20)
        .frame(maxWidth: 980)
        .background(
            LinearGradient(
                colors: [
                    appState.designSystem.colors.panel.opacity(0.84),
                    appState.designSystem.colors.accentSoft.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: appState.designSystem.radius.generationStage)
        )
        .glassEffectID("composer-stage-card", in: namespace)
        .glassEffectTransition(reduceMotion ? .materialize : .matchedGeometry)

        return Group {
            if shouldUseCustomGlass(surface: .generationStageCard, slot: ComposerGlassSlot.generationStage) {
                card.glassEffect(glassStyle(for: .generationStageCard), in: .rect(cornerRadius: appState.designSystem.radius.generationStage))
            } else {
                card.background(.ultraThinMaterial, in: .rect(cornerRadius: appState.designSystem.radius.generationStage))
            }
        }
    }

    private var modelDisplayName: String {
        if let selected = currentModelEntry {
            return selected.displayName
        }
        return appState.selectedModelID
    }

    private var currentModelEntry: ModelCatalogEntry? {
        appState.modelCatalog.first(where: { $0.id == appState.selectedModelID })
    }

    private var popularModelEntries: [ModelCatalogEntry] {
        appState.modelCatalog
            .filter(\.isPopular)
            .sorted { lhs, rhs in
                let lhsRank = lhs.popularityRank ?? .max
                let rhsRank = rhs.popularityRank ?? .max
                if lhsRank == rhsRank {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return lhsRank < rhsRank
            }
    }

    private var otherModelEntries: [ModelCatalogEntry] {
        appState.modelCatalog
            .filter { !$0.isPopular }
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func modelMenuItem(_ entry: ModelCatalogEntry) -> some View {
        Button {
            appState.selectModel(entry.id)
        } label: {
            HStack {
                if entry.id == appState.selectedModelID {
                    Image(systemName: "checkmark")
                }

                Text(entry.displayName)

                Spacer(minLength: 6)

                Text(entry.pricePerImageDisplay)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private func advancedImageOptionsPopover(optionSupport: ImageOptionSupport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced Model Options")
                .font(.headline)

            if optionSupport.supportsFontInputs {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Font Inputs (Sourceful)")
                        .font(.subheadline.weight(.semibold))

                    if appState.fontInputs.isEmpty {
                        Text("Add up to 2 font definitions for text rendering.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(appState.fontInputs) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                "Font URL",
                                text: bindingForFontURL(id: item.id)
                            )
                            .textFieldStyle(.roundedBorder)

                            TextField(
                                "Text to render",
                                text: bindingForFontText(id: item.id)
                            )
                            .textFieldStyle(.roundedBorder)

                            Button(role: .destructive) {
                                removeFontInput(id: item.id)
                            } label: {
                                Label("Remove Font Input", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.12), in: .rect(cornerRadius: 10))
                    }

                    if appState.fontInputs.count < 2 {
                        Button {
                            appState.fontInputs.append(FontInput(fontURL: "", text: ""))
                        } label: {
                            Label("Add Font Input", systemImage: "plus")
                        }
                        .buttonStyle(.glass)
                    }
                }
            } else {
                Text("No advanced options for this model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func bindingForFontURL(id: UUID) -> Binding<String> {
        Binding(
            get: {
                appState.fontInputs.first(where: { $0.id == id })?.fontURL ?? ""
            },
            set: { newValue in
                guard let index = appState.fontInputs.firstIndex(where: { $0.id == id }) else { return }
                appState.fontInputs[index].fontURL = newValue
            }
        )
    }

    private func bindingForFontText(id: UUID) -> Binding<String> {
        Binding(
            get: {
                appState.fontInputs.first(where: { $0.id == id })?.text ?? ""
            },
            set: { newValue in
                guard let index = appState.fontInputs.firstIndex(where: { $0.id == id }) else { return }
                appState.fontInputs[index].text = newValue
            }
        )
    }

    private func removeFontInput(id: UUID) {
        appState.fontInputs.removeAll { $0.id == id }
    }

    private func shouldUseCustomGlass(surface: LiquidGlassSurface, slot: Int) -> Bool {
        appState.liquidPolicy.allowsCustomGlass(on: surface, slot: slot)
    }

    private func glassStyle(for surface: LiquidGlassSurface) -> Glass {
        appState.designSystem.glass(
            for: appState.liquidPolicy.glassTier(for: surface),
            intensity: appState.preferences.visualIntensity,
            interactive: appState.liquidPolicy.isInteractive(surface: surface)
        )
    }
}

private struct GenerationQueuedSurface: View {
    let position: Int

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)

            VStack(alignment: .leading, spacing: 6) {
                Text("Queued")
                    .font(.headline)
                Text("Your render is lined up and will start shortly. Position \(position).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct GenerationRunningSurface: View {
    let modelID: String
    let imageCount: Int
    let statusBadgeGlass: Glass?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Generating", systemImage: "sparkles")
                    .font(.headline)
                Spacer(minLength: 8)
                Text("\(imageCount)x")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .modifier(ActionChipGlassModifier(glass: statusBadgeGlass))
            }

            Text(modelID)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.13),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        ForEach(0..<min(max(imageCount, 1), 4), id: \.self) { index in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                )
                                .opacity(animatePulse ? 1.0 : 0.52)
                                .animation(
                                    .easeInOut(duration: 0.9)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.12),
                                    value: animatePulse
                                )
                        }
                    }

                    ProgressView()
                        .controlSize(.large)

                    Text(imageCount > 1 ? "Rendering your images..." : "Rendering your image...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(.rect(cornerRadius: 16))
        }
        .task {
            guard !reduceMotion else { return }
            animatePulse = true
        }
    }
}

private struct GenerationCompletedSurface: View {
    let result: GenerationResult
    @Binding var prompt: String
    let onOpenViewer: () -> Void
    let onGenerateMore: () -> Void
    let onStartOver: () -> Void
    let actionGlass: Glass?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Image Ready", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer(minLength: 8)
                Text(result.modelID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let first = result.images.first,
               let nsImage = imageFromBase64(first.base64Data) {
                Button(action: onOpenViewer) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 240, maxHeight: 380)
                            .clipShape(.rect(cornerRadius: 16))
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))

                        Label("Open Fullscreen / Save", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .modifier(ActionChipGlassModifier(glass: actionGlass))
                            .padding(12)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open full image viewer")
            } else {
                ContentUnavailableView("Image unavailable", systemImage: "exclamationmark.triangle")
                    .frame(maxWidth: .infinity, minHeight: 190)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Next prompt")
                    .font(.subheadline.weight(.semibold))

                TextEditor(text: $prompt)
                    .font(.body)
                    .padding(10)
                    .frame(minHeight: 90, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.2), in: .rect(cornerRadius: 12))

                HStack(spacing: 10) {
                    Button("Start Over", action: onStartOver)
                        .buttonStyle(.glass)

                    Spacer(minLength: 8)

                    Button {
                        onGenerateMore()
                    } label: {
                        Label("Generate More", systemImage: "sparkles")
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.top, 6)
        }
    }

    private func imageFromBase64(_ value: String) -> NSImage? {
        if let data = Data(base64Encoded: value) {
            return NSImage(data: data)
        }
        if let parsed = DataURL(rawValue: value), let data = parsed.decodeData() {
            return NSImage(data: data)
        }
        return nil
    }
}

private struct ActionChipGlassModifier: ViewModifier {
    let glass: Glass?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let glass {
            content.glassEffect(glass, in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: .capsule)
        }
    }
}

private struct GenerationFailureSurface: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text("Generation issue")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Retry", action: onRetry)
                .buttonStyle(.glassProminent)
        }
    }
}
