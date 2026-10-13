import SwiftUI

/// The share-sheet card (laid out like the app's instant answer card).
struct ShareView: View {
    @ObservedObject var model: ShareModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        TextField("Search for anything", text: $model.query)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)
                            .onSubmit { Task { await model.search() } }
                        Button("Find") { Task { await model.search() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isLoading)
                    }

                    if model.isLoading {
                        ProgressView("Finding the strongest result…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if let answer = model.answer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(answer.label.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(answer.headline)
                                .font(.title2.weight(.bold))
                                .textSelection(.enabled)
                            if !answer.detail.isEmpty {
                                Text(answer.detail)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                            if !answer.source.isEmpty {
                                Text(answer.source)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else if model.failed {
                        Text("Find couldn’t get a result right now.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Select some text, then share it to Find.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Find")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }
}
