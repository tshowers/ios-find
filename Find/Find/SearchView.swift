import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @ObservedObject private var awardsService: FindAwardsService
    @ObservedObject private var watchStore: FindWatchStore
    @StateObject private var tiltNav = TiltNavigationService()
    @State private var selectedTab: BottomTab = .home
    @State private var showingShareSheet = false
    @State private var showingSearchScreen = true
    @State private var enteringNewSearch = false
    @State private var resultSearchQuery = ""
    @State private var highlightedPill = ""
    @State private var activePill = ""
    @State private var conversionAmountText = ""
    @State private var locationSettingBlocked = false
    @State private var conversionInputUnit = ""
    @State private var conversionOutputUnit = ""
    @State private var conversionRate: Double?
    @State private var conversionRateUpdatedAt = ""
    @State private var conversionSource = ""
    @State private var conversionBaseInputUnit = ""
    @State private var conversionBaseOutputUnit = ""
    @State private var conversionBaseRate: Double?
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.openURL) private var openURL

    private enum BottomTab: String, CaseIterable {
        case home = "HOME"
        case grid = "ALL"
        case history = "HISTORY"
        case info = "INFO"
        case awards = "AWARDS"
        case share = "SHARE"

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .grid: return "square.grid.2x2"
            case .history: return "clock"
            case .info: return "info.circle"
            case .awards: return "rosette"
            case .share: return "square.and.arrow.up"
            }
        }
    }

    private struct ConversionUnitOption: Identifiable {
        let value: String
        let label: String
        var id: String { value }
    }

    private struct FindQuickAction: Identifiable {
        let label: String
        let systemImage: String
        let background: Color
        let foreground: Color
        let query: String
        var disabled = false
        var id: String { label }
    }

    // Mirrors the web app's find-home.component.ts `quickActions` array -
    // same labels, order, and queries, tinted with the logo colour pairs.
    private static let quickActions: [FindQuickAction] = [
        FindQuickAction(label: "News", systemImage: "newspaper", background: Theme.tPink, foreground: Theme.tPinkFg, query: "Today's News"),
        FindQuickAction(label: "Weather", systemImage: "sun.max", background: Theme.tBlue, foreground: Theme.tBlueFg, query: "weather"),
        FindQuickAction(label: "Sports", systemImage: "trophy", background: Theme.tCyan, foreground: Theme.tCyanFg, query: "sports news"),
        FindQuickAction(label: "Conversion", systemImage: "arrow.left.arrow.right", background: Theme.tViolet, foreground: Theme.tVioletFg, query: "100 USD to EUR"),
        FindQuickAction(label: "Restaurants", systemImage: "fork.knife", background: Theme.tYellow, foreground: Theme.tYellowFg, query: "restaurants near me"),
        FindQuickAction(label: "Events", systemImage: "calendar", background: Theme.surface, foreground: Theme.muted, query: "events near me", disabled: true),
    ]

    init(viewModel: SearchViewModel, awardsService: FindAwardsService, watchStore: FindWatchStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.awardsService = awardsService
        self.watchStore = watchStore
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .home:
                        homeView(screenWidth: geometry.size.width)
                    case .grid:
                        gridView(screenWidth: geometry.size.width)
                    case .history:
                        historyView(screenWidth: geometry.size.width)
                    case .info:
                        infoView(screenWidth: geometry.size.width)
                    case .awards:
                        awardsView(screenWidth: geometry.size.width)
                    case .share:
                        shareView(screenWidth: geometry.size.width)
                    }
                }
                if showStickyPills {
                    footerStack(screenWidth: geometry.size.width, bottomInset: geometry.safeAreaInsets.bottom)
                } else {
                    bottomBar(screenWidth: geometry.size.width, bottomInset: geometry.safeAreaInsets.bottom)
                }

                if let unlocked = viewModel.pendingAwardUnlock {
                    AwardUnlockView(
                        award: unlocked,
                        unlockedCount: awardsService.unlockedCount,
                        totalCount: awardsService.totalCount
                    ) {
                        viewModel.dismissAwardUnlock()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            // Runs down through the bottom safe area to the screen edge: the
            // bottom bar already pads itself clear of the home indicator
            // (bottomInset), so stopping at the safe area as well left that
            // inset reserved twice - a band of empty chrome under the icons.
            .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom, alignment: .top)
            .padding(.bottom, footerReservedHeight(bottomInset: geometry.safeAreaInsets.bottom))
            .background(Theme.background)
            .overlay(alignment: .top) {
                #if DEBUG
                if tiltNav.isActive {
                    tiltDebugReadout
                        .padding(.horizontal, 12)
                        // Clears the result shelf bar (back/forward chevrons
                        // + title), which sits right at the top of the home
                        // view - the readout used to overlap and hide it.
                        .padding(.top, geometry.safeAreaInsets.top + 64)
                }
                #endif
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Find", isPresented: errorPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = currentShareURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: tiltNav.tilt) { _, newValue in
            handleTilt(newValue)
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .history { Task { await watchStore.refresh(markSeen: true) } }
        }
        // A tapped Watch notification opens its search (also on a cold launch).
        .onReceive(NotificationCenter.default.publisher(for: .findOpenWatchedQuery)) { _ in
            openPendingWatchQuery()
        }
        .onAppear { openPendingWatchQuery() }
        .onDisappear {
            tiltNav.disable()
        }
    }

    private func openPendingWatchQuery() {
        guard let query = AppDelegate.pendingWatchQuery else { return }
        AppDelegate.pendingWatchQuery = nil
        selectedTab = .home
        Task {
            await viewModel.runHistorySearch(query)
            if viewModel.searchResponse != nil {
                showingSearchScreen = false
            }
        }
    }

    // TiltNavigationService now detects a flick (fast + far enough), not a
    // sustained pose, and briefly reports the direction before resetting
    // itself to .center - so the flick itself is the confirmation, and this
    // fires the drill-down immediately rather than waiting out a hold timer.
    private func handleTilt(_ tilt: TiltDirection) {
        let indexByDirection: [TiltDirection: Int] = [.left: 0, .right: 1, .up: 2, .down: 3]
        guard let index = indexByDirection[tilt], currentPills.indices.contains(index) else {
            highlightedPill = ""
            return
        }

        let pill = currentPills[index]
        highlightedPill = pill
        activePill = pill

        selectedTab = .home
        Task {
            await viewModel.runDrillDown(from: baseQuery, pill: pill)
            if viewModel.searchResponse != nil {
                showingSearchScreen = false
            }
        }
    }

    private func homeView(screenWidth: CGFloat) -> some View {
        Group {
            if showingSearchScreen || (viewModel.searchResponse == nil && !enteringNewSearch) {
                searchHomeView(screenWidth: screenWidth)
            } else {
                resultHomeView(screenWidth: screenWidth)
            }
        }
        .background(Theme.cardBackground)
    }

    // Home (3i): logo + wordmark, a 54pt search field with a full-width Find
    // button under it, and a 3x2 grid of tinted quick-search tiles.
    private func searchHomeView(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    findLogo
                    Text("Find")
                        .font(Theme.font(44, weight: .bold))
                        .tracking(-1.76)
                        .foregroundStyle(Theme.text)
                }
                .padding(.top, 96)

                VStack(spacing: 10) {
                    searchBar

                    Button {
                        runSearchFromHome(viewModel.query)
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Find")
                                    .font(Theme.font(17, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                quickActionsGrid

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 560)
            .frame(width: screenWidth)
        }
        .background(Theme.bg)
    }

    private var quickActionsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(Self.quickActions) { action in
                Button {
                    runSearchFromHome(action.query)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 24, weight: .medium))
                        Text(action.label)
                            .font(Theme.font(14, weight: .bold))
                        if action.disabled {
                            Text("Coming soon")
                                .font(Theme.font(10, weight: .semibold))
                                .padding(.top, -4)
                        }
                    }
                    .foregroundStyle(action.foreground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .background(action.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .opacity(action.disabled ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(action.disabled || viewModel.isLoading)
                .accessibilityLabel(action.disabled ? "\(action.label) coming soon" : "Search \(action.label)")
            }
        }
    }

    private func runSearchFromHome(_ query: String) {
        isSearchFieldFocused = false
        viewModel.query = query
        Task {
            await viewModel.runSearch()
            if viewModel.searchResponse != nil {
                showingSearchScreen = false
            }
        }
    }

    private func resultHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultSearchBar

            if viewModel.searchResponse != nil {
                if isWeatherMode {
                    weatherHomeView(screenWidth: screenWidth)
                } else if isConversionMode {
                    conversionHomeView(screenWidth: screenWidth)
                } else if let instant = viewModel.searchResponse?.instant, isInstantMode {
                    instantHomeView(instant, screenWidth: screenWidth)
                } else {
                    answerHomeView(screenWidth: screenWidth)
                }
            } else if viewModel.isLoading {
                ProgressView("Finding the strongest result…")
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .background(Theme.bg)
    }

    private func weatherHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultPager(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let weather = viewModel.searchResponse?.weather {
                        weatherCard(weather)
                        if let forecast = weather.forecast, !forecast.isEmpty {
                            forecastList(forecast)
                        }
                        feedbackRow(meta: weatherMeta(weather))
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .frame(maxWidth: 720)
                .frame(width: screenWidth)
                .padding(.bottom, 150)
            }
        }
    }

    // An exact answer Find works out itself (the web's .find-instant card).
    private func instantHomeView(_ answer: FindInstantAnswer, screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultPager(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(answer.title)
                            .font(Theme.font(15, weight: .semibold))
                        Text(answer.value)
                            .font(Theme.font(44, weight: .heavy))
                            .tracking(-0.8)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                            .textSelection(.enabled)
                        if let detail = answer.detail, !detail.isEmpty {
                            Text(detail)
                                .font(Theme.font(15))
                                .opacity(0.85)
                        }
                    }
                    .foregroundStyle(Theme.tVioletFg)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.tViolet, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Button {
                        UIPasteboard.general.string = "\(answer.title): \(answer.value)"
                    } label: {
                        Label("Copy result", systemImage: "doc.on.doc")
                            .font(Theme.font(14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.blueInk)

                    feedbackRow(meta: "Worked out by Find")
                        .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .frame(maxWidth: 560)
                .frame(width: screenWidth)
            }
            .padding(.bottom, 150)
        }
    }

    private func conversionHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultPager(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                if let conversion = viewModel.searchResponse?.conversion {
                    VStack(alignment: .leading, spacing: 8) {
                        conversionCards
                        conversionRateLine(conversion)
                        conversionKeypad
                        feedbackRow(meta: conversionSource.isEmpty ? nil : "Source: \(conversionSource)")
                            .padding(.top, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .frame(maxWidth: 560)
                    .frame(width: screenWidth)
                }
            }
            .padding(.bottom, 150)
        }
        .onAppear { syncConversionState() }
        .onChange(of: viewModel.searchResponse?.query) { _, _ in syncConversionState() }
    }

    // Conversion (3k): From and To stacked, with the swap button over the seam.
    private var conversionCards: some View {
        VStack(spacing: 8) {
            conversionField(title: "From", isOutput: false)
            conversionField(title: "To", isOutput: true)
        }
        .overlay(alignment: .trailing) {
            Button {
                swapConversion()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.blue, in: Circle())
                    .padding(4)
                    .background(Theme.bg, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 116)
            .accessibilityLabel("Swap conversion units")
        }
    }

    @ViewBuilder
    private func conversionRateLine(_ conversion: FindConversionResult) -> some View {
        if conversion.category == .currency, let rate = conversionRate {
            let updated = FindFormat.shortDateTime(conversionRateUpdatedAt).map { " · Updated \($0)" } ?? ""
            Text("1 \(conversionInputUnit) = \(formattedConversionValue(rate, maximumFractionDigits: 6)) \(conversionOutputUnit)\(updated)")
                .font(Theme.font(13))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
        } else if conversion.category == .currency {
            Text("A live exchange rate is not available right now.")
                .font(Theme.font(13))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
        }
    }

    // 3x4 keypad: 1-9, ".", "0", and backspace (long-press clears).
    private var conversionKeypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { digit in
                keypadKey { appendConversionDigit(digit) } label: { Text(digit) }
            }
            keypadKey { appendConversionDecimal() } label: { Text(".") }
            keypadKey { appendConversionDigit("0") } label: { Text("0") }
            Image(systemName: "delete.left")
                .font(Theme.font(20, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture { deleteConversionDigit() }
                .onLongPressGesture(minimumDuration: 0.5) { conversionAmountText = "0" }
                .accessibilityElement()
                .accessibilityLabel("Backspace")
                .accessibilityHint("Hold to clear")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { deleteConversionDigit() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calculator keypad")
    }

    private func keypadKey<Label: View>(_ action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .font(Theme.font(22, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func appendConversionDigit(_ digit: String) {
        if conversionAmountText == "0" { conversionAmountText = "" }
        conversionAmountText.append(digit)
    }

    private func appendConversionDecimal() {
        guard !conversionAmountText.contains(".") else { return }
        if conversionAmountText.isEmpty { conversionAmountText = "0" }
        conversionAmountText.append(".")
    }

    private func deleteConversionDigit() {
        guard !conversionAmountText.isEmpty else { return }
        conversionAmountText.removeLast()
        if conversionAmountText.isEmpty || conversionAmountText == "-" { conversionAmountText = "0" }
    }

    private func conversionField(title: String, isOutput: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(12, weight: .semibold))
                    .foregroundStyle(isOutput ? Theme.tVioletFg : Theme.muted)

                if isOutput {
                    Text(formattedConversionOutput)
                        .font(Theme.font(36, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(Theme.tVioletFg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    TextField("0", text: $conversionAmountText)
                        .keyboardType(.decimalPad)
                        .font(Theme.font(36, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(Theme.text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(conversionUnitOptions) { option in
                    Button(option.label) {
                        if isOutput { conversionOutputUnit = option.value } else { conversionInputUnit = option.value }
                        refreshConversionRate()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(conversionUnitShort(isOutput ? conversionOutputUnit : conversionInputUnit))
                    Image(systemName: "chevron.down")
                        .font(Theme.font(10, weight: .bold))
                }
                .font(Theme.font(15, weight: .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Theme.bg, in: Capsule())
            }
            .accessibilityLabel(isOutput ? "Destination unit" : "Source unit")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(isOutput ? Theme.tViolet : Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Short unit shown in the unit pill: "USD", "°F", "km".
    private func conversionUnitShort(_ unit: String) -> String {
        if conversionCategory == .temperature { return unit == "K" ? "K" : "°\(unit)" }
        let shortNames = [
            "l": "L", "floz": "fl oz", "kph": "km/h", "mps": "m/s", "knot": "kn", "sqin": "sq in", "sqft": "sq ft",
            "sqm": "m²", "sqkm": "km²", "sqmi": "sq mi", "acre": "ac", "tonne": "t",
        ]
        return shortNames[unit] ?? unit
    }

    // Weather (3j): compact blue card, high/low and stats beside the temperature.
    private func weatherCard(_ weather: FindWeatherInfo) -> some View {
        let symbol = findWeatherSymbol(weather.description.isEmpty ? weather.condition : weather.description)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.postalCode.map { "\(weather.location) \($0)" } ?? weather.location)
                        .font(Theme.font(18, weight: .bold))
                    Text(weather.description.isEmpty ? weather.condition : weather.description)
                        .font(Theme.font(15))
                }
                Spacer()
                Image(systemName: symbol.name)
                    .font(.system(size: 50))
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .bottom) {
                Text("\(Int(weather.tempF.rounded()))°")
                    .font(Theme.font(96, weight: .bold))
                    .tracking(-5.8)
                    .lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let highLow = highLowText(weather.highF, weather.lowF) {
                        Text(highLow)
                    }
                    Text("Feels \(Int(weather.feelsLikeF.rounded()))° · \(Int(weather.humidity))% · \(Int(weather.windMph)) mph")
                }
                .font(Theme.font(14, weight: .semibold))
                .padding(.bottom, 10)
            }
        }
        .foregroundStyle(Theme.tBlueFg)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.tBlue, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func highLowText(_ high: Double?, _ low: Double?) -> String? {
        let parts = [high.map { "H \(Int($0.rounded()))°" }, low.map { "L \(Int($0.rounded()))°" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func forecastList(_ forecast: [FindWeatherForecastDay]) -> some View {
        let temps = forecast.flatMap { [$0.lowF, $0.highF] }.compactMap { $0 }
        let weekMin = temps.min() ?? 0
        let range = (temps.max() ?? 0) - weekMin
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(forecast.count)-day forecast")
                .font(Theme.font(15, weight: .bold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            ForEach(Array(forecast.enumerated()), id: \.offset) { _, day in
                forecastRow(day, weekMin: weekMin, range: range)
            }
        }
    }

    // Day, icon, low, range bar, high - the description is dropped on phones.
    private func forecastRow(_ day: FindWeatherForecastDay, weekMin: Double, range: Double) -> some View {
        let condition = day.description?.isEmpty == false ? day.description! : day.condition
        let symbol = findWeatherSymbol(condition)
        return HStack(spacing: 10) {
            Text(forecastDayLabel(day))
                .font(Theme.font(15, weight: .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(width: 52, alignment: .leading)
            Image(systemName: symbol.name)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 18))
                .foregroundStyle(symbol.color)
                .frame(width: 26)
                .accessibilityLabel(condition)
            Text(day.lowF.map { "\(Int($0.rounded()))°" } ?? "")
                .font(Theme.font(15))
                .foregroundStyle(Theme.muted)
                .frame(width: 34, alignment: .trailing)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2)
                    if let low = day.lowF, let high = day.highF {
                        let left = range > 0 ? (low - weekMin) / range : 0
                        let width = range > 0 ? max(0.04, (high - low) / range) : 1
                        Capsule().fill(Theme.cyan)
                            .frame(width: proxy.size.width * width)
                            .offset(x: proxy.size.width * left)
                    }
                }
            }
            .frame(height: 6)
            Text(day.highF.map { "\(Int($0.rounded()))°" } ?? "")
                .font(Theme.font(15, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 34, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// "Saturday" -> "Sat", so day names fit the narrow forecast column.
    private func forecastDayLabel(_ day: FindWeatherForecastDay) -> String {
        let label = day.label.isEmpty ? day.date : day.label
        return label.replacingOccurrences(
            of: #"\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*day\b"#,
            with: "$1",
            options: .regularExpression
        )
    }

    private func weatherMeta(_ weather: FindWeatherInfo) -> String? {
        var parts: [String] = []
        if let updated = FindFormat.shortTime(weather.updatedAt) { parts.append("Updated \(updated)") }
        if let lat = weather.latitude, let lon = weather.longitude {
            parts.append(String(format: "%.4f, %.4f", lat, lon))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func feedbackRow(meta: String?) -> some View {
        FindFeedbackRow(
            store: viewModel.feedbackStore,
            query: viewModel.searchResponse?.query ?? viewModel.query,
            queryType: viewModel.searchResponse?.queryType ?? .entity,
            meta: meta
        )
    }

    private func answerHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultPager(screenWidth: screenWidth)

            if viewModel.searchResponse?.queryType == .local {
                OpenNowButton(isOn: viewModel.isOpenNowSearch) {
                    Task { await viewModel.toggleOpenNow() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            Group {
                if let response = viewModel.searchResponse {
                    if results.isEmpty {
                        // A pure Q&A answer with no ranked source still has
                        // exactly one page to show - nothing to swipe between,
                        // and the shelf chevrons are already disabled for
                        // this case (see resultShelf).
                        ResultPageView(response: response, pageIndex: hasLeadingAnswer ? -1 : 0, screenWidth: screenWidth, feedbackStore: viewModel.feedbackStore, followupActions: followupActions, watchStore: watchStore)
                    } else {
                        FindResultPagerView(response: response, currentIndex: pagingIndexBinding, screenWidth: screenWidth, feedbackStore: viewModel.feedbackStore, followupActions: followupActions, watchStore: watchStore, hasLeadingAnswer: hasLeadingAnswer)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Theme.background.opacity(0.72)
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.15)
                            Text("Refining result…")
                                .font(Theme.font(15, weight: .semibold))
                                .foregroundStyle(Theme.subtext)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .background(Theme.cardBackground.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    }
                }
            }
        }
    }

    // The source of truth for "which page is showing" is `viewModel.
    // selectedResult` (a value, not an index - see `selectedResultIndex`),
    // so this bridges it to the plain `Binding<Int>` UIPageViewController
    // wants: reads resolve the selected result's index, writes re-select
    // the result at that index. A swipe lands here via the pager's
    // coordinator's `didFinishAnimating`; a shelf-chevron tap already calls
    // `viewModel.select(...)` directly, and `FindResultPagerView` notices
    // the mismatch next render and animates the same slide to it.
    private var pagingIndexBinding: Binding<Int> {
        Binding(
            get: { viewModel.viewingGroundedAnswer ? -1 : selectedResultIndex },
            set: { newIndex in
                if newIndex == -1 {
                    viewModel.viewingGroundedAnswer = true
                    return
                }
                guard results.indices.contains(newIndex) else { return }
                viewModel.select(results[newIndex])
            }
        )
    }

    // Pager (2i/3l): 44pt Back/Next circles around the progress segments and
    // "N of M · See all". Weather and conversion are a single result, so they
    // get Back plus a centred label instead.
    private func resultPager(screenWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button {
                goToPreviousResult()
            } label: {
                FindPagerCircle(systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedResultIndex == 0 && !canGoBackToAnswer ? "Back to search" : "Previous result")

            Group {
                if isSingleResultMode {
                    Text(pagerCenterLabel)
                        .font(Theme.font(15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                } else {
                    VStack(spacing: 6) {
                        if results.count > 1 {
                            FindProgressSegments(
                                count: results.count,
                                current: viewModel.viewingGroundedAnswer ? -1 : selectedResultIndex
                            )
                        }
                        if !results.isEmpty {
                        HStack(spacing: 0) {
                            if viewModel.viewingGroundedAnswer {
                                Text("Results").foregroundStyle(Theme.muted)
                            } else {
                                Text("\(selectedResultIndex + 1)").bold().foregroundStyle(Theme.text)
                                Text(" of \(results.count)").foregroundStyle(Theme.muted)
                            }
                            if results.count > 1 {
                                Text(" · ").foregroundStyle(Theme.muted)
                                Button("See all") { selectedTab = .grid }
                                    .buttonStyle(.plain)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.blueInk)
                            }
                        }
                        .font(Theme.font(12))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if isSingleResultMode {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Button {
                    goToNextResult()
                } label: {
                    FindPagerCircle(systemImage: "chevron.right")
                        .opacity(canGoToNextResult ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canGoToNextResult)
                .accessibilityLabel("Next result")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(width: screenWidth)
        .background(Theme.bg)
    }

    // Weather, conversion and movie answers are one result: Back plus a label.
    private var isSingleResultMode: Bool {
        isWeatherMode || isConversionMode || isMovieMode || isInstantMode
    }

    private var isInstantMode: Bool {
        viewModel.searchResponse?.queryType == .instant && viewModel.searchResponse?.instant != nil
    }

    private var isMovieMode: Bool {
        viewModel.searchResponse?.movie != nil
    }

    private var pagerCenterLabel: String {
        if isWeatherMode { return "Weather" }
        if isMovieMode { return "Movie" }
        if isInstantMode { return viewModel.searchResponse?.instant?.label ?? "Result" }
        return conversionCategory == .currency ? "Currency conversion" : "Unit conversion"
    }

    // All results: see ResultGridView (design_handoff_find_grid_about_help).
    private func gridView(screenWidth: CGFloat) -> some View {
        ResultGridView(
            results: results,
            query: baseQuery,
            selectedIndex: selectedResultIndex,
            screenWidth: screenWidth,
            onBack: { selectedTab = .home },
            onOpen: { result in
                // Find is meant to take you to the thing you found,
                // not into another in-app detail screen.
                if let url = URL(string: result.url) {
                    openURL(url)
                }
            },
            openNow: gridOpenNowControl
        )
    }

    private var followupActions: FindFollowupActions {
        let model = viewModel
        return FindFollowupActions(
            ask: { request in await model.askFollowup(request) },
            search: { searchQuery in Task { await model.runFollowupSearch(searchQuery) } }
        )
    }

    private var gridOpenNowControl: OpenNowControl? {
        guard viewModel.searchResponse?.queryType == .local else { return nil }
        let model = viewModel
        return OpenNowControl(isOn: model.isOpenNowSearch, toggle: { Task { await model.toggleOpenNow() } })
    }

    // "Watching" at the top of History (the web's .find-watching section).
    private var watchingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WATCHING")
                    .font(Theme.font(12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(watchStore.watches.count) of \(FindWatchStore.maxWatches)")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(watchStore.watches) { watch in
                let highlighted = watch.changed || watchStore.highlightedIDs.contains(watch.id)
                HStack(spacing: 12) {
                    Button {
                        selectedTab = .home
                        Task {
                            await viewModel.runHistorySearch(watch.query)
                            if viewModel.searchResponse != nil { showingSearchScreen = false }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(watch.current.isEmpty ? watchStore.kindLabel(watch) : "\(watchStore.kindLabel(watch)) · \(watch.current)")
                                .font(Theme.font(12, weight: .bold))
                                .foregroundStyle(highlighted ? Theme.tBlueFg : Theme.muted)
                            Text(watch.title)
                                .font(Theme.font(15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Text(watchStore.status(watch))
                                .font(Theme.font(13, weight: highlighted ? .semibold : .regular))
                                .foregroundStyle(highlighted ? Theme.tBlueFg : Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .trailing, spacing: 6) {
                        if watch.expired || watchStore.daysLeft(watch) <= 5 {
                            Button(watch.expired ? "Watch again" : "Renew") { Task { await watchStore.renew(watch) } }
                        }
                        Button("Stop") { Task { await watchStore.remove(watch) } }
                            .accessibilityLabel("Stop watching \(watch.title)")
                    }
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Theme.blueInk)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(highlighted ? Theme.tBlue : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(watch.expired ? 0.7 : 1)
            }
        }
    }

    private func historyView(screenWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    viewModel.resetSearch()
                    showingSearchScreen = true
                    selectedTab = .home
                } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 36, height: 36)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Home")

                Text("Recent searches")
                    .font(Theme.font(22, weight: .bold))
                Spacer()
                if !viewModel.searchHistory.isEmpty {
                    Button("Clear") {
                        viewModel.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .font(Theme.font(16, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
            }

            if !watchStore.watches.isEmpty {
                watchingSection
            }

            if viewModel.searchHistory.isEmpty {
                emptyState("No searches yet.")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.searchHistory, id: \.self) { item in
                            Button {
                                selectedTab = .home
                                Task {
                                    await viewModel.runHistorySearch(item)
                                    if viewModel.searchResponse != nil {
                                        showingSearchScreen = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .foregroundStyle(Theme.subtext)
                                    Text(item)
                                        .font(Theme.font(16))
                                        .foregroundStyle(Theme.text)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(width: screenWidth - 36, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .background(Theme.cardBackground)
    }

    // "Use my location" (the web's .find-info-setting card).
    private var locationSettingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { viewModel.useLocationEverywhere },
                set: { enabled in
                    Task {
                        let granted = await viewModel.setUseLocationEverywhere(enabled)
                        locationSettingBlocked = enabled && !granted
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use my location")
                        .font(Theme.font(16, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Shows how far away places are on every search, not just \"near me\". Your location is sent with each search and never stored.")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.accent)

            if locationSettingBlocked {
                Text("Location is off for Find. Turn it on in Settings › Privacy & Security › Location Services › Find, then try again.")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoView(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        viewModel.resetSearch()
                        showingSearchScreen = true
                        selectedTab = .home
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 36, height: 36)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Home")

                    Text("About Find")
                        .font(Theme.font(22, weight: .bold))
                    Spacer()
                }

                infoCard("01", "One destination, not a list", "Find picks the single strongest result instead of showing you 10 blue links. Swipe to see alternatives.")
                infoCard("02", "Context pills & drill-down", "Tap a pill in the bottom bar to refine your search context. Find keeps your original query intact and swaps the active refinement instead of stacking duplicates.")
                infoCard("03", "People → Lead Vault", "Find shows the best web results first. When a query looks like a person, buyer, or prospect, you can continue the search in Lead Vault when you’re ready.")
                infoCard("04", "The philosophy", "Most search tools optimize for clicks. Find optimizes for the right result. We believe the best search experience ends with you knowing something — not choosing between 10 links that might.")

                locationSettingCard

                VStack(spacing: 6) {
                    Text("BUILT BY")
                        .font(Theme.font(13, weight: .black))
                        .foregroundStyle(Theme.subtext)
                    Link(TaliferroCompany.name, destination: TaliferroCompany.url)
                        .font(Theme.font(22, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text("Find is part of TODD — the Momentum System designed for teams that move fast and need information faster.")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.subtext)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 14) {
                        Link(TaliferroCompany.email, destination: URL(string: "mailto:\(TaliferroCompany.email)")!)
                        Link("taliferro.tech", destination: TaliferroCompany.url)
                    }
                    .font(Theme.font(14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)

                    // Same policy links as the web Info screen (MENU_COMPANY in @taliferro/ui).
                    FlowLinks(links: TaliferroCompany.links)
                        .padding(.top, 10)

                    Text(verbatim: "© \(currentYear) \(TaliferroCompany.legalName). Taliferro Is Registered In The U.S. Patent And Trademark Office. All rights reserved.")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    if let appVersionLabel {
                        Text(verbatim: "Version \(appVersionLabel)")
                            .font(Theme.font(11))
                            .foregroundStyle(Theme.subtext.opacity(0.7))
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.top, 10)

                if tiltNav.isSupported {
                    tiltSection
                }
            }
            .frame(width: screenWidth - 36, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 120)
            .background(Theme.cardBackground)
        }
        .background(Theme.cardBackground)
    }

    private func awardsView(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        viewModel.resetSearch()
                        showingSearchScreen = true
                        selectedTab = .home
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 36, height: 36)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Home")

                    Text("Awards")
                        .font(Theme.font(22, weight: .bold))
                    Spacer()
                }

                AwardsGridView(awardsService: awardsService)
            }
            .frame(width: screenWidth - 36, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 120)
            .background(Theme.cardBackground)
        }
        .background(Theme.cardBackground)
    }

    private var tiltSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tiltNav.isActive {
                Text("Tilt navigation is active. Flick the device toward a pill to open it.")
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.subtext)

                Button {
                    tiltNav.disable()
                } label: {
                    Text("Disable tilt navigation")
                        .font(Theme.font(15, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(
                            Capsule()
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    tiltNav.enable()
                } label: {
                    Text("Enable tilt navigation")
                        .font(Theme.font(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 14)
    }

    #if DEBUG
    // Live sensor readout while tuning tilt navigation - shows raw rate and
    // the leaky-integrator accumulation for each axis, plus whatever
    // direction most recently fired, so the actual numbers behind a tilt
    // gesture can be read directly off the screen instead of guessed at.
    // Compiled out of release builds entirely - not just hidden - so it
    // never ships, without deleting it: this stays automatic (tied to the
    // build configuration) rather than something to remember to comment out
    // by hand before submission.
    private var tiltDebugReadout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG")
                .font(Theme.font(11, weight: .black))
                .foregroundStyle(Theme.subtext)
            debugRow("roll rate", tiltNav.debugRollRate)
            debugRow("roll accum", tiltNav.debugRollAccum)
            debugRow("pitch rate", tiltNav.debugPitchRate)
            debugRow("pitch accum", tiltNav.debugPitchAccum)
            Text("last fired: \(tiltNav.tilt.rawValue)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    private func debugRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
                .font(Theme.font(12))
                .foregroundStyle(Theme.subtext)
            Spacer()
            Text(String(format: "%.1f°", value))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.text)
        }
    }
    #endif

    private func shareView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer()
            if let url = currentShareURL {
                Text("Share this result")
                    .font(Theme.font(22, weight: .bold))
                Text(url.absoluteString)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.subtext)
                    .multilineTextAlignment(.center)
                    .frame(width: min(screenWidth - 48, 320))
                Button("Open Share Sheet") {
                    showingShareSheet = true
                }
                .buttonStyle(.plain)
                .font(Theme.font(17, weight: .bold))
                .frame(width: 220, height: 50)
                .background(Theme.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                Text("In TODD, this also offers the path to add the result into Knowledge when your account supports it.")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.subtext)
                    .multilineTextAlignment(.center)
                    .frame(width: min(screenWidth - 56, 320))
            } else {
                emptyState("Run a search first.")
            }
            Spacer()
        }
        .frame(width: screenWidth)
        .background(Theme.cardBackground)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.muted)
            TextField("Search for anything…", text: $viewModel.query)
                .font(Theme.font(16))
                .foregroundStyle(Theme.text)
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    isSearchFieldFocused = false
                    Task {
                        await viewModel.runSearch()
                        if viewModel.searchResponse != nil {
                            showingSearchScreen = false
                        }
                    }
                }
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(Theme.surface, in: Capsule())
    }

    // Persistent search above results, so a new search never needs Home.
    private var resultSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.muted)
                TextField("Search for anything…", text: $resultSearchQuery)
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.text)
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
                    .onChange(of: resultSearchQuery) { _, newValue in
                        beginNewSearchIfNeeded(newValue)
                    }
                    .onSubmit {
                        submitResultSearch()
                    }
            }
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(Theme.surface, in: Capsule())

            Button {
                submitResultSearch()
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Find")
                            .font(Theme.font(15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 72, height: 46)
                .background(Theme.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Theme.bg)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func beginNewSearchIfNeeded(_ value: String) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              viewModel.searchResponse != nil else { return }

        viewModel.resetSearch()
        viewModel.query = value
        enteringNewSearch = true
        selectedTab = .home
    }

    private func submitResultSearch() {
        let trimmed = resultSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !viewModel.isLoading else { return }

        isSearchFieldFocused = false
        viewModel.query = trimmed
        enteringNewSearch = true

        Task {
            await viewModel.runSearch()
            if viewModel.searchResponse != nil {
                resultSearchQuery = ""
                enteringNewSearch = false
                showingSearchScreen = false
            }
        }
    }

    private var findLogo: some View {
        Image("FindLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
    }

    private func footerStack(screenWidth: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            stickyPillBar(screenWidth: screenWidth)
            bottomBar(screenWidth: screenWidth, bottomInset: bottomInset)
        }
        .background(Theme.cardBackground)
    }

    private func bottomBar(screenWidth: CGFloat, bottomInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            // In All results, the All button becomes Home so there's an obvious
            // way back to a new search.
            let tabs = BottomTab.allCases
                .filter { $0 != .home }
                .map { $0 == .grid && selectedTab == .grid ? BottomTab.home : $0 }
            ForEach(tabs, id: \.rawValue) { tab in
                Button {
                    if tab == .home {
                        // Matches the web app's Home tab (resetToSearch()):
                        // return to a blank search, not whatever single
                        // result happened to be showing.
                        viewModel.resetSearch()
                        showingSearchScreen = true
                        selectedTab = .home
                    } else if tab == .share, currentShareURL != nil {
                        selectedTab = .share
                        showingShareSheet = true
                    } else {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                            .frame(height: 22)
                            .overlay(alignment: .topTrailing) {
                                // Changed watches (the web's .find-tab__badge).
                                if tab == .history, watchStore.changedCount > 0 {
                                    Text("\(watchStore.changedCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Theme.danger, in: Capsule())
                                        .offset(x: 10, y: -6)
                                }
                            }
                        Text(tab.rawValue.capitalized)
                            .font(Theme.font(11, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? Theme.text : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 42)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue.capitalized)
            }
        }
        .frame(width: screenWidth)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, max(10, bottomInset))
        .frame(height: 50 + max(10, bottomInset))
        .background(Theme.chrome)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var appVersionLabel: String? {
        let info = Bundle.main.infoDictionary
        guard let shortVersion = info?["CFBundleShortVersionString"] as? String else { return nil }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(shortVersion) (\($0))" } ?? shortVersion
    }

    private func infoCard(_ number: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(number)
                .font(Theme.font(15, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.accent)
                .clipShape(Circle())

            Text(title)
                .font(Theme.font(18, weight: .bold))

            Text(body)
                .font(Theme.font(15))
                .foregroundStyle(Theme.subtext)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Theme.subtext)
            Text(message)
                .font(Theme.font(15))
                .foregroundStyle(Theme.subtext)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private static let tiltDirectionLetters = ["L", "R", "U", "D"]

    private var pillRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(currentPills.enumerated()), id: \.element) { index, pill in
                let isHighlighted = (tiltNav.isActive && pill == highlightedPill)
                    || (viewModel.isLoading && pill == activePill)
                let label = tiltNav.isActive && Self.tiltDirectionLetters.indices.contains(index)
                    ? "\(Self.tiltDirectionLetters[index]) - \(pill)"
                    : pill

                Button {
                    activePill = pill
                    selectedTab = .home
                    Task {
                        await viewModel.runDrillDown(from: baseQuery, pill: pill)
                        if viewModel.searchResponse != nil {
                            showingSearchScreen = false
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isLoading && pill == activePill {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(label)
                            }
                        } else {
                            Text(label)
                        }
                    }
                    .font(Theme.font(13, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isHighlighted ? Theme.background : Theme.subtext)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    // Original context strip: flat gray cells; the lit one
                    // becomes a solid black pill inside its cell.
                    .background {
                        if isHighlighted {
                            Capsule().fill(Theme.text)
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .overlay(alignment: .trailing) {
                        if index < currentPills.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(width: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }
        }
        .opacity(viewModel.isLoading ? 0.82 : 1)
    }

    private func stickyPillBar(screenWidth: CGFloat) -> some View {
        pillRow
            .frame(width: screenWidth, alignment: .leading)
            .frame(height: 42)
            .background(Theme.chrome)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
            }
    }

    private var isWeatherMode: Bool {
        viewModel.searchResponse?.queryType == .weather
    }

    private var isConversionMode: Bool {
        viewModel.searchResponse?.queryType == .conversion && viewModel.searchResponse?.conversion != nil
    }

    private var conversionCategory: FindConversionCategory? {
        viewModel.searchResponse?.conversion?.category
    }

    private var conversionUnitOptions: [ConversionUnitOption] {
        // Backend unit conversions list every unit in their category.
        if let options = viewModel.searchResponse?.conversion?.unitOptions, !options.isEmpty {
            return options.map { ConversionUnitOption(value: $0.value, label: $0.label) }
        }
        switch conversionCategory {
        case .currency:
            return [
                .init(value: "USD", label: "US Dollar (USD)"), .init(value: "CAD", label: "Canadian Dollar (CAD)"),
                .init(value: "EUR", label: "Euro (EUR)"), .init(value: "GBP", label: "British Pound (GBP)"),
                .init(value: "JPY", label: "Japanese Yen (JPY)"), .init(value: "AUD", label: "Australian Dollar (AUD)"),
                .init(value: "CNY", label: "Chinese Yuan (CNY)"), .init(value: "CHF", label: "Swiss Franc (CHF)"),
                .init(value: "MXN", label: "Mexican Peso (MXN)")
            ]
        case .temperature: return [.init(value: "F", label: "Fahrenheit (°F)"), .init(value: "C", label: "Celsius (°C)")]
        case .distance: return [.init(value: "mi", label: "Miles"), .init(value: "km", label: "Kilometers")]
        case .weight: return [.init(value: "lb", label: "Pounds"), .init(value: "kg", label: "Kilograms")]
        case .length: return [.init(value: "in", label: "Inches"), .init(value: "cm", label: "Centimeters"), .init(value: "ft", label: "Feet"), .init(value: "m", label: "Meters")]
        case .volume: return [.init(value: "gal", label: "US Gallons"), .init(value: "l", label: "Liters")]
        case .speed, .area, .data, .none: return []
        }
    }

    private var formattedConversionOutput: String {
        guard let conversion = viewModel.searchResponse?.conversion,
              let amount = Double(conversionAmountText), let output = conversionOutputValue(conversion, amount: amount) else {
            return "Unavailable"
        }
        return formattedConversionValue(output)
    }

    private func syncConversionState() {
        guard let conversion = viewModel.searchResponse?.conversion else { return }
        conversionAmountText = formattedConversionValue(conversion.inputAmount, maximumFractionDigits: 8)
        conversionInputUnit = normalizeConversionUnit(conversion.inputUnit)
        conversionOutputUnit = normalizeConversionUnit(conversion.outputUnit)
        conversionRate = conversion.rate
        conversionRateUpdatedAt = conversion.rateUpdatedAt ?? ""
        conversionSource = conversion.source ?? ""
        conversionBaseInputUnit = conversionInputUnit
        conversionBaseOutputUnit = conversionOutputUnit
        conversionBaseRate = conversionRate
    }

    private func swapConversion() {
        let previousInput = conversionInputUnit
        conversionInputUnit = conversionOutputUnit
        conversionOutputUnit = previousInput
        refreshConversionRate()
    }

    private func refreshConversionRate() {
        guard conversionCategory == .currency else { return }
        if conversionInputUnit == conversionBaseInputUnit && conversionOutputUnit == conversionBaseOutputUnit {
            conversionRate = conversionBaseRate
        } else if conversionInputUnit == conversionBaseOutputUnit && conversionOutputUnit == conversionBaseInputUnit,
                  let baseRate = conversionBaseRate, baseRate != 0 {
            conversionRate = 1 / baseRate
        } else if let rates = viewModel.searchResponse?.conversion?.rates,
                  let inputRate = rates[conversionInputUnit], let outputRate = rates[conversionOutputUnit], inputRate != 0 {
            // Backend conversions carry every supported currency's rate
            // against the original input, so any pair can be worked out.
            conversionRate = outputRate / inputRate
        } else {
            conversionRate = nil
        }
    }

    private func conversionOutputValue(_ conversion: FindConversionResult, amount: Double) -> Double? {
        if conversion.category == .currency {
            guard let rate = conversionRate else { return nil }
            return amount * rate
        }
        if conversion.category == .temperature {
            let celsius = conversionInputUnit == "F" ? (amount - 32) * 5 / 9 : conversionInputUnit == "K" ? amount - 273.15 : amount
            return conversionOutputUnit == "F" ? celsius * 9 / 5 + 32 : conversionOutputUnit == "K" ? celsius + 273.15 : celsius
        }
        guard let inputFactor = unitFactor(conversion.category, unit: conversionInputUnit),
              let outputFactor = unitFactor(conversion.category, unit: conversionOutputUnit) else { return nil }
        return amount * inputFactor / outputFactor
    }

    private func unitFactor(_ category: FindConversionCategory, unit: String) -> Double? {
        if let factor = viewModel.searchResponse?.conversion?.unitOptions?.first(where: { $0.value == unit })?.factor {
            return factor
        }
        switch category {
        case .distance: return ["mi": 1609.344, "km": 1000][unit]
        case .weight: return ["lb": 0.45359237, "kg": 1][unit]
        case .length: return ["in": 0.0254, "cm": 0.01, "ft": 0.3048, "m": 1][unit]
        case .volume: return ["gal": 3.785411784, "l": 1][unit]
        case .temperature, .currency: return 1
        case .speed, .area, .data: return nil
        }
    }

    private func normalizeConversionUnit(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "dollar", "dollars", "usd": return "USD"
        case "cad": return "CAD"
        case "eur", "euro", "euros": return "EUR"
        case "gbp": return "GBP"
        case "jpy", "yen": return "JPY"
        case "aud": return "AUD"
        case "cny", "yuan": return "CNY"
        case "chf": return "CHF"
        case "mxn": return "MXN"
        case "fahrenheit": return "F"
        case "celsius": return "C"
        case "mile", "miles": return "mi"
        case "kilometer", "kilometers": return "km"
        case "pound", "pounds", "poundmass", "kilogram", "kilograms": return value.lowercased().hasPrefix("pound") ? "lb" : "kg"
        case "inch", "inches": return "in"
        case "centimeter", "centimeters": return "cm"
        case "foot", "feet": return "ft"
        case "meter", "meters": return "m"
        case "gallon", "gallons": return "gal"
        case "liter", "liters": return "l"
        default: return value
        }
    }

    private func formattedConversionValue(_ value: Double, maximumFractionDigits: Int = 4) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func formattedConversionDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var results: [FindRankedResult] {
        viewModel.searchResponse?.results ?? []
    }

    private var selectedResultIndex: Int {
        guard let selected = viewModel.selectedResult else { return 0 }
        return results.firstIndex(where: { $0.url == selected.url }) ?? 0
    }

    private var isGroundedAnswerSlide: Bool {
        viewModel.viewingGroundedAnswer
    }

    // Whether a dedicated leading slide (page -1) exists for the backend's
    // own generated answer - see FindResultPagerView/ResultPageView.
    private var hasLeadingAnswer: Bool {
        guard viewModel.searchResponse?.queryType == .question else { return false }
        let text = viewModel.searchResponse?.answer?.text ?? ""
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canGoToNextResult: Bool {
        guard !results.isEmpty else { return false }
        return viewModel.viewingGroundedAnswer || selectedResultIndex < results.count - 1
    }

    private var currentPills: [String] {
        Array((currentResult?.pills ?? []).prefix(4))
    }

    private var currentResult: FindRankedResult? {
        viewModel.selectedResult ?? results.first
    }

    private var shelfTitle: String {
        baseQuery.isEmpty ? "Find" : compactQuery(baseQuery)
    }

    private func compactQuery(_ query: String) -> String {
        let maxCharacters = 34
        guard query.count > maxCharacters else { return query }

        let cutoff = query.index(query.startIndex, offsetBy: maxCharacters - 1)
        return String(query[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private var baseQuery: String {
        (viewModel.searchResponse?.query ?? viewModel.query).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentShareURL: URL? {
        if let urlString = currentResult?.url {
            return URL(string: urlString)
        }
        return nil
    }

    private var showStickyPills: Bool {
        !currentPills.isEmpty
            && ((selectedTab == .home && !showingSearchScreen && viewModel.searchResponse != nil)
                || selectedTab == .grid)
    }

    private func footerReservedHeight(bottomInset: CGFloat) -> CGFloat {
        let tabs = 50 + max(10, bottomInset)
        let pills: CGFloat = showStickyPills ? 42 : 0
        return tabs + pills
    }

    /// Previous result; from the first result, the leading answer page when
    /// there is one, otherwise back to the search screen - same as web's
    /// onPreviousResult().
    private func goToPreviousResult() {
        if viewModel.viewingGroundedAnswer {
            goHome()
        } else if selectedResultIndex > 0, results.indices.contains(selectedResultIndex - 1) {
            viewModel.select(results[selectedResultIndex - 1])
        } else if canGoBackToAnswer {
            viewModel.viewingGroundedAnswer = true
        } else {
            goHome()
        }
    }

    private var canGoBackToAnswer: Bool {
        hasLeadingAnswer && !viewModel.viewingGroundedAnswer
    }

    private func goHome() {
        viewModel.resetSearch()
        showingSearchScreen = true
        selectedTab = .home
    }

    /// "‹ Back" / "Next ›" - a word beside the chevron so it reads as navigation.

    private func goToNextResult() {
        if viewModel.viewingGroundedAnswer {
            viewModel.viewingGroundedAnswer = false
            return
        }
        guard selectedResultIndex < results.count - 1 else { return }
        viewModel.select(results[selectedResultIndex + 1])
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { !viewModel.errorMessage.isEmpty },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = ""
                }
            }
        )
    }
}

#Preview {
    let awardsService = FindAwardsService()
    NavigationStack {
        SearchView(
            viewModel: SearchViewModel(
                apiClient: FindAPIClient(
                    config: AppConfig(
                        apiBaseURL: URL(string: "https://api.taliferro.tech/api")!,
                        apiKey: "preview"
                    )
                ),
                awardsService: awardsService,
                locationService: FindLocationService()
            ),
            awardsService: awardsService,
            watchStore: FindWatchStore(apiClient: FindAPIClient(
                config: AppConfig(apiBaseURL: URL(string: "https://api.taliferro.tech/api")!, apiKey: "preview")
            ))
        )
    }
}
