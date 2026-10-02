import SwiftUI

// Mirrors the web app's Awards screen: progress bar + 2-column badge grid,
// deliberately no per-badge threshold or "N to go" countdown text - only
// the badge title and its locked/unlocked/mystery state are shown.
struct AwardsGridView: View {
    @ObservedObject var awardsService: FindAwardsService

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            progressBar

            LazyVGrid(columns: columns, spacing: 26) {
                ForEach(awardsService.awards) { award in
                    VStack(spacing: 10) {
                        AwardBadgeView(icon: award.icon, state: award.state)
                        Text(award.state == .mystery ? "\u{2014} \u{2014} \u{2014}" : award.title)
                            .font(Theme.font(12, weight: .bold))
                            .foregroundStyle(titleColor(for: award.state))
                            .tracking(award.state == .mystery ? 1 : 0)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accent.opacity(0.6), Theme.accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * awardsService.progressPercent)
                }
            }
            .frame(height: 6)

            Text("\(awardsService.unlockedCount) of \(awardsService.totalCount) unlocked")
                .font(Theme.font(12, weight: .bold))
                .foregroundStyle(Theme.subtext)
                .fixedSize()
        }
    }

    private func titleColor(for state: FindAwardState) -> Color {
        switch state {
        case .unlocked: return Theme.text
        case .locked: return Theme.subtext
        case .mystery: return Theme.subtext.opacity(0.5)
        }
    }
}
