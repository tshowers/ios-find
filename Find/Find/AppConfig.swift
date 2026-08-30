import Foundation

struct AppConfig {
    let apiBaseURL: URL
    let apiKey: String

    static func fromBundle(bundle: Bundle = .main) -> AppConfig {
        let bundledBaseURLString = bundle.object(forInfoDictionaryKey: "FIND_API_BASE_URL") as? String ?? ""
        let bundledAPIKey = bundle.object(forInfoDictionaryKey: "FIND_API_KEY") as? String ?? ""

        // For the starter app, fall back to the same backend contract the web app uses
        // so local Xcode configuration does not block first launch.
        let baseURLString = bundledBaseURLString.isEmpty
            ? "https://api.taliferro.tech/api"
            : bundledBaseURLString
        let apiKey = bundledAPIKey.isEmpty || bundledAPIKey == "CHANGE_ME"
            ? "AIzaSyCAAgRd8tq9PXkPKE2zddseYtZ-Xx_P8mU"
            : bundledAPIKey

        guard let apiBaseURL = URL(string: baseURLString), !apiKey.isEmpty else {
            fatalError("Missing FIND_API_BASE_URL or FIND_API_KEY.")
        }

        return AppConfig(apiBaseURL: apiBaseURL, apiKey: apiKey)
    }
}
