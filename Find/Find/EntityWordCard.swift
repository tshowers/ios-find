import SwiftUI

/// A dictionary card for "define <word>" (web: find-word-card): the word, how
/// to say it, and its meanings, straight from the dictionary via the backend,
/// so the same word reads the same every time. A similar word is a new
/// "define" search.
struct EntityWordCard: View {
    let entity: FindEntity
    let fetch: @Sendable (String) async -> Data?
    let onSearch: (String) -> Void
    @StateObject private var sections = EntitySections()
    @StateObject private var audio = EntityPreviewPlayer()

    private var word: FindWordSection? { sections.value("word", as: FindWordSection.self) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                EntityTagChips(tags: [FindEntityTag(text: "Dictionary", tone: "violet")] + (word?.meanings.map { FindEntityTag(text: $0.partOfSpeech, tone: "plain") } ?? []))
                Text(word?.word ?? entity.name)
                    .font(Theme.font(40, weight: .bold))
                    .tracking(-1)
                    .foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .textSelection(.enabled)
                if let word, !word.phonetic.isEmpty || word.audioUrl != nil {
                    HStack(spacing: 12) {
                        if !word.phonetic.isEmpty {
                            Text(word.phonetic).font(Theme.font(17)).foregroundStyle(Theme.text)
                        }
                        if let link = word.audioUrl, let url = URL(string: link) {
                            Button { audio.toggle(url) } label: {
                                Label(audio.isPlaying ? "Stop" : "Listen", systemImage: audio.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                                    .font(Theme.font(14, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(Theme.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Hear \(word.word)")
                        }
                    }
                }
            }

            if sections.isLoading("word") {
                EntitySkeleton(height: 220, radius: 20)
            } else if let word {
                ForEach(Array(word.meanings.enumerated()), id: \.offset) { _, meaning in
                    meaningView(meaning, sourceUrl: word.sourceUrl)
                }
            } else {
                Text("The dictionary couldn't be reached. More results has other definitions.")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.muted)
            }

            if let word {
                EntityActionTiles(actions: [
                    EntityAction("Full entry", systemImage: "book.fill", url: word.sourceUrl),
                ].compactMap { $0 })
            }
        }
        .task { await sections.load(["word"], fetch: fetch) }
        .onDisappear { audio.stop() }
    }

    private func meaningView(_ meaning: FindWordSection.Meaning, sourceUrl: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EntityListTitle(text: meaning.partOfSpeech.uppercased())
            ForEach(Array(meaning.definitions.enumerated()), id: \.offset) { index, definition in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .font(Theme.font(17, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(minWidth: 22, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(definition.text)
                            .font(Theme.font(17))
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        if !definition.example.isEmpty {
                            Text("“\(definition.example)”")
                                .font(Theme.font(15).italic())
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if meaning.moreCount > 0, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    Text("\(meaning.moreCount) more \(meaning.moreCount == 1 ? "meaning" : "meanings") as \(article(meaning.partOfSpeech)) \(meaning.partOfSpeech) ↗")
                        .font(Theme.font(14, weight: .semibold))
                        .foregroundStyle(Theme.blueInk)
                }
            }
            if !meaning.synonyms.isEmpty {
                EntityFlow(spacing: 8) {
                    Text("Similar").font(Theme.font(13, weight: .semibold)).foregroundStyle(Theme.muted).frame(height: 30)
                    ForEach(meaning.synonyms, id: \.self) { synonym in
                        Button { onSearch("define \(synonym)") } label: {
                            Text(synonym)
                                .font(Theme.font(13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(Theme.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// "an adjective", "a noun".
    private func article(_ word: String) -> String {
        "aeiou".contains(word.lowercased().first ?? "x") ? "an" : "a"
    }
}
