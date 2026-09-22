import SwiftUI

// Mirrors the web app's unlock-celebration overlay and its staggered reveal:
// badge scale-in spring -> ring draws itself -> title -> description -> CTA,
// each beat landing before the next starts, with a haptic tied to the badge
// landing. Full-screen, sits above everything else (tab bar included).
struct AwardUnlockView: View {
    let award: FindAward
    let unlockedCount: Int
    let totalCount: Int
    let onContinue: () -> Void

    @State private var glowVisible = false
    @State private var badgeScale: CGFloat = 0.6
    @State private var badgeOpacity: Double = 0
    @State private var ringProgress: CGFloat = 0
    @State private var eyebrowVisible = false
    @State private var titleVisible = false
    @State private var descVisible = false
    @State private var hintVisible = false
    @State private var buttonVisible = false
    @State private var hapticTrigger = false

    var body: some View {
        ZStack {
            Theme.background.opacity(0.94)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            RadialGradient(colors: [Theme.accent.opacity(0.32), Theme.accent.opacity(0.08), .clear], center: .center, startRadius: 4, endRadius: 170)
                .frame(width: 320, height: 320)
                .opacity(glowVisible ? 1 : 0)
                .scaleEffect(glowVisible ? 1 : 0.85)
                .offset(y: -140)

            VStack(spacing: 0) {
                Spacer(minLength: 90)

                Text("AWARD UNLOCKED")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Theme.subtext)
                    .opacity(eyebrowVisible ? 1 : 0)
                    .offset(y: eyebrowVisible ? 0 : 8)

                ZStack {
                    AwardBadgeView(icon: award.icon, state: .unlocked, size: 176)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color.white.opacity(0.65), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 176 * 0.46, height: 176 * 0.46)
                        .rotationEffect(.degrees(-90))
                }
                .scaleEffect(badgeScale)
                .opacity(badgeOpacity)
                .padding(.top, 28)

                Text(award.title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 8)

                Text("\u{201C}\(award.copy)\u{201D}")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)
                    .padding(.horizontal, 40)
                    .opacity(descVisible ? 1 : 0)
                    .offset(y: descVisible ? 0 : 8)

                Text("\(unlockedCount) of \(totalCount) unlocked")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.subtext)
                    .padding(.top, 20)
                    .opacity(hintVisible ? 1 : 0)
                    .offset(y: hintVisible ? 0 : 8)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 8)
            }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .task { await playSequence() }
    }

    @MainActor
    private func playSequence() async {
        withAnimation(.easeOut(duration: 0.5).delay(0.05)) { eyebrowVisible = true }
        withAnimation(.easeOut(duration: 1.0).delay(0.15)) { glowVisible = true }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.62).delay(0.1)) {
            badgeScale = 1
            badgeOpacity = 1
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
        hapticTrigger.toggle()
        withAnimation(.easeOut(duration: 0.7)) { ringProgress = 1 }

        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.easeOut(duration: 0.45)) { titleVisible = true }

        try? await Task.sleep(nanoseconds: 130_000_000)
        withAnimation(.easeOut(duration: 0.45)) { descVisible = true }

        try? await Task.sleep(nanoseconds: 170_000_000)
        withAnimation(.easeOut(duration: 0.4)) { hintVisible = true }

        try? await Task.sleep(nanoseconds: 100_000_000)
        withAnimation(.easeOut(duration: 0.4)) { buttonVisible = true }
    }
}

#Preview {
    AwardUnlockView(
        award: FindAward(id: "connector", title: "The Connector", threshold: 10, copy: "You saw the thread before anyone said it out loud.", icon: .connector),
        unlockedCount: 4, totalCount: 10, onContinue: {}
    )
}
