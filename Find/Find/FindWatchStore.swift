import Combine
import Foundation
import UIKit
import UserNotifications
import WidgetKit

extension Notification.Name {
    /// AppDelegate got an APNs device token (hex string in `object`).
    static let findPushTokenReceived = Notification.Name("findPushTokenReceived")
    /// The user tapped a Watch notification; `object` is the watch's query.
    static let findOpenWatchedQuery = Notification.Name("findOpenWatchedQuery")
}

/// "Watch a find" (the web's watches in find-home.component.ts). No account:
/// this device keeps its own random id. Watches are only fetched once the
/// device has watched something, so ordinary launches make no extra request.
@MainActor
final class FindWatchStore: ObservableObject {
    @Published private(set) var watches: [FindWatch] = [] {
        didSet {
            shareWithWidget()
            FindSpotlight.indexWatches(watches)
        }
    }
    @Published private(set) var busyKey: String?
    @Published var message = ""
    /// Changed watches stay highlighted for the visit they were first seen on.
    @Published private(set) var highlightedIDs: Set<String> = []

    static let maxWatches = 10

    private let apiClient: FindAPIClient
    private let defaults = UserDefaults.standard
    private var tokenObserver: NSObjectProtocol?

    init(apiClient: FindAPIClient) {
        self.apiClient = apiClient
        tokenObserver = NotificationCenter.default.addObserver(forName: .findPushTokenReceived, object: nil, queue: .main) { [weak self] note in
            guard let token = note.object as? String else { return }
            Task { @MainActor in await self?.registerDevice(token: token) }
        }
        if hasWatches {
            Task { await refresh() }
        }
    }

    var deviceId: String {
        if let saved = defaults.string(forKey: "find.deviceId") { return saved }
        let created = UUID().uuidString
        defaults.set(created, forKey: "find.deviceId")
        return created
    }

    private var hasWatches: Bool {
        get { defaults.bool(forKey: "find.hasWatches") }
        set { defaults.set(newValue, forKey: "find.hasWatches") }
    }

    var changedCount: Int { watches.filter(\.changed).count }

    func watch(query: String, url: String) -> FindWatch? {
        watches.first { $0.query == query && $0.url == url }
    }

    /// Watch this result, or stop watching it.
    func toggle(query: String, url: String, title: String, queryType: String, address: String?, phone: String?) async {
        let key = "\(query)|\(url)"
        guard busyKey == nil else { return }
        busyKey = key
        message = ""
        defer { busyKey = nil }

        if let existing = watch(query: query, url: url) {
            if (try? await apiClient.watch("find/watches/remove", FindWatchRequest(deviceId: deviceId, id: existing.id))) != nil {
                watches.removeAll { $0.id == existing.id }
            } else {
                message = "Find couldn’t stop watching right now."
            }
            return
        }

        do {
            let response = try await apiClient.watch("find/watches", FindWatchRequest(
                deviceId: deviceId, query: query, url: url, title: title, queryType: queryType, address: address, phone: phone
            ))
            guard let created = response.watch else { throw FindAPIError.invalidResponse }
            watches.removeAll { $0.id == created.id }
            watches.insert(created, at: 0)
            hasWatches = true
            let cadence = created.kind == "hours" || created.kind == "page" ? "twice a day" : "every few hours"
            message = "Watching. Find checks it \(cadence) and shows changes in History."
            await requestNotifications()
        } catch FindAPIError.httpError(409) {
            message = "You can watch up to \(Self.maxWatches) finds. Remove one to add another."
        } catch {
            message = "Find couldn’t start watching right now."
        }
    }

    func refresh(markSeen: Bool = false) async {
        guard let response = try? await apiClient.watch("find/watches/list", FindWatchRequest(deviceId: deviceId)) else { return }
        watches = response.watches ?? []
        if watches.isEmpty { hasWatches = false }
        guard markSeen, changedCount > 0 else { return }
        highlightedIDs.formUnion(watches.filter(\.changed).map(\.id))
        if (try? await apiClient.watch("find/watches/seen", FindWatchRequest(deviceId: deviceId))) != nil {
            await refresh()
        }
    }

    func remove(_ watch: FindWatch) async {
        if (try? await apiClient.watch("find/watches/remove", FindWatchRequest(deviceId: deviceId, id: watch.id))) != nil {
            watches.removeAll { $0.id == watch.id }
        }
    }

    func renew(_ watch: FindWatch) async {
        guard let renewed = try? await apiClient.watch("find/watches/renew", FindWatchRequest(deviceId: deviceId, id: watch.id)).watch else { return }
        watches = watches.map { $0.id == renewed.id ? renewed : $0 }
    }

    // MARK: Notifications

    /// Asked the first time something is watched, not on launch.
    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func registerDevice(token: String) async {
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        _ = try? await apiClient.watch("find/devices", FindWatchRequest(deviceId: deviceId, apnsToken: token, environment: environment))
    }

    // MARK: Widget

    /// The home-screen widget reads the latest change from the shared App
    /// Group (FindWidgetProvider in FindWidget.swift).
    private func shareWithWidget() {
        guard let shared = UserDefaults(suiteName: "group.tech.taliferro.find") else { return }
        let latest = watches.compactMap { watch in watch.lastChange.map { (watch, $0) } }.max { $0.1.at < $1.1.at }
        let values: [String: Any] = [
            "widget.changedCount": changedCount,
            "widget.latestTitle": latest?.0.title ?? "",
            "widget.latestSummary": latest?.1.summary ?? "",
            "widget.latestAt": (latest?.1.at ?? 0) / 1000,
        ]
        let unchanged = values.allSatisfy { key, value in (shared.object(forKey: key) as? NSObject)?.isEqual(value) == true }
        guard !unchanged else { return }
        values.forEach { shared.set($1, forKey: $0) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Display

    func kindLabel(_ watch: FindWatch) -> String {
        ["price": "Price", "hours": "Hours", "topic": "New results", "page": "Page"][watch.kind] ?? "Watching"
    }

    func status(_ watch: FindWatch) -> String {
        if watch.expired { return "Watch ended" }
        if let change = watch.lastChange { return "\(change.summary) · \(Self.relative(change.at))" }
        if let checked = watch.lastCheckedAt { return "No changes yet · checked \(Self.relative(checked))" }
        return "First check coming up"
    }

    func daysLeft(_ watch: FindWatch) -> Int {
        max(0, Int(ceil((watch.expiresAt / 1000 - Date().timeIntervalSince1970) / 86400)))
    }

    private static func relative(_ milliseconds: Double) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: Date(timeIntervalSince1970: milliseconds / 1000), relativeTo: Date())
    }
}
