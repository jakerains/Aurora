import AppKit
import SwiftData
import SwiftUI

@MainActor
final class AuroraApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                self.configureWindowAppearance(window)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func configureWindowAppearance(_ window: NSWindow) {
        // Keep the toolbar while removing the duplicated centered title treatment.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
    }
}

@MainActor
@main
struct AuroraStudioApp: App {
    @NSApplicationDelegateAdaptor(AuroraApplicationDelegate.self) private var appDelegate
    @State private var appState = DependencyFactory.makeAppState()
    private let modelContainer = AuroraStudioApp.makeModelContainer()

    var body: some Scene {
        WindowGroup("Aurora Studio") {
            WorkspaceRootView(appState: appState)
                .environment(appState)
                .task {
                    appState.bootstrap()
                }
        }
        .windowStyle(.titleBar)
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try PersistenceController.container(inMemory: false)
        } catch {
            do {
                return try PersistenceController.container(inMemory: true)
            } catch {
                fatalError("Unable to create model container: \(error.localizedDescription)")
            }
        }
    }
}
