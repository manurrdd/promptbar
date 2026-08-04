import SwiftUI
import AppKit

/// One-time welcome window. Menu bar apps are easy to miss on first launch,
/// so this points out where the app lives and how to use it.
@MainActor
enum Welcome {
    private static let defaultsKey = "hasSeenWelcome"
    private static var window: NSWindow?

    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        UserDefaults.standard.set(true, forKey: defaultsKey)

        let window = NSWindow(contentRect: .zero,
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView { window.close() }
            .environmentObject(AppSettings.shared))
        window.setContentSize(window.contentView!.fittingSize)
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct WelcomeView: View {
    @EnvironmentObject private var settings: AppSettings
    let close: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)

            Text("Welcome to Promptbar")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 14) {
                tip(icon: "menubar.arrow.up.rectangle",
                    title: "Lives in your menu bar",
                    text: Text("Look for the \(Image(systemName: settings.menuIcon)) icon at the top right of your screen. There's no Dock icon."))
                tip(icon: "keyboard",
                    title: "Open it from anywhere",
                    text: Text("Press **\(settings.hotkey.display)** in any app to open the quick panel. Type to filter, press return to copy."))
                tip(icon: "doc.on.doc",
                    title: "Click to copy",
                    text: Text("Clicking a prompt puts it on your clipboard, ready to paste."))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Get Started") { close() }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .padding(.top, 8)
        .frame(width: 400)
    }

    private func tip(icon: String, title: String, text: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                text
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
