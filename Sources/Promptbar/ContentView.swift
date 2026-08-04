import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: PromptStore
    @EnvironmentObject private var settings: AppSettings
    let isMenuBarWindow: Bool

    private enum Screen: Equatable {
        case list
        case editor(Prompt, isNew: Bool)
    }

    @State private var screen: Screen = .list
    @State private var search = ""
    @State private var showToast = false
    @State private var toastTask: Task<Void, Never>?

    private var filtered: [Prompt] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.displayPrompts }
        return store.displayPrompts.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            switch screen {
            case .list:
                listScreen
            case .editor(let prompt, let isNew):
                PromptEditor(prompt: prompt, isNew: isNew) { result in
                    if let result {
                        isNew ? store.add(result) : store.update(result)
                    }
                    withAnimation(.snappy) { screen = .list }
                }
            }
        }
        .frame(width: isMenuBarWindow ? 340 : nil,
               height: isMenuBarWindow ? 440 : nil)
    }

    // MARK: - List

    private var listScreen: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { prompt in
                            PromptRow(prompt: prompt,
                                      showPreview: settings.showPreview,
                                      onCopy: { copy(prompt) },
                                      onPin: { store.togglePin(prompt) },
                                      onEdit: {
                                          withAnimation(.snappy) {
                                              screen = .editor(prompt, isNew: false)
                                          }
                                      },
                                      onDelete: { store.delete(prompt) })
                        }
                    }
                    .padding(6)
                }
            }

            Divider()
            footer
        }
        .overlay(alignment: .bottom) { toast }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search prompts", text: $search)
                .textFieldStyle(.plain)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: search.isEmpty ? "quote.bubble" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(search.isEmpty ? "No prompts yet" : "No results")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if search.isEmpty {
                Text("Press “New” to create your first one.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    screen = .editor(Prompt(title: "", text: ""), isNew: true)
                }
            } label: {
                Label("New", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            Spacer()

            Text(settings.hotkey.display)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .help("Global shortcut for the quick panel")

            if isMenuBarWindow {
                OpenMainWindowButton()
            }

            OpenSettingsButton()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Promptbar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var toast: some View {
        Group {
            if showToast {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.quaternary))
                    .padding(.bottom, 44)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: showToast)
    }

    private func copy(_ prompt: Prompt) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt.text, forType: .string)

        toastTask?.cancel()
        showToast = true
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            showToast = false
        }
    }
}

// MARK: - Row

private struct PromptRow: View {
    let prompt: Prompt
    let showPreview: Bool
    let onCopy: () -> Void
    let onPin: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if showPreview {
                        Text(prompt.text)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if hovering {
                    HStack(spacing: 2) {
                        rowButton(prompt.pinned ? "pin.slash" : "pin",
                                  help: prompt.pinned ? "Unpin" : "Pin to top",
                                  action: onPin)
                        rowButton("pencil", help: "Edit", action: onEdit)
                        rowButton("trash", help: "Delete", role: .destructive, action: onDelete)
                    }
                    .transition(.opacity)
                } else if prompt.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hovering ? Color.primary.opacity(0.07) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
        }
        .contextMenu {
            Button("Copy", action: onCopy)
            Button(prompt.pinned ? "Unpin" : "Pin to top", action: onPin)
            Button("Edit", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private func rowButton(_ symbol: String, help: String,
                           role: ButtonRole? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Editor

private struct PromptEditor: View {
    @State var prompt: Prompt
    let isNew: Bool
    let onFinish: (Prompt?) -> Void

    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isNew ? "New Prompt" : "Edit Prompt")
                .font(.system(size: 13, weight: .semibold))

            TextField("Title", text: $prompt.title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)

            TextEditor(text: $prompt.text)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary)
                )

            HStack {
                Spacer()
                Button("Cancel") { onFinish(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onFinish(prompt) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(prompt.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .onAppear { titleFocused = true }
    }
}

// MARK: - Footer buttons

private struct OpenMainWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Image(systemName: "macwindow")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Open as window")
    }
}

private struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Settings")
    }
}
