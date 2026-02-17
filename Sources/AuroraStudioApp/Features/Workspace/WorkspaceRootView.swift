import SwiftUI

private enum SidebarDestination: String, CaseIterable, Identifiable {
    case composer
    case models
    case queue
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .composer: return "Create"
        case .models: return "Models"
        case .queue: return "Queue"
        case .history: return "History"
        }
    }

    var symbol: String {
        switch self {
        case .composer: return "sparkles.rectangle.stack"
        case .models: return "square.stack.3d.up"
        case .queue: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .history: return "photo.stack"
        }
    }
}

struct WorkspaceRootView: View {
    @Bindable var appState: AppState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var destination: SidebarDestination = .composer
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .detailOnly
    @Namespace private var glassNamespace

    var body: some View {
        NavigationSplitView(columnVisibility: $splitColumnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(240)
        } detail: {
            content
                .padding()
                .background { workspaceBackground }
        }
        .tint(appState.designSystem.colors.accent)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task { await appState.refreshModels() }
                } label: {
                    Label("Refresh Models", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)

                Button {
                    appState.isOnboardingPresented = true
                } label: {
                    Label("Connections", systemImage: "key")
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $appState.isOnboardingPresented) {
            OnboardingView(appState: appState)
        }
        .overlay {
            if appState.isViewerPresented {
                ImageViewerOverlayView(appState: appState)
                    .zIndex(50)
                    .transition(.opacity)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { appState.globalErrorMessage != nil },
                set: { if !$0 { appState.globalErrorMessage = nil } }
            )
        ) {
            Button("OK") { appState.globalErrorMessage = nil }
        } message: {
            Text(appState.globalErrorMessage ?? "Unknown error")
        }
        .task {
            // Keep UI policy in sync with system accessibility settings.
            appState.preferences.reduceMotionOverride = appState.preferences.reduceMotionOverride
            appState.preferences.reduceTransparencyOverride = appState.preferences.reduceTransparencyOverride
            _ = appState.preferences.shouldReduceMotion(systemValue: reduceMotion)
            _ = appState.preferences.shouldReduceTransparency(systemValue: reduceTransparency)
            applyFocusColumnVisibility()
        }
        .onChange(of: destination) { _, _ in
            applyFocusColumnVisibility()
        }
        .onChange(of: appState.createExperienceMode) { _, _ in
            applyFocusColumnVisibility()
        }
        .animation(.easeOut(duration: 0.2), value: appState.isViewerPresented)
    }

    private var workspaceBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    appState.designSystem.colors.canvas,
                    appState.designSystem.colors.panel.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            AuroraAtmosphereView(
                reduceMotion: appState.preferences.shouldReduceMotion(systemValue: reduceMotion),
                reduceTransparency: appState.preferences.shouldReduceTransparency(systemValue: reduceTransparency),
                intensity: 1.0
            )
        }
    }

    private var sidebar: some View {
        List(selection: $destination) {
            Section("Workspace") {
                ForEach(SidebarDestination.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                }
            }

            Section("Live") {
                if appState.queueSnapshot.running != nil {
                    Label("Running: Text to Image", systemImage: "play.circle")
                } else {
                    Label("Idle", systemImage: "pause.circle")
                }

                Label("Queued: \(appState.queueSnapshot.queued.count)", systemImage: "clock")
                Label("Completed: \(appState.queueSnapshot.completed.count)", systemImage: "checkmark.circle")
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [
                    appState.designSystem.colors.canvas.opacity(0.95),
                    appState.designSystem.colors.panel.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            AuroraAtmosphereView(
                reduceMotion: appState.preferences.shouldReduceMotion(systemValue: reduceMotion),
                reduceTransparency: appState.preferences.shouldReduceTransparency(systemValue: reduceTransparency),
                intensity: 0.45
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .composer:
            ComposerView(appState: appState, namespace: glassNamespace)
        case .models:
            ModelBrowserView(appState: appState)
        case .queue:
            QueuePanelView(appState: appState)
        case .history:
            HistoryGalleryView(appState: appState)
        }
    }

    private func applyFocusColumnVisibility() {
        if destination == .composer, appState.shouldUseFocusHero {
            splitColumnVisibility = .detailOnly
            return
        }

        splitColumnVisibility = .all
    }
}

private struct AuroraAtmosphereView: View {
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let intensity: Double

    @State private var animatePhase = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 260)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.18, green: 0.82, blue: 0.98, opacity: 0.36),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 360
                    )
                )
                .frame(width: 760, height: 540)
                .blur(radius: 70)
                .offset(
                    x: animatePhase && !reduceMotion ? 190 : -170,
                    y: animatePhase && !reduceMotion ? -90 : 110
                )

            RoundedRectangle(cornerRadius: 320)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.38, green: 0.98, blue: 0.72, opacity: 0.28),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 320
                    )
                )
                .frame(width: 620, height: 480)
                .blur(radius: 90)
                .offset(
                    x: animatePhase && !reduceMotion ? -220 : 190,
                    y: animatePhase && !reduceMotion ? 120 : -130
                )

            RoundedRectangle(cornerRadius: 260)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.22, green: 0.44, blue: 0.95, opacity: 0.24),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 300
                    )
                )
                .frame(width: 680, height: 500)
                .blur(radius: 85)
                .offset(
                    x: animatePhase && !reduceMotion ? 70 : -90,
                    y: animatePhase && !reduceMotion ? 170 : -150
                )
        }
        .opacity((reduceTransparency ? 0.14 : 0.48) * intensity)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 13).repeatForever(autoreverses: true)) {
                animatePhase.toggle()
            }
        }
    }
}

private struct ModelInspectorCard: View {
    let entry: ModelCatalogEntry
    let designSystem: AppDesignSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topHeader
            descriptionSection
            capabilitySection
        }
    }

    private var topHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Inspector", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if entry.isPopular {
                    Label("Popular", systemImage: "flame.fill")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(designSystem.colors.accent.opacity(0.75)), in: .capsule)
                }
            }

            Text(entry.displayName)
                .font(.title2.weight(.semibold))
                .lineLimit(2)

            Text("Price per image")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(entry.pricePerImageDisplay)
                .font(.title3.weight(.bold))
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    designSystem.colors.accent.opacity(0.20),
                    designSystem.colors.panel.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 16)
        )
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.subheadline.weight(.semibold))

            if entry.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No description available for this model.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(parsedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var capabilitySection: some View {
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

        return VStack(alignment: .leading, spacing: 10) {
            Text("Capabilities")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(entry.outputModalities, id: \.self) { modality in
                    InspectorChip(text: modality.capitalized, icon: "sparkles.square.fill")
                }

                if entry.supportsImageInput {
                    InspectorChip(text: "Image Input", icon: "photo")
                }

                if entry.supportsImageConfig {
                    InspectorChip(text: "Image Config", icon: "slider.horizontal.3")
                }
            }

            if let signature = entry.modalitySignature, !signature.isEmpty {
                Text(signature)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var parsedDescription: AttributedString {
        let source = entry.description
        if let parsed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(source)
    }
}

private struct InspectorChip: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .capsule)
    }
}
