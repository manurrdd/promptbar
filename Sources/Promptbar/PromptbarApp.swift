import SwiftUI

@main
struct PromptbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PromptStore.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra("Promptbar", systemImage: settings.menuIcon) {
            ContentView(isMenuBarWindow: true)
                .environmentObject(store)
                .environmentObject(settings)
        }
        .menuBarExtraStyle(.window)

        Window("Promptbar", id: "main") {
            ContentView(isMenuBarWindow: false)
                .environmentObject(store)
                .environmentObject(settings)
                .frame(minWidth: 380, minHeight: 420)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 540)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon only, no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor in
            HotKeyManager.shared.onPress = { QuickPanel.shared.toggle() }
            HotKeyManager.shared.register(AppSettings.shared.hotkey)
            Welcome.showIfNeeded()
        }
    }
}
