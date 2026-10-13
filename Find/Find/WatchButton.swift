import SwiftUI

/// The Watch / Watching button on a result page, plus the line under it
/// after watching ("Watching. Find checks it…") or when the limit is hit.
struct WatchButton: View {
    @ObservedObject var store: FindWatchStore
    let query: String
    let url: String
    let title: String
    let queryType: String
    let address: String?
    let phone: String?

    var body: some View {
        let isWatching = store.watch(query: query, url: url) != nil
        let isBusy = store.busyKey == "\(query)|\(url)"
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await store.toggle(query: query, url: url, title: title, queryType: queryType, address: address, phone: phone) }
            } label: {
                Label(isWatching ? "Watching" : "Watch", systemImage: isWatching ? "eye.fill" : "bell")
                    .font(Theme.font(14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(isWatching ? Theme.tBlueFg : Theme.text)
                    .background(isWatching ? Theme.tBlue : Theme.surface, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityAddTraits(isWatching ? .isSelected : [])

            if !store.message.isEmpty {
                Text(store.message)
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
