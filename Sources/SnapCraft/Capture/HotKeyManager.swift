import Carbon.HIToolbox
import AppKit

/// Registers system-wide capture hot keys via the Carbon Hot Key API (the only
/// supported route for global shortcuts that fire while another app is focused).
/// Re-`register` whenever the user edits a shortcut in Settings.
final class HotKeyManager {

    /// Called on the main thread when a bound shortcut fires.
    var onTrigger: ((CaptureKind) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var idToKind: [UInt32: CaptureKind] = [:]
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x534E4150 // 'SNAP'

    init() { installHandler() }

    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }

    func register(_ shortcuts: [CaptureKind: KeyCombo]) {
        unregisterAll()
        var nextID: UInt32 = 1
        for (kind, combo) in shortcuts {
            let hotID = EventHotKeyID(signature: signature, id: nextID)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers,
                                             hotID, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
                idToKind[nextID] = kind
            } else {
                NSLog("SnapCraft: failed to register hot key for \(kind) (status \(status))")
            }
            nextID += 1
        }
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        idToKind.removeAll()
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            mgr.dispatch(id: hkID.id)
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec,
                            Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    private func dispatch(id: UInt32) {
        guard let kind = idToKind[id] else { return }
        DispatchQueue.main.async { [weak self] in self?.onTrigger?(kind) }
    }
}
