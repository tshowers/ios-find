import Combine
import CoreLocation
import SwiftUI
import UIKit

/// A place "Point" can aim at. Without coordinates, the address is looked up
/// on the device (CLGeocoder).
struct PointTarget: Hashable {
    let name: String
    let address: String
    var latitude: Double?
    var longitude: Double?
}

/// "Point": a big arrow that turns toward a place as the phone moves, with
/// the live distance. Compass (heading) + position from CoreLocation; with
/// several locations it aims at the nearest. Nothing leaves the device.
@MainActor
final class PlacePointer: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case locating
        case ready
        case noLocation
        case placeNotFound
    }

    @Published private(set) var status: Status = .locating
    @Published private(set) var target: PointTarget?
    @Published private(set) var distanceMeters: Double?
    /// Arrow rotation in degrees, accumulated so it never spins the long way
    /// round when the heading crosses north.
    @Published private(set) var arrowDegrees: Double = 0
    @Published private(set) var hasCompass = CLLocationManager.headingAvailable()
    @Published private(set) var isAligned = false

    private let manager = CLLocationManager()
    private var targets: [PointTarget]
    private var here: CLLocation?
    private var heading: Double?

    init(targets: [PointTarget]) {
        self.targets = targets
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 2
        manager.headingOrientation = .portrait
    }

    func start() {
        Task { await resolveCoordinates() }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .noLocation
        default:
            begin()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func begin() {
        manager.startUpdatingLocation()
        if hasCompass { manager.startUpdatingHeading() }
    }

    /// Targets with only an address get coordinates from Apple's geocoder.
    private func resolveCoordinates() async {
        let geocoder = CLGeocoder()
        for index in targets.indices where targets[index].latitude == nil && !targets[index].address.isEmpty {
            if let location = try? await geocoder.geocodeAddressString(targets[index].address).first?.location {
                targets[index].latitude = location.coordinate.latitude
                targets[index].longitude = location.coordinate.longitude
            }
        }
        if !targets.contains(where: { $0.latitude != nil }) {
            status = .placeNotFound
        }
        update()
    }

    private func update() {
        guard status != .noLocation, status != .placeNotFound, let here else { return }
        let located = targets.compactMap { target -> (PointTarget, CLLocation)? in
            guard let latitude = target.latitude, let longitude = target.longitude else { return nil }
            return (target, CLLocation(latitude: latitude, longitude: longitude))
        }
        guard let nearest = located.min(by: { here.distance(from: $0.1) < here.distance(from: $1.1) }) else { return }
        target = nearest.0
        distanceMeters = here.distance(from: nearest.1)
        status = .ready

        guard let heading else { return }
        let relative = Self.bearing(from: here.coordinate, to: nearest.1.coordinate) - heading
        var delta = (relative - arrowDegrees).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        arrowDegrees += delta

        let offCenter = abs(relative.truncatingRemainder(dividingBy: 360))
        let aligned = min(offCenter, 360 - offCenter) < 10
        if aligned && !isAligned {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isAligned = aligned
    }

    /// Compass bearing (degrees from true north) from one point to another.
    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: begin()
            case .denied, .restricted: self.status = .noLocation
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            here = location
            update()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            heading = degrees
            update()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

struct PointToPlaceView: View {
    let title: String
    let mapsURL: URL?
    @StateObject private var pointer: PlacePointer
    @ObservedObject private var activity = FindActivityMonitor.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(title: String, targets: [PointTarget], mapsURL: URL?) {
        self.title = title
        self.mapsURL = mapsURL
        _pointer = StateObject(wrappedValue: PlacePointer(targets: targets))
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(Theme.font(16, weight: .semibold))
                    .foregroundStyle(Theme.blueInk)
            }
            Text(title)
                .font(Theme.font(22, weight: .bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            if let target = pointer.target, target.name != title, !target.name.isEmpty {
                Text(target.name)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.muted)
            }

            Spacer(minLength: 0)
            arrow
            Spacer(minLength: 0)

            Text(distanceText)
                .font(Theme.font(34, weight: .bold))
                .foregroundStyle(Theme.text)
            if let meters = pointer.distanceMeters,
               let walk = activity.walkingTime(for: String(format: "%.1f mi", meters / 1609.34)) {
                Text(walk)
                    .font(Theme.font(17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Text(hint)
                .font(Theme.font(15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            if let mapsURL {
                Button {
                    openURL(mapsURL)
                } label: {
                    Label("Directions", systemImage: "location.fill")
                        .font(Theme.font(17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { pointer.start() }
        .onDisappear { pointer.stop() }
    }

    private var arrow: some View {
        ZStack {
            Circle()
                .fill(pointer.isAligned ? Theme.tGreen : Theme.surface)
                .frame(width: 240, height: 240)
            Image(systemName: pointer.status == .ready && pointer.hasCompass ? "location.north.fill" : "mappin.and.ellipse")
                .font(.system(size: 110, weight: .regular))
                .foregroundStyle(pointer.isAligned ? Theme.tGreenFg : Theme.blue)
                .rotationEffect(.degrees(pointer.hasCompass ? pointer.arrowDegrees : 0))
                .animation(.easeOut(duration: 0.2), value: pointer.arrowDegrees)
        }
        .accessibilityLabel(hint)
    }

    private var distanceText: String {
        guard let meters = pointer.distanceMeters else { return pointer.status == .locating ? "…" : "" }
        let miles = meters / 1609.34
        if miles < 0.1 { return "\(Int((meters * 3.28084 / 10).rounded()) * 10) ft" }
        return String(format: "%.1f mi", miles)
    }

    private var hint: String {
        switch pointer.status {
        case .locating:
            return "Finding you…"
        case .noLocation:
            return "Location is off for Find. Turn it on in Settings to point the way."
        case .placeNotFound:
            return "Couldn't find this place on the map."
        case .ready:
            if !pointer.hasCompass { return "This device has no compass, so here's the distance." }
            return pointer.isAligned ? "Straight ahead" : "Turn until the arrow points up"
        }
    }
}
