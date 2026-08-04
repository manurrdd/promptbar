import Foundation

@MainActor
final class PromptStore: ObservableObject {
    static let shared = PromptStore()

    @Published var prompts: [Prompt] = [] {
        didSet { save() }
    }

    /// Pinned first, keeping manual order within each group.
    var displayPrompts: [Prompt] {
        prompts.filter(\.pinned) + prompts.filter { !$0.pinned }
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Promptbar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prompts.json")
    }()

    init() {
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Prompt].self, from: data) else {
            prompts = [
                Prompt(title: "Summarize text",
                       text: "Summarize the following text in 3 key points, clear and to the point:"),
                Prompt(title: "Fix email",
                       text: "Fix the spelling and improve the tone of this email while keeping my style:")
            ]
            return
        }
        prompts = decoded
    }

    private func save() {
        guard let data = try? Self.encoder.encode(prompts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    func add(_ prompt: Prompt) {
        prompts.insert(prompt, at: 0)
    }

    func update(_ prompt: Prompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        prompts[index] = prompt
    }

    func delete(_ prompt: Prompt) {
        prompts.removeAll { $0.id == prompt.id }
    }

    func togglePin(_ prompt: Prompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        prompts[index].pinned.toggle()
    }

    // MARK: - Export / Import

    func exportData() throws -> Data {
        try Self.encoder.encode(prompts)
    }

    /// Merges: updates existing prompts (by id) and appends new ones. Returns how many were imported.
    func importData(_ data: Data) throws -> Int {
        let incoming = try JSONDecoder().decode([Prompt].self, from: data)
        for prompt in incoming {
            if prompts.contains(where: { $0.id == prompt.id }) {
                update(prompt)
            } else {
                prompts.append(prompt)
            }
        }
        return incoming.count
    }
}
