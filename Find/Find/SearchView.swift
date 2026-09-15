import SwiftUI
import NaturalLanguage

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @StateObject private var tiltNav = TiltNavigationService()
    @State private var selectedTab: BottomTab = .home
    @State private var showingShareSheet = false
    @State private var showingSearchScreen = true
    @State private var enteringNewSearch = false
    @State private var resultSearchQuery = ""
    @State private var highlightedPill = ""
    @State private var activePill = ""
    @State private var conversionAmountText = ""
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
        case grid = "GRID"
        case history = "HISTORY"
        case info = "INFO"
        case share = "SHARE"

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .grid: return "square.grid.2x2"
            case .history: return "arrow.counterclockwise"
            case .info: return "info.circle.fill"
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
        let color: Color
        let query: String
        var disabled = false
        var id: String { label }
    }

    // Mirrors the web app's find-home.component.ts `quickActions` array
    // exactly - same labels, order, colors (via Theme.quickAction*), and
    // queries.
    private static let quickActions: [FindQuickAction] = [
        FindQuickAction(label: "News", systemImage: "newspaper.fill", color: Theme.quickActionNews, query: "Today's News"),
        FindQuickAction(label: "Weather", systemImage: "sun.max.fill", color: Theme.quickActionWeather, query: "weather"),
        FindQuickAction(label: "Sports", systemImage: "soccerball", color: Theme.quickActionSports, query: "sports news"),
        FindQuickAction(label: "Conversion", systemImage: "arrow.left.arrow.right", color: Theme.quickActionConversion, query: "100 USD to EUR"),
        FindQuickAction(label: "Restaurants", systemImage: "fork.knife", color: Theme.quickActionRestaurants, query: "restaurants near me"),
        FindQuickAction(label: "Events", systemImage: "calendar", color: Theme.quickActionEvents, query: "events near me", disabled: true),
    ]

    init(viewModel: SearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                    case .share:
                        shareView(screenWidth: geometry.size.width)
                    }
                }
                if showStickyPills {
                    footerStack(screenWidth: geometry.size.width, bottomInset: geometry.safeAreaInsets.bottom)
                } else {
                    bottomBar(screenWidth: geometry.size.width, bottomInset: geometry.safeAreaInsets.bottom)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
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
        .onDisappear {
            tiltNav.disable()
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

    private func searchHomeView(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 62)

                findLogo
                    .padding(.bottom, 26)

                searchBar
                    .padding(.horizontal, 24)

                Button {
                    runSearchFromHome(viewModel.query)
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Find")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 18)

                quickActionsGrid
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                Spacer(minLength: 60)
            }
            .frame(width: screenWidth)
            .background(Theme.cardBackground)
        }
    }

    private var quickActionsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(Self.quickActions) { action in
                Button {
                    runSearchFromHome(action.query)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(action.label)
                            .font(.system(size: 13, weight: .bold))
                        if action.disabled {
                            Text("Coming soon")
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .background(action.color)
                    .opacity(action.disabled ? 0.52 : 1)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(action.disabled || viewModel.isLoading)
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
        .background(Theme.cardBackground)
    }

    private func weatherHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultShelf(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let heroURL = heroImageURL {
                        heroImageView(url: heroURL, screenWidth: screenWidth)
                    }
                    if let weather = viewModel.searchResponse?.weather {
                        weatherCard(weather)
                    }
                    Spacer(minLength: 18)
                }
                .frame(width: screenWidth)
                .padding(.top, 24)
                .padding(.bottom, 150)
            }
        }
    }

    private func conversionHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultShelf(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                if let conversion = viewModel.searchResponse?.conversion {
                    if let heroURL = heroImageURL {
                        heroImageView(url: heroURL, screenWidth: screenWidth)
                    }
                    conversionCard(conversion)
                }
                Spacer(minLength: 18)
            }
            .padding(.bottom, 150)
        }
        .onAppear { syncConversionState() }
        .onChange(of: viewModel.searchResponse?.query) { _, _ in syncConversionState() }
    }

    private func conversionCard(_ conversion: FindConversionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(conversion.category == .currency ? "CURRENCY CONVERSION" : "UNIT CONVERSION")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Theme.accent)

            HStack(alignment: .bottom, spacing: 10) {
                conversionField(title: "From", isOutput: false)

                Button {
                    swapConversion()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36, height: 36)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap conversion units")

                conversionField(title: "To", isOutput: true)
            }

            conversionKeypad

            if conversion.category == .currency, let rate = conversionRate {
                Text("1 \(conversionInputUnit) = \(formattedConversionValue(rate, maximumFractionDigits: 6)) \(conversionOutputUnit)\(conversionRateUpdatedAt.isEmpty ? "" : " · Updated \(formattedConversionDate(conversionRateUpdatedAt))")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.subtext)
            } else if conversion.category == .currency {
                Text("A live exchange rate is not available right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }

            if !conversionSource.isEmpty {
                Text("Source: \(conversionSource)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.subtext)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 24)
    }

    private var conversionKeypad: some View {
        let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(digits, id: \.self) { digit in
                Button(digit) { appendConversionDigit(digit) }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Theme.surface)
                    .foregroundStyle(Theme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1))
            }
            Button(".") { appendConversionDecimal() }
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Theme.surface)
                .foregroundStyle(Theme.text)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1))
            Button { deleteConversionDigit() } label: { Image(systemName: "delete.left") }
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Theme.surface)
                .foregroundStyle(Theme.text)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .accessibilityLabel("Backspace")
            Button("Clear") { conversionAmountText = "0" }
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Theme.accent.opacity(0.12))
                .foregroundStyle(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .gridCellColumns(2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calculator keypad")
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

    @ViewBuilder
    private func conversionField(title: String, isOutput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.subtext)

            if isOutput {
                Text(formattedConversionOutput)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                TextField("Amount", text: $conversionAmountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(minHeight: 48)
                    .padding(.horizontal, 12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: conversionAmountText) { _, _ in }
            }

            Menu {
                ForEach(conversionUnitOptions) { option in
                    Button(option.label) {
                        if isOutput { conversionOutputUnit = option.value } else { conversionInputUnit = option.value }
                        refreshConversionRate()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isOutput ? conversionOutputUnit : conversionInputUnit)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weatherCard(_ weather: FindWeatherInfo) -> some View {
        VStack(spacing: 10) {
            AsyncImage(url: URL(string: weather.iconUrl)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: 90, height: 90)

            Text("\(Int(weather.tempF.rounded()))°F")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Theme.text)

            Text(weather.postalCode.map { "\(weather.location) \($0)" } ?? weather.location)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)

            Text(weather.description.capitalized)
                .font(.system(size: 16))
                .foregroundStyle(Theme.subtext)

            HStack(spacing: 20) {
                Text("Feels like \(Int(weather.feelsLikeF.rounded()))°")
                Text("Humidity \(Int(weather.humidity))%")
                Text("Wind \(Int(weather.windMph)) mph")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.subtext)
            .padding(.top, 8)

            if weather.highF != nil || weather.lowF != nil {
                HStack(spacing: 16) {
                    if let highF = weather.highF {
                        Text("High \(Int(highF.rounded()))°")
                    }
                    if let lowF = weather.lowF {
                        Text("Low \(Int(lowF.rounded()))°")
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.text)
                .padding(.top, 6)
            }

            if let forecast = weather.forecast, !forecast.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FORECAST")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.text)
                        .padding(.bottom, 8)

                    ForEach(Array(forecast.enumerated()), id: \.offset) { index, day in
                        forecastRow(day, showsDivider: index < forecast.count - 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 22)
            }

            if let updatedAt = weather.updatedAt, let formatted = Self.formatUpdatedAt(updatedAt) {
                Text("Updated \(formatted)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.subtext)
                    .padding(.top, 14)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private func forecastRow(_ day: FindWeatherForecastDay, showsDivider: Bool) -> some View {
        HStack(spacing: 10) {
            Text(day.label.isEmpty ? day.date : day.label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 92, alignment: .leading)

            HStack(spacing: 6) {
                if let iconUrlString = day.iconUrl, let iconURL = URL(string: iconUrlString) {
                    AsyncImage(url: iconURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 24, height: 24)
                }

                Text(day.description?.isEmpty == false ? day.description! : day.condition)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.subtext)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if let highF = day.highF {
                    Text("\(Int(highF.rounded()))°")
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                }
                if let lowF = day.lowF {
                    Text("\(Int(lowF.rounded()))°")
                        .foregroundStyle(Theme.subtext)
                }
            }
            .font(.system(size: 14))
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
            }
        }
    }

    private static let updatedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static func formatUpdatedAt(_ iso: String) -> String? {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        return updatedAtFormatter.string(from: date)
    }

    private func answerHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultShelf(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let heroURL = heroImageURL {
                        heroImageView(url: heroURL, screenWidth: screenWidth)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Text(currentEyebrow)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.accent)

                        Text(currentBusinessName)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Theme.text)

                        if !currentBusinessAddress.isEmpty {
                            Text(currentBusinessAddress)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.subtext)
                        }

                        if !currentBusinessMeta.isEmpty, let urlString = currentResult?.url, let url = URL(string: urlString) {
                            HStack(spacing: 12) {
                                ForEach(currentBusinessMeta, id: \.self) { item in
                                    Link(item, destination: url)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }

                        if let sourceURL = currentSourceDisplayURL {
                            Text(sourceURL)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.subtext)
                        }

                        if let hours = currentBusinessHours {
                            hoursCard(hours)
                        }

                        if !currentHoursFromSummary {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(answerParagraphs, id: \.self) { paragraph in
                                    Text(paragraph)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.subtext)
                                        .lineSpacing(6)
                                }
                            }
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 18)
                    .offset(y: heroImageURL == nil ? 18 : -8)

                    referencesSection
                        .padding(.top, heroImageURL == nil ? 18 : -8)

                    if let resultMetaText {
                        Text(resultMetaText)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subtext)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                    }

                    Spacer(minLength: 18)
                }
                .frame(width: screenWidth)
                .padding(.bottom, 150)
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Theme.background.opacity(0.72)
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.15)
                            Text("Refining result…")
                                .font(.system(size: 15, weight: .semibold))
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
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            if value.translation.width < 0 {
                                goToNextResult()
                            } else {
                                goToPreviousResult()
                            }
                        }
                    }
            )
        }
    }

    private func resultShelf(screenWidth: CGFloat) -> some View {
        HStack {
            Button {
                viewModel.resetSearch()
                showingSearchScreen = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            VStack(spacing: 4) {
                Text(shelfTitle)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(baseQuery.isEmpty ? "Find" : baseQuery)
                    .help(baseQuery.isEmpty ? "Find" : baseQuery)

                HStack(spacing: 5) {
                    ForEach(0..<results.count, id: \.self) { index in
                        Circle()
                            .fill(index == selectedResultIndex ? Theme.text : Theme.border)
                            .frame(width: index == selectedResultIndex ? 8 : 6, height: index == selectedResultIndex ? 8 : 6)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                goToNextResult()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(results.isEmpty || selectedResultIndex >= results.count - 1 ? Theme.subtext : Theme.text)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(results.isEmpty || selectedResultIndex >= results.count - 1)
        }
        .frame(width: screenWidth)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    private func gridView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            gridHeader(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if results.isEmpty {
                        emptyState("Run a search first.")
                    } else {
                        let isCompact = screenWidth < 520
                        let columnWidth = max(0, isCompact ? screenWidth - 36 : (screenWidth - 36 - 12) / 2)

                        // Two natural-height columns keep this view masonry-like
                        // instead of stretching every tile to the tallest tile
                        // in its row. Alternating results preserves scan order.
                        let indexedResults = results.enumerated().map { (offset: $0.offset, element: $0.element) }
                        let leftResults = indexedResults.compactMap { index, result in
                            index.isMultiple(of: 2) ? (index, result) : nil
                        }
                        let rightResults = indexedResults.compactMap { index, result in
                            index.isMultiple(of: 2) ? nil : (index, result)
                        }

                        Group {
                            if isCompact {
                                masonryColumn(indexedResults, imageSide: columnWidth)
                            } else {
                                HStack(alignment: .top, spacing: 12) {
                                    masonryColumn(leftResults, imageSide: columnWidth)
                                    masonryColumn(rightResults, imageSide: columnWidth)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .frame(width: screenWidth - 36, alignment: .topLeading)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 150)
                .background(Theme.cardBackground)
            }
            .background(Theme.cardBackground)
        }
    }

    @ViewBuilder
    private func masonryColumn(_ items: [(offset: Int, element: FindRankedResult)], imageSide: CGFloat) -> some View {
        VStack(spacing: 2) {
            ForEach(items, id: \.element.id) { item in
                GridTile(
                    result: item.element,
                    imageSide: imageSide,
                    isSelected: item.offset == selectedResultIndex
                ) {
                    // Find is meant to take you to the thing you found,
                    // not into another in-app detail screen.
                    if let url = URL(string: item.element.url) {
                        openURL(url)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // Fixed above the scrolling grid (not inside the ScrollView), so it
    // stays put while results scroll underneath - same treatment as the
    // result shelf. Replaces the old plain "All results" heading with a
    // back button, matching the web app: tapping it returns to the single
    // current result instead of just being inert page-title text.
    private func gridHeader(screenWidth: CGFloat) -> some View {
        HStack {
            Button {
                selectedTab = .home
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Spacer()

            Text("\(results.count) found")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.subtext)

            Color.clear
                .frame(width: 44, height: 1)
        }
        .frame(width: screenWidth)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    private struct GridTile: View {
        let result: FindRankedResult
        let imageSide: CGFloat
        let isSelected: Bool
        let onSelect: () -> Void

        @State private var imageFailed = false

        private var imageURL: URL? {
            guard !result.imageUrl.isEmpty else { return nil }
            return URL(string: result.imageUrl)
        }

        private var showsImage: Bool {
            imageURL != nil && !imageFailed
        }

        var body: some View {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {
                    if showsImage, let imageURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Color.clear
                                    .onAppear { imageFailed = true }
                            default:
                                Rectangle()
                                    .fill(Theme.surface)
                            }
                        }
                        .frame(width: imageSide, height: imageSide)
                        .clipped()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.displayUrl)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)

                        Text(result.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(showsImage ? 2 : 3)

                        Text(result.summary)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.subtext)
                            .lineLimit(showsImage ? 3 : 9)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 7, y: 3)
            }
            .buttonStyle(.plain)
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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 36, height: 36)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to home")

                Text("Recent searches")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                if !viewModel.searchHistory.isEmpty {
                    Button("Clear") {
                        viewModel.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
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
                                        .font(.system(size: 16))
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

    private func infoView(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        viewModel.resetSearch()
                        showingSearchScreen = true
                        selectedTab = .home
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 36, height: 36)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to home")

                    Text("About Find")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                }

                infoCard("01", "One destination, not a list", "Find picks the single strongest result instead of showing you 10 blue links. Swipe to see alternatives.")
                infoCard("02", "Context pills & drill-down", "Tap a pill in the bottom bar to refine your search context. Find keeps your original query intact and swaps the active refinement instead of stacking duplicates.")
                infoCard("03", "People → Lead Vault", "Find shows the best web results first. When a query looks like a person, buyer, or prospect, you can continue the search in Lead Vault when you’re ready.")
                infoCard("04", "The philosophy", "Most search tools optimize for clicks. Find optimizes for answers. We believe the best search experience ends with you knowing something — not choosing between 10 links that might.")

                VStack(spacing: 6) {
                    Text("BUILT BY")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.subtext)
                    Text("Taliferro Tech")
                        .font(.system(size: 22, weight: .bold))
                    Text("Find is part of TODD — the Momentum System designed for teams that move fast and need information faster.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.subtext)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 14) {
                        Link("ty.showers@taliferro.com", destination: URL(string: "mailto:ty.showers@taliferro.com")!)
                        Link("taliferro.com", destination: URL(string: "https://taliferro.com")!)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)

                    Text(LocalizedStringKey("© \(currentYear) TODD. Site design [Taliferro Group](https://taliferro.com/website-development). Taliferro Is Registered In The U.S. Patent And Trademark Office. All rights reserved. | [Contact](https://taliferro.com/contact.html)"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtext)
                        .multilineTextAlignment(.center)
                        .tint(Theme.accent)
                        .padding(.top, 12)

                    if let appVersionLabel {
                        Text(verbatim: "Version \(appVersionLabel)")
                            .font(.system(size: 11))
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

    private var tiltSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tiltNav.isActive {
                Text("Tilt navigation is active. Flick the device toward a pill to open it.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.subtext)

                Button {
                    tiltNav.disable()
                } label: {
                    Text("Disable tilt navigation")
                        .font(.system(size: 15, weight: .bold))
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
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
                .font(.system(size: 11, weight: .black))
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
                .font(.system(size: 12))
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
                    .font(.system(size: 22, weight: .bold))
                Text(url.absoluteString)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.subtext)
                    .multilineTextAlignment(.center)
                    .frame(width: min(screenWidth - 48, 320))
                Button("Open Share Sheet") {
                    showingShareSheet = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 220, height: 50)
                .background(Theme.accent)
                .foregroundStyle(.black)
                .clipShape(Capsule())
                Text("In TODD, this also offers the path to add the result into Knowledge when your account supports it.")
                    .font(.system(size: 15))
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
        TextField("Search for anything...", text: $viewModel.query)
            .font(.system(size: 17))
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
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

    private var resultSearchBar: some View {
        HStack(spacing: 8) {
            TextField("Search for anything...", text: $resultSearchQuery)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Theme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.border, lineWidth: 1)
                )
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onChange(of: resultSearchQuery) { _, newValue in
                    beginNewSearchIfNeeded(newValue)
                }
                .onSubmit {
                    submitResultSearch()
                }

            Button {
                submitResultSearch()
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Find")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 68, height: 50)
                .background(Theme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
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
            .frame(width: 92, height: 92)
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
            ForEach(BottomTab.allCases.filter { $0 != .home }, id: \.rawValue) { tab in
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
                            .font(.system(size: 17, weight: .medium))

                        Text(tab.rawValue)
                            .font(.system(size: 8, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selectedTab == tab ? Theme.accent : Theme.subtext)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 42)
                    .padding(.top, 5)
                    .padding(.bottom, 4)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(selectedTab == tab ? Theme.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: screenWidth)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, max(10, bottomInset))
        .frame(height: 50 + max(10, bottomInset))
        .background(Theme.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.border)
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
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(Theme.accent)
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 18, weight: .bold))

            Text(body)
                .font(.system(size: 15))
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
                .font(.system(size: 15))
                .foregroundStyle(Theme.subtext)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private static let tiltDirectionLetters = ["L", "R", "U", "D"]

    private var pillRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(currentPills.enumerated()), id: \.element) { index, pill in
                let isHighlighted = tiltNav.isActive && pill == highlightedPill
                let label = tiltNav.isActive && Self.tiltDirectionLetters.indices.contains(index)
                    ? "\(Self.tiltDirectionLetters[index]): \(pill)"
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
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(isHighlighted ? Color.white : Theme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(isHighlighted ? Theme.accent : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(Theme.border, lineWidth: 1)
                    )
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
            .background(Theme.cardBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.border)
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
        case .none: return []
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
            if conversionInputUnit == conversionOutputUnit { return amount }
            return conversionOutputUnit == "F" ? amount * 9 / 5 + 32 : (amount - 32) * 5 / 9
        }
        guard let inputFactor = unitFactor(conversion.category, unit: conversionInputUnit),
              let outputFactor = unitFactor(conversion.category, unit: conversionOutputUnit) else { return nil }
        return amount * inputFactor / outputFactor
    }

    private func unitFactor(_ category: FindConversionCategory, unit: String) -> Double? {
        switch category {
        case .distance: return ["mi": 1609.344, "km": 1000][unit]
        case .weight: return ["lb": 0.45359237, "kg": 1][unit]
        case .length: return ["in": 0.0254, "cm": 0.01, "ft": 0.3048, "m": 1][unit]
        case .volume: return ["gal": 3.785411784, "l": 1][unit]
        case .temperature, .currency: return 1
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

    private var heroImageURL: URL? {
        if let fallback = fallbackHeroImageURL {
            return fallback
        }
        if isGroundedAnswerSlide {
            if let image = viewModel.searchResponse?.answer?.imageUrl,
               let url = URL(string: image), !image.isEmpty {
                return url
            }
            return nil
        }
        if let image = currentResult?.imageUrl, let url = URL(string: image), !image.isEmpty {
            return url
        }
        if let image = viewModel.searchResponse?.answer?.imageUrl, let url = URL(string: image), !image.isEmpty {
            return url
        }
        return nil
    }

    private var fallbackHeroImageURL: URL? {
        let path: String
        if isWeatherMode {
            path = "find-weather.png"
        } else if isConversionMode {
            path = "find-conversion.png"
        } else {
            let searchText = [
                viewModel.searchResponse?.query,
                viewModel.searchResponse?.normalizedQuery,
                viewModel.searchResponse?.answer?.text,
                currentResult?.title
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            guard searchText.range(of: #"\b(sports?|nfl|nba|wnba|mlb|nhl|soccer|football|basketball|baseball|hockey)\b"#, options: .regularExpression) != nil else {
                return nil
            }
            path = "find-sports.png"
        }
        return URL(string: "https://find.taliferro.tech/fallback/\(path)")
    }

    private func heroImageView(url: URL, screenWidth: CGFloat) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            default:
                Rectangle()
                    .fill(Theme.surface)
            }
        }
        .frame(maxWidth: screenWidth, maxHeight: UIScreen.main.bounds.height * 0.42)
        .frame(width: screenWidth)
        .background(Theme.surface)
    }

    // True only on the single slide the backend originally recommended
    // (searchResponse.selectedIndex, fixed per search - not the same as
    // selectedResultIndex, which changes as you page). Mirrors the web
    // app's isGroundedAnswerSlide: the shared AI-synthesized answer only
    // belongs on that one slide; every other slide - reached by paging via
    // the shelf chevrons - shows that individual result's own title/
    // summary/source, same as the grid shows for it.
    private var isGroundedAnswerSlide: Bool {
        guard viewModel.searchResponse?.queryType == .question else { return false }
        guard let text = viewModel.searchResponse?.answer?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let originalIndex = viewModel.searchResponse?.selectedIndex ?? 0
        return selectedResultIndex == originalIndex
    }

    private var currentEyebrow: String {
        isGroundedAnswerSlide ? "ANSWER" : "RESULT \(selectedResultIndex + 1)"
    }

    private var currentSourceDisplayURL: String? {
        guard !isGroundedAnswerSlide else { return nil }
        let displayUrl = currentResult?.displayUrl ?? ""
        return displayUrl.isEmpty ? nil : displayUrl
    }

    // Matches the web app's find-question-sources block: the citations
    // behind the grounded answer, shown only on that slide. Each opens the
    // actual source, same as everywhere else Find links out.
    @ViewBuilder
    private var referencesSection: some View {
        if isGroundedAnswerSlide, let references = viewModel.searchResponse?.answer?.references, !references.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("References")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(references.count) SOURCES")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.subtext)
                }

                VStack(spacing: 10) {
                    ForEach(references) { reference in
                        Button {
                            if let url = URL(string: reference.url) {
                                openURL(url)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reference.displayUrl)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                                Text(reference.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    // Matches the web app's find-result-meta line.
    private var resultMetaText: String? {
        guard let timings = viewModel.searchResponse?.timings else { return nil }

        var parts = [String(format: "%.1fs total", Double(timings.totalMs) / 1000)]
        if timings.candidateCount > 0 {
            parts.append("\(timings.candidateCount) candidates")
        }
        if timings.enrichedCount > 0 {
            parts.append("\(timings.enrichedCount) pages checked")
        }

        if currentResult?.isFirstParty == true {
            parts.append("official Taliferro knowledge")
        } else if let answer = currentResult?.answer, !answer.isEmpty,
                  currentResult?.isFirstParty != true,
                  viewModel.searchResponse?.queryType != .question {
            parts.append("TODD summary")
        } else if viewModel.searchResponse?.queryType == .question {
            parts.append(isGroundedAnswerSlide ? "grounded answer" : "supporting result")
        }

        return parts.joined(separator: " · ")
    }

    private var answerParagraphs: [String] {
        let candidates: [String?] = isGroundedAnswerSlide ?
            [viewModel.searchResponse?.answer?.text] :
            [currentResult?.answer, currentResult?.summary]
        let text = (candidates.compactMap { $0 }.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ) ?? "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return [] }

        let explicit = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if explicit.count > 1 { return explicit }

        let sentences = sentenceTokenize(text)
        if sentences.count < 4 { return [text] }

        var paragraphs: [String] = []
        var chunk: [String] = []
        for sentence in sentences {
            chunk.append(sentence)
            if chunk.count == 2 {
                paragraphs.append(chunk.joined(separator: " "))
                chunk.removeAll()
            }
        }
        if !chunk.isEmpty {
            paragraphs.append(chunk.joined(separator: " "))
        }
        return paragraphs
    }

    private var currentBusinessHours: FindBusinessHours? {
        if let hours = currentResult?.hours, !hours.days.isEmpty {
            return hours
        }

        // The backend may place provider text in either `answer` or
        // `summary`, depending on which result/enrichment path produced the
        // card. Try both, plus the top-level answer, so iOS matches the web
        // app's structured-hours fallback behavior.
        let candidates = [
            currentResult?.answer,
            currentResult?.summary,
            viewModel.searchResponse?.answer?.text
        ]
        for candidate in candidates {
            if let parsed = parsedHours(from: candidate ?? ""), !parsed.days.isEmpty {
                return parsed
            }
        }
        return nil
    }

    private var currentHoursFromSummary: Bool {
        currentResult?.hours == nil && currentBusinessHours != nil
    }

    private func hoursCard(_ hours: FindBusinessHours) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Hours")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if let statusText = hours.statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(hours.isOpenNow == true ? .green : .red)
                } else if let isOpenNow = hours.isOpenNow {
                    Text(isOpenNow ? "Open now" : "Closed now")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isOpenNow ? .green : .red)
                } else if let status = currentHoursStatus(hours) {
                    Text(status.text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(status.isOpen ? .green : .red)
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(hours.days.enumerated()), id: \.offset) { index, day in
                HStack(alignment: .top, spacing: 10) {
                    Text(day.day)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle( isToday(day.day) ? Theme.accent : Theme.text )
                        .frame(width: 92, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        if day.isClosed == true {
                            Text("Closed")
                        } else if day.isTwentyFourHours == true {
                            Text("Open 24 hours")
                        } else if day.periods.isEmpty {
                            Text("Hours unavailable")
                        } else {
                            ForEach(Array(day.periods.enumerated()), id: \.offset) { _, period in
                                Text("\(period.open) – \(period.close)")
                            }
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 9)
                .background(isToday(day.day) ? Theme.accent.opacity(0.08) : .clear)
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(Theme.border).frame(height: 1) }
                }
            }

            ForEach(hours.holidayNotes ?? [], id: \.self) { note in
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subtext)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.vertical, 4)
    }

    private func isToday(_ day: String) -> Bool {
        let today = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
        return day.lowercased() == today.lowercased() || day.lowercased() == String(today.prefix(3)).lowercased()
    }

    private func currentHoursStatus(_ hours: FindBusinessHours) -> (text: String, isOpen: Bool)? {
        let today = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
        guard let day = hours.days.first(where: { $0.day.lowercased() == today.lowercased() || $0.day.lowercased() == String(today.prefix(3)).lowercased() }) else { return nil }
        if day.isClosed == true { return ("Closed now", false) }
        if day.isTwentyFourHours == true { return ("Open now", true) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        let nowComponents = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let open = day.periods.contains { period in
            guard let start = formatter.date(from: period.open), let end = formatter.date(from: period.close) else { return false }
            let startComponents = Calendar.current.dateComponents([.hour, .minute], from: start)
            let endComponents = Calendar.current.dateComponents([.hour, .minute], from: end)
            let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
            let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
            return endMinutes < startMinutes ? now >= startMinutes || now <= endMinutes : now >= startMinutes && now <= endMinutes
        }
        return (open ? "Open now" : "Closed now", open)
    }

    private func parsedHours(from text: String) -> FindBusinessHours? {
        let source = text.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        guard let dayRegex = try? NSRegularExpression(pattern: "(?i)\\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\\b\\s*[-:]", options: []) else { return nil }
        let nsSource = source as NSString
        let matches = dayRegex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        guard !matches.isEmpty else { return nil }

        let timeRegex = try? NSRegularExpression(pattern: "(?i)(\\d{1,2}(?::\\d{2})?\\s*[AP]M)\\s*-\\s*(\\d{1,2}(?::\\d{2})?\\s*[AP]M)", options: [])
        let days: [FindBusinessHoursDay] = matches.enumerated().compactMap { index, match in
            let dayValue = nsSource.substring(with: match.range(at: 1))
            let start = match.range.location + match.range.length
            let end = index + 1 < matches.count ? matches[index + 1].range.location : nsSource.length
            let segment = nsSource.substring(with: NSRange(location: start, length: max(0, end - start)))
            if segment.range(of: "closed", options: .caseInsensitive) != nil {
                return FindBusinessHoursDay(day: normalizedDay(dayValue), periods: [], isClosed: true, isTwentyFourHours: false)
            }
            if segment.range(of: "24 hours", options: .caseInsensitive) != nil || segment.range(of: "open 24", options: .caseInsensitive) != nil {
                return FindBusinessHoursDay(day: normalizedDay(dayValue), periods: [], isClosed: false, isTwentyFourHours: true)
            }
            let periods = timeRegex?.matches(in: segment, range: NSRange(location: 0, length: (segment as NSString).length)).compactMap { periodMatch -> FindBusinessHoursPeriod? in
                guard periodMatch.numberOfRanges >= 3 else { return nil }
                return FindBusinessHoursPeriod(open: (segment as NSString).substring(with: periodMatch.range(at: 1)).replacingOccurrences(of: "  ", with: " "), close: (segment as NSString).substring(with: periodMatch.range(at: 2)).replacingOccurrences(of: "  ", with: " "))
            } ?? []
            return periods.isEmpty ? nil : FindBusinessHoursDay(day: normalizedDay(dayValue), periods: periods, isClosed: false, isTwentyFourHours: false)
        }
        guard !days.isEmpty else { return nil }
        return FindBusinessHours(timezone: nil, isOpenNow: nil, statusText: nil, days: days, holidayNotes: nil, sourceUrl: nil)
    }

    private func normalizedDay(_ value: String) -> String {
        switch value.lowercased().prefix(3) {
        case "mon": return "Monday"
        case "tue": return "Tuesday"
        case "wed": return "Wednesday"
        case "thu": return "Thursday"
        case "fri": return "Friday"
        case "sat": return "Saturday"
        case "sun": return "Sunday"
        default: return value
        }
    }

    // NLTokenizer understands sentence-ending punctuation vs. abbreviation
    // periods (e.g. "U.S.", "Dr.") correctly, unlike a naive split on ".".
    private func sentenceTokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
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

    private var currentTitle: String {
        if isGroundedAnswerSlide {
            return (viewModel.searchResponse?.query ?? "Find").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (currentResult?.title ?? viewModel.searchResponse?.query ?? "Find").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentBusinessName: String {
        businessTitleParts.name.isEmpty ? currentTitle : businessTitleParts.name
    }

    private var currentBusinessAddress: String {
        businessTitleParts.address
    }

    private var currentBusinessMeta: [String] {
        businessTitleParts.meta
    }

    private var businessTitleParts: (name: String, address: String, meta: [String]) {
        let title = (currentResult?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = title.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard segments.count > 1,
              let addressIndex = segments.firstIndex(where: { segment in
                  guard let first = segment.first else { return false }
                  return first.isNumber && segment.contains(",")
              }), addressIndex > 0 else {
            return (title, "", [])
        }

        let metadata = segments[segments.index(after: segments.startIndex)..<addressIndex]
            .flatMap { $0.components(separatedBy: " & ") }
            .filter { item in
                item.range(of: "updated|photos?|reviews?", options: [.caseInsensitive, .regularExpression]) != nil
            }
        return (segments[0], segments[addressIndex], metadata)
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

    private func goToNextResult() {
        guard selectedResultIndex < results.count - 1 else { return }
        viewModel.select(results[selectedResultIndex + 1])
    }

    private func goToPreviousResult() {
        guard selectedResultIndex > 0 else { return }
        viewModel.select(results[selectedResultIndex - 1])
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
    NavigationStack {
        SearchView(
            viewModel: SearchViewModel(
                apiClient: FindAPIClient(
                    config: AppConfig(
                        apiBaseURL: URL(string: "https://api.taliferro.tech/api")!,
                        apiKey: "preview"
                    )
                )
            )
        )
    }
}
