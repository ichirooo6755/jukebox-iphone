import JukeboxCore
import SwiftUI

struct GuestQueueView: View {
    @EnvironmentObject private var client: GuestAPIClient

    var body: some View {
        NavigationStack {
            Group {
                if client.playbackState.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("キューは空です")
                            .font(.title3.weight(.semibold))
                        Text("Search タブから曲やプレイリストを追加できます")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(client.playbackState.queue) { item in
                            queueRow(item)
                        }
                        .onMove(perform: moveItems)
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("キュー")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .refreshable { await client.refreshState() }
        }
    }

    private func queueRow(_ item: QueueItem) -> some View {
        HStack(spacing: 12) {
            artwork(for: item)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(item.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.service.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    Text(item.addedBy)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text(guestFormatTime(Double(item.duration)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func artwork(for item: QueueItem) -> some View {
        Group {
            if let url = GuestArtworkURL.imageURL(for: item, baseURL: client.hostURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholderArt
                    }
                }
            } else {
                placeholderArt
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholderArt: some View {
        ZStack {
            Color.pink.opacity(0.2)
            Image(systemName: "music.note")
                .foregroundStyle(.pink)
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = client.playbackState.queue
        items.move(fromOffsets: source, toOffset: destination)
        let order = items.map(\.id)
        Task {
            do {
                try await client.reorderQueue(order: order)
            } catch {
                client.errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let ids = offsets.map { client.playbackState.queue[$0].id }
        Task {
            for id in ids {
                do {
                    try await client.removeFromQueue(id: id)
                } catch {
                    client.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
