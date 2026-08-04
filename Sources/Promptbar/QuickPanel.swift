import SwiftUI
import AppKit

/// Spotlight-style floating panel: opened with the global hotkey on top of any app,
/// without activating Promptbar or stealing more focus than necessary.
@MainActor
final class QuickPanel: NSObject, NSWindowDelegate {
    static let shared = QuickPanel()

    private var panel: NSPanel?

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(x: frame.midX - size.width / 2,
                                 y: frame.midY - size.height / 2 + frame.height * 0.12)
            panel.setFrameOrigin(origin)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let view = QuickPanelView(onClose: { [weak self] in self?.hide() })
            .environmentObject(PromptStore.shared)
            .environmentObject(AppSettings.shared)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = .preferredContentSize
        panel.contentView = hosting
        return panel
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

// MARK: - Panel view

private struct QuickPanelView: View {
    @EnvironmentObject private var store: PromptStore
    @EnvironmentObject private var settings: AppSettings
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    private var results: [Prompt] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return store.displayPrompts }
        return store.displayPrompts.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if !results.isEmpty {
                Divider()
                resultsList
            }
        }
        .frame(width: 560)
        .background(PanelMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            query = ""
            selection = 0
            searchFocused = true
        }
        .onChange(of: query) { selection = 0 }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.secondary)
            TextField("Search prompts…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .light))
                .focused($searchFocused)
                .onSubmit { copySelected() }
            if results.isEmpty && !query.isEmpty {
                Text("No results")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, prompt in
                        row(prompt, selected: index == selection)
                            .id(index)
                            .onTapGesture { copy(prompt) }
                            .onHover { inside in
                                if inside { selection = index }
                            }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 322)
            .onChange(of: selection) {
                proxy.scrollTo(selection)
            }
        }
    }

    private func row(_ prompt: Prompt, selected: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(prompt.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? .white : .primary)
                    .lineLimit(1)
                if settings.showPreview {
                    Text(prompt.text)
                        .font(.system(size: 11))
                        .foregroundStyle(selected ? .white.opacity(0.75) : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if prompt.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(selected ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.tertiary))
            }
            if selected {
                Text("↩")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor : .clear)
        )
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    private func copySelected() {
        guard results.indices.contains(selection) else { return }
        copy(results[selection])
    }

    private func copy(_ prompt: Prompt) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt.text, forType: .string)
        onClose()
    }
}

/// Native translucent material (the same one system popovers use).
private struct PanelMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
