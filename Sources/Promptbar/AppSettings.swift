import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let menuIcons = ["quote.bubble", "text.quote", "sparkles", "bolt.fill", "terminal"]

    @Published var menuIcon: String {
        didSet { defaults.set(menuIcon, forKey: "menuIcon") }
    }

    /// Show the first line of the prompt text under the title in lists.
    @Published var showPreview: Bool {
        didSet { defaults.set(showPreview, forKey: "showPreview") }
    }

    @Published var hotkey: KeyShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(hotkey) {
                defaults.set(data, forKey: "hotkey")
            }
            HotKeyManager.shared.register(hotkey)
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        menuIcon = defaults.string(forKey: "menuIcon") ?? "quote.bubble"
        showPreview = defaults.object(forKey: "showPreview") as? Bool ?? true
        if let data = defaults.data(forKey: "hotkey"),
           let saved = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
            hotkey = saved
        } else {
            hotkey = .default
        }
    }
}
