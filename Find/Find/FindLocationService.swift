import CoreLocation

// Mirrors the web app's resolveCoordinatesForQuery (find-home.component.ts):
// location is requested lazily, only for a location-shaped query (weather
// with no named place, "near me" local search), never on launch. The
// granted position is cached for the rest of the session so the system
// permission prompt / a fresh GPS fix isn't repeated on every search. A
// denied/restricted/timed-out request resolves to nil rather than throwing,
// so the query still runs (without coordinates) instead of blocking - the
// backend falls back to a normal search when location is absent (see
// weather.service.js's locationlessWeather path and NEAR_ME_PATTERN there).
@MainActor
final class FindLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var cachedCoordinate: CLLocationCoordinate2D?

    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private let requestTimeoutSeconds: UInt64 = 8

    override init() {
        super.init()
        manager.delegate = self
    }

    var isSupported: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    /// Resolves to the current coordinate, requesting permission first if
    /// needed. Never throws or hangs indefinitely - a denial, restriction, or
    /// timeout resolves to nil.
    func currentCoordinate() async -> CLLocationCoordinate2D? {
        if let cachedCoordinate { return cachedCoordinate }
        guard isSupported else { return nil }

        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            let granted = await withTimeout(nil) { [weak self] in
                await self?.waitForAuthorizationDecision() ?? false
            }
            guard granted == true else { return nil }
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            return nil
        }

        let coordinate = await withTimeout(nil) { [weak self] in
            await self?.requestLocationOnce()
        } ?? nil
        cachedCoordinate = coordinate
        return coordinate
    }

    /// Races `operation` against `requestTimeoutSeconds`, returning `fallback`
    /// if the timeout wins. Mirrors the web version's 8000ms setTimeout race.
    private func withTimeout<T>(_ fallback: T, _ operation: @escaping () async -> T) async -> T {
        await withTaskGroup(of: T.self) { group in
            group.addTask { await operation() }
            group.addTask { [requestTimeoutSeconds] in
                try? await Task.sleep(nanoseconds: requestTimeoutSeconds * 1_000_000_000)
                return fallback
            }
            let result = await group.next() ?? fallback
            group.cancelAll()
            return result
        }
    }

    private func waitForAuthorizationDecision() async -> Bool {
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocationOnce() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard let continuation = self.authorizationContinuation else { return }
            self.authorizationContinuation = nil
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                // Still awaiting the user's actual choice - leave the
                // continuation pending for the next authorization callback.
                self.authorizationContinuation = continuation
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            self.locationContinuation?.resume(returning: coordinate)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }
}
