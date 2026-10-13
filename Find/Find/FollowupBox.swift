import SwiftUI

/// What a result page needs to ask a follow-up and to run a new search,
/// handed down from SearchView (pages live inside a UIPageViewController,
/// so they can't reach the view model through the environment).
struct FindFollowupActions {
    let ask: (FindFollowupRequest) async -> FindFollowupResponse
    let search: (String) -> Void
}

/// "Ask about this result" (the web's #followupBox in find-home.component.html):
/// a short answer from this result's own sources, with a way back. A
/// question that wants something else runs that search instead.
struct FollowupBox: View {
    let query: String
    let url: String
    let title: String
    let sourceUrls: [String]
    let actions: FindFollowupActions

    @State private var text = ""
    @State private var isAsking = false
    @State private var asked: (question: String, response: FindFollowupResponse)?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let asked {
                answerCard(question: asked.question, response: asked.response)
            }

            HStack(spacing: 8) {
                TextField("Ask about this result", text: $text)
                    .font(Theme.font(15))
                    .submitLabel(.send)
                    .focused($isFocused)
                    .onSubmit(ask)
                    .disabled(isAsking)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .overlay(Capsule().stroke(Theme.surface2, lineWidth: 1))

                Button(action: ask) {
                    Text(isAsking ? "Asking…" : "Ask")
                        .font(Theme.font(15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAsking || text.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(isAsking || text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
    }

    private func answerCard(question: String, response: FindFollowupResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.uppercased())
                .font(Theme.font(12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Theme.tBlueFg)

            if response.answered {
                Text(response.answer)
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !response.sources.isEmpty {
                    HStack(spacing: 4) {
                        Text("From").foregroundStyle(Theme.tBlueFg)
                        ForEach(response.sources, id: \.url) { source in
                            if let link = URL(string: source.url) {
                                Link(source.displayUrl, destination: link).foregroundStyle(Theme.blueInk)
                            }
                        }
                    }
                    .font(Theme.font(13))
                }
            } else {
                Text(response.success ? "The sources for this result don’t say." : "Find couldn’t check the sources right now.")
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.text)
                Button("Search for “\(response.searchQuery)”") {
                    actions.search(response.searchQuery)
                }
                .font(Theme.font(14, weight: .semibold))
                .foregroundStyle(Theme.blueInk)
                .buttonStyle(.plain)
            }

            Button("Back to the result") { asked = nil }
                .font(Theme.font(14, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.tBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func ask() {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAsking else { return }
        isAsking = true
        isFocused = false
        let request = FindFollowupRequest(query: query, followup: question, url: url, title: title, sourceUrls: sourceUrls)
        Task {
            let response = await actions.ask(request)
            isAsking = false
            text = ""
            if response.mode == "search", !response.searchQuery.isEmpty {
                actions.search(response.searchQuery)
            } else {
                asked = (question, response)
            }
        }
    }
}
