import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var groqAPIKey:      String  = ""
    @Published var anthropicAPIKey: String  = ""
    @Published var deepgramAPIKey:  String  = ""
    @Published var groqModel:       String  = "llama-3.3-70b-versatile"
    @Published var claudeModel:     String  = "claude-sonnet-4-6"
    @Published var whisperModel:    String  = "small"
    @Published var overlayOpacity:  Double  = 0.75
    @Published var vadThreshold:    Double  = 0.015
    @Published var firstLaunch:     Bool    = true

    private let defaults = UserDefaults.standard

    private init() { load() }

    func load() {
        groqAPIKey      = defaults.string(forKey: "groqAPIKey")      ?? ""
        anthropicAPIKey = defaults.string(forKey: "anthropicAPIKey") ?? ""
        deepgramAPIKey  = defaults.string(forKey: "deepgramAPIKey")  ?? ""
        groqModel       = defaults.string(forKey: "groqModel")       ?? "llama-3.3-70b-versatile"
        claudeModel     = defaults.string(forKey: "claudeModel")     ?? "claude-sonnet-4-6"
        whisperModel    = defaults.string(forKey: "whisperModel")    ?? "small"
        overlayOpacity  = defaults.double(forKey: "overlayOpacity").nonZero ?? 0.75
        vadThreshold    = defaults.double(forKey: "vadThreshold").nonZero   ?? 0.015
        firstLaunch     = defaults.object(forKey: "firstLaunch") == nil ? true
                          : defaults.bool(forKey: "firstLaunch")
    }

    func save() {
        defaults.set(groqAPIKey,      forKey: "groqAPIKey")
        defaults.set(anthropicAPIKey, forKey: "anthropicAPIKey")
        defaults.set(deepgramAPIKey,  forKey: "deepgramAPIKey")
        defaults.set(groqModel,       forKey: "groqModel")
        defaults.set(claudeModel,     forKey: "claudeModel")
        defaults.set(whisperModel,    forKey: "whisperModel")
        defaults.set(overlayOpacity,  forKey: "overlayOpacity")
        defaults.set(vadThreshold,    forKey: "vadThreshold")
        defaults.set(false,           forKey: "firstLaunch")
        firstLaunch = false
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
