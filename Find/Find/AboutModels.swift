import Foundation

struct FindProductLink: Identifiable {
    var id: String { name }
    let name: String
    let body: String
    let iconURL: URL
    let ctaURL: URL
    let wideIcon: Bool

    init(name: String, body: String, iconURL: URL, ctaURL: URL, wideIcon: Bool = false) {
        self.name = name
        self.body = body
        self.iconURL = iconURL
        self.ctaURL = ctaURL
        self.wideIcon = wideIcon
    }
}

enum FindProducts {
    private static let assetBase = "https://find.taliferro.tech/assets/find/entities"

    static let moreFromTaliferroTech: [FindProductLink] = [
        FindProductLink(
            name: "Email Signature Builder",
            body: "Branded email signatures in minutes.",
            iconURL: URL(string: "\(assetBase)/email-signature-builder/logo.png")!,
            ctaURL: URL(string: "https://signature.taliferro.tech")!
        ),
        FindProductLink(
            name: "SayIt",
            body: "Social media built for organizations.",
            iconURL: URL(string: "\(assetBase)/sayit/logo.png")!,
            ctaURL: URL(string: "https://sayit.taliferro.tech")!
        ),
        FindProductLink(
            name: "Ask TODD",
            body: "Get unstuck with a clear next move.",
            iconURL: URL(string: "\(assetBase)/todd/TODD-icon.png")!,
            ctaURL: URL(string: "https://ask.taliferro.tech")!
        ),
        FindProductLink(
            name: "Lead Vault",
            body: "Search verified business contacts.",
            iconURL: URL(string: "\(assetBase)/lead-vault/logo.png")!,
            ctaURL: URL(string: "https://lead-vault.taliferro.tech")!
        ),
        FindProductLink(
            name: "Maya",
            body: "On-call marketing advice.",
            iconURL: URL(string: "\(assetBase)/maya/logo.png")!,
            ctaURL: URL(string: "https://maya.taliferro.tech")!,
            wideIcon: true
        ),
        FindProductLink(
            name: "Taliferro Music",
            body: "Stream music without the noise.",
            iconURL: URL(string: "\(assetBase)/music/logo.png")!,
            ctaURL: URL(string: "https://music.taliferro.com")!
        )
    ]

    static let momentumSystem: [FindProductLink] = [
        FindProductLink(
            name: "Pulse",
            body: "Capture live feedback & sentiment.",
            iconURL: URL(string: "\(assetBase)/pulse/pulse.png")!,
            ctaURL: URL(string: "https://pulse.taliferro.tech")!
        ),
        FindProductLink(
            name: "Network",
            body: "Relationship & contact intelligence.",
            iconURL: URL(string: "\(assetBase)/network/logo.png")!,
            ctaURL: URL(string: "https://network.taliferro.tech")!
        ),
        FindProductLink(
            name: "Outreach",
            body: "Campaigns & follow-up execution.",
            iconURL: URL(string: "\(assetBase)/outreach/logo.png")!,
            ctaURL: URL(string: "https://todd.taliferro.tech/outreach/app")!
        ),
        FindProductLink(
            name: "Moves",
            body: "Turn conversations into action.",
            iconURL: URL(string: "\(assetBase)/moves/logo.png")!,
            ctaURL: URL(string: "https://todd.taliferro.tech/moves/app")!
        ),
        FindProductLink(
            name: "Social",
            body: "Queued social work, one system.",
            iconURL: URL(string: "\(assetBase)/social/logo.png")!,
            ctaURL: URL(string: "https://todd.taliferro.tech/outreach/social")!
        ),
        FindProductLink(
            name: "Docs",
            body: "Reusable knowledge & context.",
            iconURL: URL(string: "\(assetBase)/docs/logo.png")!,
            ctaURL: URL(string: "https://todd.taliferro.tech/docs/app")!
        )
    ]
}
