import SwiftUI

private enum ModelCatalogSegment: String, CaseIterable, Identifiable {
    case popular
    case all

    var id: String { rawValue }
}

struct ModelBrowserView: View {
    @Bindable var appState: AppState

    @State private var segment: ModelCatalogSegment = .all
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: appState.designSystem.spacing.md) {
            Text("Image Models")
                .font(.largeTitle.bold())
            Text("Showing \(filteredEntries.count) models (\(appState.modelCatalog.filter { $0.isPopular }.count) popular).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Catalog", selection: $segment) {
                Text("Popular").tag(ModelCatalogSegment.popular)
                Text("All").tag(ModelCatalogSegment.all)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            TextField("Search models", text: $search)
                .textFieldStyle(.roundedBorder)

            List(filteredEntries) { entry in
                ModelRow(entry: entry, isSelected: entry.id == appState.selectedModelID) {
                    appState.selectModel(entry.id)
                }
            }
            .listStyle(.inset)
        }
    }

    private var filteredEntries: [ModelCatalogEntry] {
        let base: [ModelCatalogEntry] = {
            switch segment {
            case .popular:
                return appState.modelCatalog.filter(\.isPopular)
            case .all:
                return appState.modelCatalog
            }
        }()

        guard !search.isEmpty else { return base }
        return base.filter {
            $0.displayName.localizedStandardContains(search) ||
                $0.id.localizedStandardContains(search) ||
                $0.description.localizedStandardContains(search)
        }
    }
}

private struct ModelRow: View {
    let entry: ModelCatalogEntry
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.displayName)
                        .font(.headline)
                    if entry.isPopular {
                        Text("Popular")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(.orange), in: .capsule)
                    }
                }

                Text(entry.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("Image cost:")
                        .font(.caption.weight(.semibold))
                    Text(entry.pricePerImageDisplay)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(entry.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.primary.opacity(isSelected ? 0.12 : 0.04))
            )
        }
        .buttonStyle(.plain)
    }
}
