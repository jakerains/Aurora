import SwiftUI

struct QueuePanelView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: appState.designSystem.spacing.md) {
            Text("Generation Queue")
                .font(.largeTitle.bold())

            if let running = appState.queueSnapshot.running {
                GroupBox("Running") {
                    QueueRow(item: running, canCancel: true) {
                        Task { await appState.cancelJob(jobID: running.id) }
                    }
                }
            }

            GroupBox("Queued") {
                if appState.queueSnapshot.queued.isEmpty {
                    Text("No jobs queued.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(appState.queueSnapshot.queued) { item in
                        QueueRow(item: item, canCancel: true) {
                            Task { await appState.cancelJob(jobID: item.id) }
                        }
                    }
                }
            }

            GroupBox("Recent") {
                if appState.queueSnapshot.completed.isEmpty {
                    Text("No completed jobs yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(appState.queueSnapshot.completed.prefix(12)) { item in
                        QueueRow(item: item, canCancel: false, onCancel: nil)
                    }
                }
            }
        }
    }
}

private struct QueueRow: View {
    let item: GenerationQueueItem
    let canCancel: Bool
    let onCancel: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Text to Image")
                    .font(.headline)
                Text(item.job.modelID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.job.prompt)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer()

            statusBadge

            if canCancel, let onCancel {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.glass)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusBadge: some View {
        let color: Color = {
            switch item.status {
            case .queued: return .yellow
            case .running: return .blue
            case .succeeded: return .green
            case .failed: return .red
            case .canceled: return .gray
            }
        }()

        return Text(item.status.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular.tint(color), in: .capsule)
    }
}
