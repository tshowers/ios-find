import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @State private var selectedTab: BottomTab = .home
    @State private var showingShareSheet = false
    @State private var showingSearchScreen = true

    private enum BottomTab: String, CaseIterable {
        case home = "HOME"
        case grid = "GRID"
        case history = "HISTORY"
        case info = "INFO"
        case bookmark = "BOOKMARK"
        case share = "SHARE"

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .grid: return "square.grid.2x2"
            case .history: return "arrow.counterclockwise"
            case .info: return "info.circle.fill"
            case .bookmark: return "bookmark"
            case .share: return "square.and.arrow.up"
            }
        }
    }

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
                    case .bookmark:
                        bookmarkView(screenWidth: geometry.size.width)
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
            .background(Color(red: 0.96, green: 0.94, blue: 0.98))
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
    }

    private func homeView(screenWidth: CGFloat) -> some View {
        Group {
            if showingSearchScreen || viewModel.searchResponse == nil {
                searchHomeView(screenWidth: screenWidth)
            } else {
                resultHomeView(screenWidth: screenWidth)
            }
        }
        .background(Color.white)
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
                    Task {
                        await viewModel.runSearch()
                        if viewModel.searchResponse != nil {
                            showingSearchScreen = false
                        }
                    }
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
                    .background(Color(red: 0.13, green: 0.71, blue: 0.93))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                Spacer(minLength: 340)
            }
            .frame(width: screenWidth)
            .background(Color.white)
        }
    }

    private func resultHomeView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            resultShelf(screenWidth: screenWidth)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let heroURL = heroImageURL {
                        AsyncImage(url: heroURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            default:
                                Rectangle()
                                    .fill(Color.black.opacity(0.06))
                            }
                        }
                        .frame(maxWidth: screenWidth, maxHeight: 300)
                        .frame(width: screenWidth)
                        .background(Color.black.opacity(0.06))
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Text("ANSWER")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color(red: 0.13, green: 0.71, blue: 0.93))

                        Text(currentTitle)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.black)

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(answerParagraphs, id: \.self) { paragraph in
                                Text(paragraph)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black.opacity(0.86))
                                    .lineSpacing(6)
                            }
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.96, green: 0.99, blue: 1.0), .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(red: 0.79, green: 0.9, blue: 1.0), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 18)
                    .offset(y: heroImageURL == nil ? 18 : -8)

                    Spacer(minLength: 18)
                }
                .frame(width: screenWidth)
                .padding(.bottom, 20)
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.white.opacity(0.72)
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.15)
                            Text("Refining result…")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.75))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.92))
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
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
            }
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
                            .fill(index == selectedResultIndex ? Color.gray.opacity(0.8) : Color.gray.opacity(0.35))
                            .frame(width: index == selectedResultIndex ? 8 : 6, height: index == selectedResultIndex ? 8 : 6)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 44, height: 1)
        }
        .frame(width: screenWidth)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func gridView(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("All results")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Text("\(results.count) found")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.gray)
                }

                if results.isEmpty {
                    emptyState("Run a search first.")
                } else {
                    let columns = [
                        GridItem(.flexible(), spacing: 0),
                        GridItem(.flexible(), spacing: 0)
                    ]

                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(0..<results.count, id: \.self) { index in
                            gridTile(results[index], index: index)
                        }
                    }
                }

            }
            .frame(width: screenWidth - 36, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background(Color.white)
        }
        .background(Color.white)
    }

    private func gridTile(_ result: FindRankedResult, index: Int) -> some View {
        Button {
            viewModel.select(result)
            selectedTab = .home
            showingSearchScreen = false
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL = imageURL(for: result) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                        }
                    }
                    .frame(height: 110)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(result.displayUrl)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.13, green: 0.71, blue: 0.93))
                        .lineLimit(1)

                    Text(result.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(result.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(.black.opacity(0.72))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, height: 260, alignment: .topLeading)
            .background(Color.white)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(index == selectedResultIndex ? Color(red: 0.13, green: 0.71, blue: 0.93) : Color.black.opacity(0.08), lineWidth: index == selectedResultIndex ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func historyView(screenWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Recent searches")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                if !viewModel.searchHistory.isEmpty {
                    Button("Clear") {
                        viewModel.clearHistory()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
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
                                        .foregroundStyle(.gray)
                                    Text(item)
                                        .font(.system(size: 16))
                                        .foregroundStyle(.black)
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
        .background(Color.white)
    }

    private func infoView(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("About Find")
                    .font(.system(size: 22, weight: .bold))

                infoCard("01", "One destination, not a list", "Find picks the single strongest result instead of showing you 10 blue links. Swipe to see alternatives.")
                infoCard("02", "Context pills & drill-down", "Tap a pill in the bottom bar to refine your search context. Find keeps your original query intact and swaps the active refinement instead of stacking duplicates.")
                infoCard("03", "People → Lead Vault", "Find shows the best web results first. When a query looks like a person, buyer, or prospect, you can continue the search in Lead Vault when you’re ready.")
                infoCard("04", "The philosophy", "Most search tools optimize for clicks. Find optimizes for answers. We believe the best search experience ends with you knowing something — not choosing between 10 links that might.")

                productsSection("More from Taliferro Tech", FindProducts.moreFromTaliferroTech)
                    .padding(.top, 8)

                productsSection("Momentum system", FindProducts.momentumSystem)

                VStack(spacing: 6) {
                    Text("BUILT BY")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.gray)
                    Text("Taliferro Tech")
                        .font(.system(size: 22, weight: .bold))
                    Text("Find is part of TODD — the Momentum System designed for teams that move fast and need information faster.")
                        .font(.system(size: 15))
                        .foregroundStyle(.black.opacity(0.72))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 14) {
                        Link("ty.showers@taliferro.com", destination: URL(string: "mailto:ty.showers@taliferro.com")!)
                        Link("taliferro.com", destination: URL(string: "https://taliferro.com")!)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.13, green: 0.71, blue: 0.93))
                    .padding(.top, 6)

                    Text("© \(currentYear) TODD. All rights reserved.")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.45))
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.top, 10)
            }
            .frame(width: screenWidth - 36, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .background(Color.white)
        }
        .background(Color.white)
    }

    private func bookmarkView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundStyle(.gray)
            Text("Bookmark requires sign-in")
                .font(.system(size: 20, weight: .bold))
            Text("On the full TODD experience, bookmarking saves the result to Knowledge when you’re logged in and subscribed.")
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(width: min(screenWidth - 64, 320))
            Spacer()
        }
        .frame(width: screenWidth)
        .background(Color.white)
    }

    private func shareView(screenWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer()
            if let url = currentShareURL {
                Text("Share this result")
                    .font(.system(size: 22, weight: .bold))
                Text(url.absoluteString)
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .frame(width: min(screenWidth - 48, 320))
                Button("Open Share Sheet") {
                    showingShareSheet = true
                }
                .font(.system(size: 17, weight: .bold))
                .frame(width: 220, height: 50)
                .background(Color(red: 0.13, green: 0.71, blue: 0.93))
                .foregroundStyle(.black)
                .clipShape(Capsule())
                Text("In TODD, this also offers the path to add the result into Knowledge when your account supports it.")
                    .font(.system(size: 15))
                    .foregroundStyle(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(width: min(screenWidth - 56, 320))
            } else {
                emptyState("Run a search first.")
            }
            Spacer()
        }
        .frame(width: screenWidth)
        .background(Color.white)
    }

    private var searchBar: some View {
        TextField("Search for anything...", text: $viewModel.query)
            .font(.system(size: 17))
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .submitLabel(.search)
            .onSubmit {
                Task {
                    await viewModel.runSearch()
                    if viewModel.searchResponse != nil {
                        showingSearchScreen = false
                    }
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
        .background(Color.white)
    }

    private func bottomBar(screenWidth: CGFloat, bottomInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(BottomTab.allCases, id: \.rawValue) { tab in
                Button {
                    if tab == .home {
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
                    .foregroundStyle(selectedTab == tab ? Color(red: 0.13, green: 0.71, blue: 0.93) : Color.gray.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(selectedTab == tab ? Color(red: 0.13, green: 0.71, blue: 0.93) : .clear)
                            .frame(height: 2)
                    }
                }
            }
        }
        .frame(width: screenWidth)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, max(10, bottomInset))
        .frame(height: 62 + max(10, bottomInset))
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func productsSection(_ title: String, _ products: [FindProductLink]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.gray)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(products) { product in
                    Link(destination: product.ctaURL) {
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: product.iconURL) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.black.opacity(0.06))
                                }
                            }
                            .frame(width: product.wideIcon ? 72 : 36, height: 36)

                            Text(product.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.leading)

                            Text(product.body)
                                .font(.system(size: 13))
                                .foregroundStyle(.black.opacity(0.62))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private func infoCard(_ number: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(number)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(Color(red: 0.13, green: 0.71, blue: 0.93))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 18, weight: .bold))

            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.72))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.gray)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var pillRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(currentPills, id: \.self) { pill in
                    Button {
                        selectedTab = .home
                        Task {
                            await viewModel.runDrillDown(from: baseQuery, pill: pill)
                            if viewModel.searchResponse != nil {
                                showingSearchScreen = false
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(pill)
                                }
                            } else {
                                Text(pill)
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(minWidth: 98)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .opacity(viewModel.isLoading ? 0.82 : 1)
    }

    private func stickyPillBar(screenWidth: CGFloat) -> some View {
        pillRow
            .frame(width: screenWidth, alignment: .leading)
            .frame(height: 42)
            .background(Color.white)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1)
            }
    }

    private var results: [FindRankedResult] {
        viewModel.searchResponse?.results ?? []
    }

    private var selectedResultIndex: Int {
        guard let selected = viewModel.selectedResult else { return 0 }
        return results.firstIndex(where: { $0.url == selected.url }) ?? 0
    }

    private var heroImageURL: URL? {
        if let image = currentResult?.imageUrl, let url = URL(string: image), !image.isEmpty {
            return url
        }
        if let image = viewModel.searchResponse?.answer?.imageUrl, let url = URL(string: image), !image.isEmpty {
            return url
        }
        return nil
    }

    private var answerParagraphs: [String] {
        let text = (viewModel.searchResponse?.answer?.text ?? currentResult?.answer ?? currentResult?.summary ?? "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return [] }

        let explicit = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if explicit.count > 1 { return explicit }

        let sentences = text.split(separator: ".").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if sentences.count < 4 { return [text] }

        var paragraphs: [String] = []
        var chunk: [String] = []
        for sentence in sentences {
            chunk.append(sentence + ".")
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
        (viewModel.searchResponse?.query ?? currentResult?.title ?? "Find").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func imageURL(for result: FindRankedResult) -> URL? {
        guard !result.imageUrl.isEmpty else { return nil }
        return URL(string: result.imageUrl)
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
        let tabs = 62 + max(10, bottomInset)
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
