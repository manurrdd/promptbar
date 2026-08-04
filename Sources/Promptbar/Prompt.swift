import Foundation

struct Prompt: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var text: String
    var pinned = false

    init(id: UUID = UUID(), title: String, text: String, pinned: Bool = false) {
        self.id = id
        self.title = title
        self.text = text
        self.pinned = pinned
    }

    // Tolerant decoding: older JSON files have no "pinned" key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }
}
