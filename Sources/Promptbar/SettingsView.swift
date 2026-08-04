import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: PromptStore
    @EnvironmentObject private var settings: AppSettings

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    @State private var dataMessage: String?

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                LabeledContent("Open quick panel") {
                    ShortcutRecorder(shortcut: $settings.hotkey)
                }
                if settings.hotkey != .default {
                    Button("Reset to default (⌥⌘P)") {
                        settings.hotkey = .default
                    }
                    .controlSize(.small)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }
                if let launchError {
                    Text(launchError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                Picker("Menu bar icon", selection: $settings.menuIcon) {
                    ForEach(AppSettings.menuIcons, id: \.self) { icon in
                        Image(systemName: icon).tag(icon)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show text preview", isOn: $settings.showPreview)
            }

            Section("Data") {
                LabeledContent("\(store.prompts.count) prompts saved") {
                    Button("Export…") { exportPrompts() }
                    Button("Import…") { importPrompts() }
                }
                if let dataMessage {
                    Text(dataMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = "Not available: install Promptbar.app in /Applications (doesn't work with \"swift run\")."
        }
    }

    private func exportPrompts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "promptbar-export.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportData().write(to: url)
            dataMessage = "Exported to \(url.lastPathComponent)."
        } catch {
            dataMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importPrompts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let count = try store.importData(try Data(contentsOf: url))
            dataMessage = "Imported \(count) prompts (existing ones updated, new ones added)."
        } catch {
            dataMessage = "Import failed: invalid file."
        }
    }
}

// MARK: - Shortcut recorder

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut
    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording = true
        } label: {
            Text(isRecording ? "Press a shortcut…" : shortcut.display)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(isRecording ? .secondary : .primary)
                .frame(minWidth: 110)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isRecording ? Color.accentColor : .secondary.opacity(0.3))
                )
        }
        .buttonStyle(.plain)
        .background(
            KeyCapture(isRecording: $isRecording) { captured in
                if let captured {
                    shortcut = captured
                }
                isRecording = false
            }
        )
    }
}

/// Invisible AppKit view that captures the next shortcut pressed.
private struct KeyCapture: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (KeyShortcut?) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onCapture = onCapture
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class CaptureView: NSView {
        var onCapture: ((KeyShortcut?) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { // Esc cancels
                finish(nil)
                return
            }
            if let shortcut = KeyShortcut(event: event) {
                finish(shortcut)
            } else {
                NSSound.beep()
            }
        }

        private func finish(_ shortcut: KeyShortcut?) {
            onCapture?(shortcut)
            window?.makeFirstResponder(nil)
        }
    }
}
