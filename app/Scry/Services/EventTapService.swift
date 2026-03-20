import AppKit
import Combine
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Scry", category: "EventTap")

final class EventTapService {
    let forceClickPublisher = PassthroughSubject<NSPoint, Never>()
    let mouseDownPublisher = PassthroughSubject<Void, Never>()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private var passiveMonitor: Any?
    private let settings = AppSettings.shared
    fileprivate let debugLog = DebugLogStore.shared

    /// Whether force-touch detection is currently active.
    private(set) var isRunning = false

    /// True when using a passive NSEvent monitor instead of a CGEvent tap.
    private(set) var usingPassiveFallback = false

    // MARK: - Thread-safe state (accessed from CGEvent callback thread AND main thread)

    /// Lock protecting `_previousStage` and `_lastForceClickTime`.
    fileprivate var stateLock = os_unfair_lock()

    /// Previous pressure stage — used to detect the 0→2 transition.
    fileprivate var _previousStage = 0

    /// Timestamp of last fired force-click (for debouncing).
    fileprivate var _lastForceClickTime: Date = .distantPast

    /// Whether the left mouse button is currently held down.
    fileprivate var _mouseIsDown = false

    /// Timestamp of the current mouse-down (for hold-duration gating).
    fileprivate var _mouseDownTime: Date = .distantPast

    /// Whether a force-click was already fired during the current mouse-down.
    fileprivate var _forceClickFiredForCurrentPress = false

    /// Mouse position at the start of the current press (for drag distance gating).
    fileprivate var _mouseDownLocation: CGPoint = .zero

    /// Maximum distance (points) the cursor may ever move from the initial click and
    /// still count as a force-click.  Once exceeded at any point during the press, the
    /// gesture is permanently rejected (no re-triggering if the cursor drifts back).
    private static let maxForceClickDrift: CGFloat = 4

    /// True when drift exceeded the threshold at any point during the current press.
    fileprivate var _driftExceeded = false

    func start() {
        logger.info("start() called — isRunning=\(self.isRunning), forceClick=\(self.settings.forceClick)")
        guard !isRunning else {
            debugLog.log("EventTap", "start() called but already running", level: .debug)
            return
        }
        guard settings.forceClick else {
            debugLog.log("EventTap", "start() skipped — force click is disabled", level: .debug)
            return
        }

        debugLog.log("EventTap", "Creating CGEvent tap for mouse + pressure events...")

        // Monitor mouse events (reliable) + pressure type 34 (unreliable but worth trying).
        // Force click detection reads the raw mouseEventPressure field from drag events,
        // since pure pressure events (type 34) often don't flow through CGEvent taps.
        let pressureEventType = CGEventType(rawValue: 34)!
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << pressureEventType.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            debugLog.log("EventTap", "CGEvent.tapCreate FAILED — falling back to passive monitor", level: .warning)
            // Fallback: use passive event monitor (cannot suppress native Look Up)
            startPassiveMonitor()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        usingPassiveFallback = false
        debugLog.eventTapStatus = "Active (CGEvent tap)"
        debugLog.log("EventTap", "CGEvent tap created and enabled successfully")

        // Also start a passive monitor as a safety net — the CGEvent tap may silently
        // receive no events (e.g. inherited permissions from Xcode). Debouncing in
        // handleStageTransition prevents double-firing when both sources work.
        startPassiveMonitor()
        debugLog.eventTapStatus = "Active (CGEvent tap + passive)"

        // Health-check timer: re-enable tap if macOS disables it
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: Constants.Timing.healthCheckInterval, repeats: true) { [weak self] _ in
            self?.healthCheck()
        }
    }

    /// Tears down and re-creates the event tap + passive monitor.
    func restart() {
        stop()
        start()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        if let monitor = passiveMonitor {
            NSEvent.removeMonitor(monitor)
            passiveMonitor = nil
        }
        eventTap = nil
        runLoopSource = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        isRunning = false
        usingPassiveFallback = false
        os_unfair_lock_lock(&stateLock)
        _previousStage = 0
        _mouseIsDown = false
        _mouseDownTime = .distantPast
        _forceClickFiredForCurrentPress = false
        _driftExceeded = false
        _mouseDownLocation = .zero
        os_unfair_lock_unlock(&stateLock)
        debugLog.eventTapStatus = "Stopped"
    }

    // MARK: - Internal (called from C callback)

    fileprivate func handleStageTransition(stage: Int, pressure: Double) {
        os_unfair_lock_lock(&stateLock)
        let prevStage = _previousStage

        if prevStage < 2 && stage >= 2 {
            let now = Date()
            guard now.timeIntervalSince(_lastForceClickTime) > Constants.Timing.debounceCooldown else {
                debugLog.log("EventTap", "Stage \(prevStage)→\(stage) DEBOUNCED (cooldown)", level: .debug)
                _previousStage = stage
                os_unfair_lock_unlock(&stateLock)
                return
            }
            _lastForceClickTime = now
            _previousStage = stage
            os_unfair_lock_unlock(&stateLock)

            debugLog.log(
                "EventTap",
                "FORCE-CLICK detected (stage=\(stage), pressure=\(String(format: "%.3f", pressure)))"
            )
            DispatchQueue.main.async { [weak self] in
                self?.forceClickPublisher.send(NSEvent.mouseLocation)
            }
            return
        }

        _previousStage = stage == 0 ? 0 : stage
        os_unfair_lock_unlock(&stateLock)
    }

    /// Computes the hold duration required to trigger a force-click based on the
    /// user's sensitivity setting.  Higher sensitivity → shorter hold.
    ///
    /// CGEvent taps and global NSEvent monitors cannot receive graduated Force Touch
    /// pressure (NSEvent.pressure on drag events is always 1.0, and NSEventTypePressure
    /// events don't flow reliably through CGEvent taps or global monitors).  The only
    /// viable system-wide force-click detection is hold-duration + drift-distance gating.
    /// The sensitivity slider controls the required hold time:
    ///   sensitivity 1.0 → 0.3 s   (responsive but not hair-trigger)
    ///   sensitivity 0.5 → 0.55 s
    ///   sensitivity 0.1 → 0.75 s   (requires a deliberate hold)
    private func requiredHoldDuration() -> TimeInterval {
        let sensitivity = settings.pressureSensitivity
        let minDelay = 0.2
        let maxDelay = 0.7
        return minDelay + (1.0 - sensitivity) * (maxDelay - minDelay)
    }

    /// Called from the CGEvent callback for mouse events.
    /// Force-click is detected by hold-duration + drift-distance (not pressure — see
    /// `requiredHoldDuration()` for rationale).
    fileprivate func handleMouseEvent(type: CGEventType, location: CGPoint) {
        os_unfair_lock_lock(&stateLock)

        if type == .leftMouseDown {
            _mouseIsDown = true
            _mouseDownTime = Date()
            _forceClickFiredForCurrentPress = false
            _driftExceeded = false
            _mouseDownLocation = location
            os_unfair_lock_unlock(&stateLock)
            DispatchQueue.main.async { [weak self] in
                self?.mouseDownPublisher.send()
            }
            return
        }

        if type == .leftMouseUp {
            _mouseIsDown = false
            _forceClickFiredForCurrentPress = false
            _driftExceeded = false
            os_unfair_lock_unlock(&stateLock)
            return
        }

        // leftMouseDragged — check hold time + drift distance
        guard _mouseIsDown, !_forceClickFiredForCurrentPress, !_driftExceeded else {
            os_unfair_lock_unlock(&stateLock)
            return
        }

        // Check drift — once exceeded, permanently reject this press
        let dx = location.x - _mouseDownLocation.x
        let dy = location.y - _mouseDownLocation.y
        let drift = sqrt(dx * dx + dy * dy)
        guard drift <= Self.maxForceClickDrift else {
            _driftExceeded = true
            os_unfair_lock_unlock(&stateLock)
            return
        }

        // Require minimum hold duration
        let now = Date()
        let holdDuration = requiredHoldDuration()
        guard now.timeIntervalSince(_mouseDownTime) >= holdDuration else {
            os_unfair_lock_unlock(&stateLock)
            return
        }

        guard now.timeIntervalSince(_lastForceClickTime) > Constants.Timing.debounceCooldown else {
            os_unfair_lock_unlock(&stateLock)
            return
        }

        _lastForceClickTime = now
        _forceClickFiredForCurrentPress = true
        os_unfair_lock_unlock(&stateLock)

        let holdMs = now.timeIntervalSince(_mouseDownTime) * 1000
        debugLog.log(
            "EventTap",
            "FORCE-CLICK detected (hold \(String(format: "%.0fms", holdMs)), drift \(String(format: "%.1fpt", drift)))"
        )
        DispatchQueue.main.async { [weak self] in
            self?.forceClickPublisher.send(NSEvent.mouseLocation)
        }
    }

    // MARK: - Private

    private func startPassiveMonitor() {
        guard passiveMonitor == nil else {
            logger.info("startPassiveMonitor: already exists, skipping")
            return
        }
        logger.info("startPassiveMonitor: registering global monitor for pressure + mouse events...")
        // Note: .leftMouseDragged is NOT allowed in global monitors per Apple docs.
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.pressure, .leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return }

            switch event.type {
            case .pressure:
                let stage = event.stage
                let pressure = Double(event.pressure)

                os_unfair_lock_lock(&self.stateLock)
                let prevStage = self._previousStage
                os_unfair_lock_unlock(&self.stateLock)

                self.debugLog.log(
                    "Passive",
                    "pressure stage=\(stage) pressure=\(String(format: "%.3f", pressure)) (prev=\(prevStage))",
                    level: .debug
                )
                self.handleStageTransition(stage: stage, pressure: pressure)

            case .leftMouseDown:
                os_unfair_lock_lock(&self.stateLock)
                self._mouseIsDown = true
                self._mouseDownTime = Date()
                self._forceClickFiredForCurrentPress = false
                os_unfair_lock_unlock(&self.stateLock)

            case .leftMouseUp:
                os_unfair_lock_lock(&self.stateLock)
                self._mouseIsDown = false
                self._forceClickFiredForCurrentPress = false
                os_unfair_lock_unlock(&self.stateLock)

            default:
                break
            }
        }
        guard let monitor = monitor else {
            logger.error("startPassiveMonitor: NSEvent.addGlobalMonitorForEvents returned nil!")
            debugLog.log("EventTap", "Passive monitor failed to register (nil returned)", level: .error)
            return
        }
        passiveMonitor = monitor
        // Only update status flags when used as sole detection method (no CGEvent tap)
        if eventTap == nil {
            isRunning = true
            usingPassiveFallback = true
            debugLog.eventTapStatus = "Passive (fallback)"
        }
        logger.info("startPassiveMonitor: registered successfully")
        debugLog.log("EventTap", "Passive monitor started")
    }

    fileprivate func healthCheck() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            debugLog.log("EventTap", "Health check: tap was disabled, re-enabling", level: .warning)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    fileprivate func reEnableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

/// C-level callback for CGEventTap.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<EventTapService>.fromOpaque(userInfo).takeUnretainedValue()

    // Handle tap disabled events
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        service.reEnableTap()
        return Unmanaged.passUnretained(event)
    }

    // --- Mouse events: detect force-click via hold-duration + drift-distance ---
    // Note: NSEvent.pressure / CGEvent.mouseEventPressure on drag events is always 1.0
    // on Force Touch trackpads (Apple docs). Graduated pressure only flows through
    // NSEventTypePressure events which don't reach CGEvent taps or global monitors.
    if type == .leftMouseDown || type == .leftMouseDragged || type == .leftMouseUp {
        service.handleMouseEvent(type: type, location: event.location)

        // Never suppress mouse events
        return Unmanaged.passUnretained(event)
    }

    // --- Pressure events (type 34) — may not arrive, but handle if they do ---
    let pressureEventType = CGEventType(rawValue: 34)!
    guard type == pressureEventType else {
        return Unmanaged.passUnretained(event)
    }

    guard let nsEvent = NSEvent(cgEvent: event) else {
        service.debugLog.log("Tap", "NSEvent(cgEvent:) returned nil for type 34", level: .warning)
        return Unmanaged.passUnretained(event)
    }

    let stage = nsEvent.stage
    let pressure = Double(nsEvent.pressure)

    os_unfair_lock_lock(&service.stateLock)
    let prevStage = service._previousStage
    os_unfair_lock_unlock(&service.stateLock)

    service.debugLog.log(
        "Tap",
        "pressure stage=\(stage) pressure=\(String(format: "%.3f", pressure)) prev=\(prevStage)",
        level: .debug
    )

    service.handleStageTransition(stage: stage, pressure: pressure)

    // Suppress native Look Up if we just detected a force-click
    if prevStage < 2 && stage >= 2 {
        return nil
    }

    return Unmanaged.passUnretained(event)
}
