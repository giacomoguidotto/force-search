import AppKit
import Carbon
import Combine

final class HotKeyService {
    let hotKeyPublisher = PassthroughSubject<Void, Never>()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var currentKeyCombo: KeyCombo?

    private static let hotKeyID = EventHotKeyID(signature: OSType(0x4653_4B59), // "FSKY"
                                                  id: 1)

    init() {
        installCarbonHandler()
    }

    deinit {
        unregister()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    func register(keyCombo: KeyCombo) {
        unregister()
        currentKeyCombo = keyCombo

        let hotKeyID = Self.hotKeyID
        let status = RegisterEventHotKey(
            keyCombo.keyCode,
            keyCombo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("[HotKeyService] Failed to register hotkey: \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Private

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr, hotKeyID.id == HotKeyService.hotKeyID.id else {
                return OSStatus(eventNotHandledErr)
            }

            DispatchQueue.main.async {
                service.hotKeyPublisher.send()
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
