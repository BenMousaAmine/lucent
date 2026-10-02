import SwiftUI

struct TrashColumn: View {
    let model: TrashViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(ByteCountFormatter.string(fromByteCount: model.totalBytes, countStyle: .file))
                    .font(LucentTheme.numeric(.title3))
                Spacer()
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Refresh")
                Button("Open Trash in Finder") { model.openInFinder() }
                    .disabled(model.items.isEmpty)
            }
            .padding(.horizontal).padding(.top).padding(.bottom, 6)

            Text("Everything you delete, from Lucent too, waits here and keeps using disk space until you empty the Trash in Finder. If Finder says an item is “in use”, an open app still has files inside it: quit that app (often an IDE or Xcode) and empty again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal).padding(.bottom, 8)

            Divider()

            content
        }
        .navigationTitle("Trash")
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            VStack { Spacer(); ProgressView(); Spacer() }
                .frame(maxWidth: .infinity)
        case .noAccess:
            VStack {
                Label("Lucent can't read the Trash. Enable Full Disk Access in Settings → Privacy.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding()
                Spacer()
            }
        case .loaded(let items):
            if items.isEmpty {
                ContentUnavailableView("The Trash is empty", systemImage: "trash")
            } else {
                List(items) { item in
                    HStack {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(item.isDirectory ? AnyShapeStyle(LucentTheme.accent) : AnyShapeStyle(.secondary))
                        Text(item.name)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: item.physicalTotal, countStyle: .file))
                            .font(LucentTheme.numeric(.body)).foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
