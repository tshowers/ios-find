import SwiftUI

/// Round 4 types 2–4 (web: find-business-card): a store (green), restaurant
/// (yellow) or local service (violet). Facts come from Google Places, the
/// nearest location to the phone's position; sales, dishes and services from
/// the business's own website (details); a store's sale pages (sale).
struct EntityBusinessCard: View {
    let entity: FindEntity
    let fetch: @Sendable (String) async -> Data?
    @StateObject private var sections = EntitySections()

    private var place: FindPlaceSection? { sections.value("place", as: FindPlaceSection.self) }
    private var details: FindPlaceDetails? { sections.value("details", as: FindPlaceDetails.self) }
    private var sale: FindSaleSection? { sections.value("sale", as: FindSaleSection.self) }
    private var summary: FindEntitySummary? { sections.value("summary", as: FindEntitySummary.self) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // "Closes in 12 min" counts down without a refresh.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                if let status = status(at: context.date) { EntityStatusPill(text: status.text, tone: status.tone) }
            }

            if sections.isLoading("place") {
                EntitySkeleton(height: 200, radius: 20)
            } else {
                EntityHeroImage(url: place?.photoUrl)
            }

            EntityIdentityRow(name: entity.name, meta: meta) {
                EntityThumb(url: entity.logoUrl, fallback: entity.name)
            }

            if sections.isLoading("place") {
                EntitySkeleton(height: 40, radius: 20)
            } else {
                EntityKeyFacts(facts: keyFacts)
            }

            EntitySummaryBlock(summary: summary, isLoading: sections.isLoading("summary"))

            VStack(spacing: 10) {
                if !detailRows.isEmpty || !(place?.serves ?? []).isEmpty {
                    EntityDisclosure(title: detailsTitle, preview: detailRows.prefix(2).map(\.name).joined(separator: " · ").ifEmpty((place?.serves ?? []).joined(separator: " · "))) {
                        if let serves = place?.serves, !serves.isEmpty {
                            EntityTagChips(tags: serves.map { FindEntityTag(text: $0, tone: "plain") }).padding(.bottom, 8)
                        }
                        EntityRows(rows: detailRows)
                    }
                } else if sections.isLoading("details") {
                    EntitySkeleton()
                }

                if let items = sale?.items, !items.isEmpty {
                    EntityDisclosure(title: "Shop the sale", preview: items.prefix(2).map(\.title).joined(separator: " · ")) {
                        ForEach(items, id: \.self) { item in
                            EntityRow(name: item.title, value: item.price, sub: item.was.map { "was \($0)" }, url: item.url)
                        }
                    }
                }

                if let week = place?.hoursWeek, !week.isEmpty, let nearest = place?.nearest {
                    let today = todayIndex(nearest)
                    EntityDisclosure(title: "Hours", preview: week.indices.contains(today) ? "Today \(shortHours(week[today].hours))" : "") {
                        ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                            EntityRow(name: day.day, value: shortHours(day.hours), highlight: index == today)
                        }
                    }
                } else if sections.isLoading("place") {
                    EntitySkeleton()
                }

                if let nearest = place?.nearest {
                    EntityDisclosure(title: "Location", preview: [nearest.street, nearest.milesText].compactMap { $0 }.joined(separator: " · ")) {
                        EntityRow(name: "Address", sub: nearest.address)
                        if let phone = nearest.phone, !phone.isEmpty {
                            EntityRow(name: "Phone", value: phone, url: "tel:\(phone.filter { $0.isNumber || $0 == "+" })")
                        }
                        if let miles = nearest.milesText { EntityRow(name: "Distance", value: miles) }
                        if let about = place?.about, !about.isEmpty {
                            Text(about).font(Theme.font(14)).foregroundStyle(Theme.muted).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let others = place?.others, !others.isEmpty {
                    EntityDisclosure(title: "Other locations", preview: "\(others.count) more · closest \(others[0].milesText ?? others[0].city ?? "")") {
                        ForEach(others, id: \.self) { location in
                            EntityRow(name: location.street, value: location.milesText ?? location.city, sub: openText(location), url: location.directionsUrl)
                        }
                    }
                }
            }

            EntityActionTiles(actions: actions)
        }
        .task {
            await sections.load(entity.type == "store" ? ["place", "details", "sale", "summary"] : ["place", "details", "summary"], fetch: fetch)
        }
    }

    // MARK: Words

    private var meta: String {
        guard let place else { return entity.label ?? "" }
        return [place.category ?? entity.label, [place.nearest.street, place.nearest.city].compactMap { $0 }.joined(separator: ", ")]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var keyFacts: [FindKeyFact] {
        guard let place else { return [] }
        let firstSale = details?.sales?.first
        let firstPrice = details?.services?.first { !($0.price ?? "").isEmpty }
        return [
            place.rating.map { FindKeyFact(value: "★ \(String(format: "%.1f", $0.value))", label: "(\($0.count.formatted()))") },
            place.nearest.milesText.map { FindKeyFact(value: $0, label: "away") } ?? place.nearest.city.map { FindKeyFact(value: $0, label: "") },
            entity.type == "restaurant" ? place.priceLevel.flatMap { $0.isEmpty ? nil : FindKeyFact(value: $0, label: "price") } : nil,
            firstSale.map { FindKeyFact(value: ($0.discount ?? "").ifEmpty($0.title), label: ($0.discount ?? "").isEmpty ? "on sale" : $0.title) },
            firstPrice.map { FindKeyFact(value: $0.price ?? "", label: $0.name) },
        ].compactMap { $0 }.filter { !$0.value.isEmpty }
    }

    private var detailsTitle: String {
        entity.type == "store" ? "On sale" : entity.type == "restaurant" ? "Menu" : "Services"
    }

    private var detailRows: [FindListRow] {
        guard let details else { return [] }
        if let sales = details.sales {
            return sales.map { FindListRow(name: $0.title, value: $0.discount, sub: [$0.detail, $0.endsAt.map { "ends \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "), url: nil) }
        }
        if let dishes = details.popular {
            return dishes.map { FindListRow(name: $0.name, value: $0.price, sub: $0.description, url: nil) }
        }
        return (details.services ?? []).map { FindListRow(name: $0.name, value: $0.price, sub: $0.duration, url: nil) }
    }

    private var actions: [EntityAction] {
        let website = place?.website ?? entity.website
        let location = place?.nearest
        let call = location?.phone.flatMap { phone in EntityAction(entity.type == "service" ? "Call now" : "Call", systemImage: "phone.fill", url: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") }
        let menu = details?.menuUrl.flatMap { $0 == website ? nil : EntityAction("Menu", systemImage: "book", url: $0) }
        let site = EntityAction(
            menu != nil ? "Order" : entity.type == "store" ? "Shop" : entity.type == "restaurant" ? "Menu" : "Website",
            systemImage: entity.type == "store" || menu != nil ? "bag" : entity.type == "restaurant" ? "fork.knife" : "globe",
            url: website
        )
        let directions = EntityAction("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill", url: location?.directionsUrl)
        let maps = EntityAction("Maps", systemImage: "map", url: location?.mapsUrl)
        let ordered: [EntityAction?] = entity.type == "service" ? [call, site, directions, maps]
            : entity.type == "restaurant" && menu != nil ? [menu, site, directions, call]
            : [site, directions, call, maps]
        return ordered.compactMap { $0 }
    }

    // MARK: Open, closing soon, closed (in the place's own time zone)

    private func status(at now: Date) -> (text: String, tone: String)? {
        guard let location = place?.nearest, let openNow = location.openNow else { return nil }
        if location.open24Hours == true {
            return (entity.type == "service" ? "Available now · open 24 hours" : "Open 24 hours", "green")
        }
        if openNow {
            if let closes = FindEntityFormat.date(location.nextCloseTime) {
                let minutes = Int(closes.timeIntervalSince(now) / 60)
                if minutes > 0 && minutes <= 60 {
                    return ("Closes in \(minutes) min · open until \(placeTime(closes, location))", "yellow")
                }
                return ("Open now · until \(placeTime(closes, location))", "green")
            }
            return ("Open now", "green")
        }
        if let opens = FindEntityFormat.date(location.nextOpenTime) {
            let sameDay = placeCalendar(location).isDate(opens, inSameDayAs: now)
            let when = sameDay ? placeTime(opens, location) : "\(FindEntityFormat.format(opens, "EEE", timeZone: placeZone(location))) \(placeTime(opens, location))"
            return ("Closed · opens \(when)", "plain")
        }
        return ("Closed", "plain")
    }

    private func placeZone(_ location: FindPlaceLocation) -> TimeZone {
        location.utcOffsetMinutes.flatMap { TimeZone(secondsFromGMT: $0 * 60) } ?? .current
    }

    private func placeCalendar(_ location: FindPlaceLocation) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = placeZone(location)
        return calendar
    }

    /// "9 PM", "9:30 PM".
    private func placeTime(_ date: Date, _ location: FindPlaceLocation) -> String {
        FindEntityFormat.format(date, "jmm", timeZone: placeZone(location)).replacingOccurrences(of: ":00", with: "")
    }

    /// Monday = 0, as Places lists the week.
    private func todayIndex(_ location: FindPlaceLocation) -> Int {
        (placeCalendar(location).component(.weekday, from: Date()) + 5) % 7
    }

    /// "10:00 AM – 9:00 PM" -> "10 AM – 9 PM".
    private func shortHours(_ hours: String) -> String {
        hours.replacingOccurrences(of: #":00(?=\s?[AP]M)"#, with: "", options: .regularExpression)
    }

    private func openText(_ location: FindPlaceLocation) -> String {
        if location.open24Hours == true { return "Open 24 hours" }
        guard let open = location.openNow else { return "" }
        return open ? "Open now" : "Closed"
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
