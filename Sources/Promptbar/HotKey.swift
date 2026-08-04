import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut, serializable so it can be stored in settings.
struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    /// ⌥⌘P — comfortable and free of conflicts with Spotlight (⌘Space),
    /// Raycast/Alfred (⌥Space or ⌘Space) and ChatGPT (⌥Space).
    static let `default` = KeyShortcut(keyCode: UInt32(kVK_ANSI_P),
                                       carbonModifiers: UInt32(optionKey | cmdKey),
                                       display: "⌥⌘P")

    init(keyCode: UInt32, carbonModifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.display = display
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // Require at least one "strong" modifier so plain keys aren't hijacked.
        guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control) else {
            return nil
        }
        var carbon: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); symbols += "⌘" }

        keyCode = UInt32(event.keyCode)
        carbonModifiers = carbon
        display = symbols + Self.keyName(for: event)
    }

    private static func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "?"
        }
    }
}

/// Global hotkey registration via Carbon (stable API, no special permissions).
final class HotKeyManager {
    static let shared = HotKeyManager()
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func register(_ shortcut: KeyShortcut) {
        unregister()
        installHandlerIfNeeded()
        let hotKeyID = EventHotKeyID(signature: OSType(0x5042_4152), id: 1) // "PBAR"
        RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}
