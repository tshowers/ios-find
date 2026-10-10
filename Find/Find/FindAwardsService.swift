import Foundation
import Combine

// Mirrors the web app's src/app/services/find-awards.service.ts exactly -
// same 10-award ladder, same thresholds, same copy, same Night Owl / Early
// Bird resolve-once-and-keep-it behavior. Storage is UserDefaults instead of
// localStorage (no cross-platform sync intended - just the same shape).
enum FindAwardIcon: String, Codable {
    case rebel, curious, nightOwl, earlyBird, connector, sharpEye, explorer, specialist, relentless, tastemaker, legend
}

enum FindAwardState {
    case unlocked, locked, mystery
}

struct FindAward: Identifiable, Codable {
    let id: String
    var title: String
    let threshold: Int
    var copy: String
    var icon: FindAwardIcon
    var hidden: Bool = false
}

struct FindAwardListItem: Identifiable {
    let id: String
    let title: String
    let icon: FindAwardIcon
    let state: FindAwardState
}

private struct FindAwardUnlockRecord: Codable {
    let title: String
    let copy: String
    let icon: FindAwardIcon
    let unlockedAt: Date
}

@MainActor
final class FindAwardsService: ObservableObject {
    @Published private(set) var count: Int = 0
    @Published private var unlocked: [String: FindAwardUnlockRecord] = [:]

    static let ladder: [FindAward] = [
        FindAward(id: "rebel", title: "The Rebel", threshold: 1,
                  copy: "You don\u{2019}t wait for permission \u{2014} you go find it yourself.", icon: .rebel),
        FindAward(id: "curious-one", title: "The Curious One", threshold: 3,
                  copy: "You can\u{2019}t leave a question alone. Never could.", icon: .curious),
        FindAward(id: "night-owl", title: "The Night Owl / Early Bird", threshold: 6,
                  copy: "3am and your mind\u{2019}s still going. That\u{2019}s not insomnia \u{2014} that\u{2019}s you.", icon: .nightOwl),
        FindAward(id: "connector", title: "The Connector", threshold: 10,
                  copy: "You saw the thread before anyone said it out loud.", icon: .connector),
        FindAward(id: "sharp-eye", title: "The Sharp Eye", threshold: 15,
                  copy: "Something felt off and you were right.", icon: .sharpEye),
        FindAward(id: "explorer", title: "The Explorer", threshold: 20,
                  copy: "One result was never going to be enough for you.", icon: .explorer),
        FindAward(id: "specialist", title: "The Specialist", threshold: 30,
                  copy: "You stopped skimming. You went all the way down.", icon: .specialist),
        FindAward(id: "relentless", title: "The Relentless", threshold: 40,
                  copy: "Something in you refused to close the tab.", icon: .relentless),
        FindAward(id: "tastemaker", title: "The Tastemaker", threshold: 60,
                  copy: "People catch up to what you already knew.", icon: .tastemaker),
        FindAward(id: "legend", title: "The Legend", threshold: 100, copy: "You stopped counting a while ago. So did we.",
                  icon: .legend, hidden: true),
    ]

    private let countKey = "find-awards-count"
    private let unlockedKey = "find-awards-unlocked"

    init() {
        load()
    }

    var awards: [FindAwardListItem] {
        Self.ladder.map { award in
            if let record = unlocked[award.id] {
                return FindAwardListItem(id: award.id, title: record.title, icon: record.icon, state: .unlocked)
            }
            return FindAwardListItem(id: award.id, title: award.title, icon: award.icon, state: award.hidden ? .mystery : .locked)
        }
    }

    var totalCount: Int { Self.ladder.count }

    var unlockedCount: Int {
        Self.ladder.filter { !$0.hidden && unlocked[$0.id] != nil }.count
    }

    var progressPercent: Double {
        let trackable = Self.ladder.filter { !$0.hidden }.count
        return trackable == 0 ? 0 : Double(unlockedCount) / Double(trackable)
    }

    /// Call once per completed search. Returns the award that was just unlocked, if any.
    @discardableResult
    func recordSearch() -> FindAward? {
        count += 1
        save()

        var justUnlocked: FindAward?
        for award in Self.ladder {
            guard unlocked[award.id] == nil, count >= award.threshold else { continue }
            let resolved = resolveAward(award)
            unlocked[award.id] = FindAwardUnlockRecord(title: resolved.title, copy: resolved.copy, icon: resolved.icon, unlockedAt: Date())
            justUnlocked = resolved
        }
        if justUnlocked != nil { save() }
        return justUnlocked
    }

    private func resolveAward(_ award: FindAward) -> FindAward {
        guard award.id == "night-owl" else { return award }
        let hour = Calendar.current.component(.hour, from: Date())
        let isEarly = hour >= 4 && hour < 12
        var resolved = award
        if isEarly {
            resolved.title = "The Early Bird"
            resolved.icon = .earlyBird
            resolved.copy = "You were thinking before the world woke up."
        } else {
            resolved.title = "The Night Owl"
            resolved.icon = .nightOwl
            resolved.copy = "3am and your mind\u{2019}s still going. That\u{2019}s not insomnia \u{2014} that\u{2019}s you."
        }
        return resolved
    }

    private func load() {
        count = UserDefaults.standard.integer(forKey: countKey)
        if let data = UserDefaults.standard.data(forKey: unlockedKey),
           let decoded = try? JSONDecoder().decode([String: FindAwardUnlockRecord].self, from: data) {
            unlocked = decoded
        }
    }

    private func save() {
        UserDefaults.standard.set(count, forKey: countKey)
        if let data = try? JSONEncoder().encode(unlocked) {
            UserDefaults.standard.set(data, forKey: unlockedKey)
        }
    }
}
