import Carbon
import AppKit

/// Глобальний хоткей (Carbon RegisterEventHotKey) — не потребує дозволу Accessibility.
final class GlobalHotKey {
    static let shared = GlobalHotKey()
    private var ref: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandler: EventHandlerRef?

    /// ⌘⇧D за замовчуванням (keyCode 2 = D).
    func register(keyCode: UInt32 = 2, modifiers: UInt32 = UInt32(cmdKey | shiftKey), action: @escaping () -> Void) {
        unregister()
        handler = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().handler?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        let id = EventHotKeyID(signature: OSType(0x554C4452), id: 1)   // "ULDR"
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }
}
