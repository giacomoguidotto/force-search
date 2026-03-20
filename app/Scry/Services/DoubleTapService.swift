import AppKit
import Combine

/// Detects taps of a modifier key (Globe, Cmd, Opt, Ctrl, or Shift).
///
/// Uses `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` to observe
/// modifier transitions system-wide.
///
/// - **Globe key with system action disabled** ("Do Nothing"): fires on a single tap,
///   since the key would otherwise be inert.
/// - **All other cases**: requires a double-tap to avoid interfering with the
///   modifier's normal function.
final class DoubleTapService {
    let doubleTapPublisher = PassthroughSubject<Void, Never>()

    /// Maximum interval between two taps to count as a double-tap.
    private static let maxDoubleTapInterval: TimeInterval = 0.4

    /// Maximum duration a single press can last and still count as a "tap" (not a hold).
    private static let maxTapDuration: TimeInterval = 0.3

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let debugLog = DebugLogStore.shared

    private var modifier: DoubleTapModifier = .globe
    private var singleTapMode = false

    /// Timestamp when the modifier key was last pressed down.
    private var keyDownTime: Date?

    /// Timestamp of the last completed tap (key down + quick key up).
    private var lastTapTime: Date?

    /// Whether the modifier key is currently held down.
    private var isKeyDown = false

    func start(modifier: DoubleTapModifier, singleTap: Bool? = nil) {
        stop()
        self.modifier = modifier
        if let explicit = singleTap {
            self.singleTapMode = explicit
        } else {
            self.singleTapMode = modifier == .globe && !PermissionsService.shared.globeKeyConflict
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        let mode = singleTapMode ? "single-tap" : "double-tap"
        debugLog.log("DoubleTap", "\(modifier.displayName) monitor started (\(mode))")
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        keyDownTime = nil
        lastTapTime = nil
        isKeyDown = false
    }

    deinit {
        stop()
    }

    // MARK: - Private

    private func handleFlagsChanged(_ event: NSEvent) {
        let eventKeyCode = event.keyCode
        let isOurKey = eventKeyCode == modifier.keyCode
            || eventKeyCode == modifier.rightKeyCode
        guard isOurKey else { return }

        let modDown = event.modifierFlags.contains(modifier.modifierFlag)

        // Ignore if other modifiers are held — user is doing a chord.
        let allModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
        let otherModifiers = allModifiers.subtracting(modifier.modifierFlag)
        guard event.modifierFlags.isDisjoint(with: otherModifiers) else {
            keyDownTime = nil
            lastTapTime = nil
            return
        }

        if modDown && !isKeyDown {
            isKeyDown = true
            keyDownTime = Date()
        } else if !modDown && isKeyDown {
            isKeyDown = false

            guard let downTime = keyDownTime else { return }
            let now = Date()
            let pressDuration = now.timeIntervalSince(downTime)
            keyDownTime = nil

            // Was this a quick tap (not a hold)?
            guard pressDuration < Self.maxTapDuration else {
                lastTapTime = nil
                return
            }

            if singleTapMode {
                fireTap()
                return
            }

            // Double-tap: check if this is the second tap
            if let prevTap = lastTapTime,
               now.timeIntervalSince(prevTap) < Self.maxDoubleTapInterval {
                lastTapTime = nil
                fireTap()
            } else {
                lastTapTime = now
            }
        }
    }

    private func fireTap() {
        let mode = singleTapMode ? "single" : "double"
        debugLog.log("DoubleTap", "\(modifier.displayName) \(mode)-tap detected")
        DispatchQueue.main.async { [weak self] in
            self?.doubleTapPublisher.send()
        }
    }
}
