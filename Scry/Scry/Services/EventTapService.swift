import AppKit
import Combine
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Scry", category: "EventTap")

final class EventTapService {
    let forceClickPublisher = PassthroughSubject<NSPoint, Never>()

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

    /// Cached pressure threshold — read from settings on start() and updated via Combine.
    fileprivate var cachedPressureThreshold: Double = Constants.Defaults.pressureSensitivity

    private var settingsCancellable: AnyCancellable?

    func start() {
        logger.info("start() called — isRunning=\(self.isRunning), triggerMethod=\(String(describing: self.settings.triggerMethod))")
        guard !isRunning else {
            debugLog.log("EventTap", "start() called but already running")
            return
        }
        guard settings.triggerMethod == .forceClick else {
            debugLog.log("EventTap", "start() skipped — trigger method is not forceClick")
            return
        }

        // Cache pressure threshold and observe future changes
        cachedPressureThreshold = settings.pressureSensitivity
        settingsCancellable = settings.$pressureSensitivity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.cachedPressureThreshold = newValue
            }

        debugLog.log("EventTap", "Creating CGEvent tap for pressure events...")

        // NSEvent.EventType.pressure = 34; no CGEventType equivalent
        let pressureEventType: CGEventType = CGEventType(rawValue: 34)!
        let eventMask: CGEventMask = (1 << pressureEventType.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            debugLog.log("EventTap", "CGEvent.tapCreate FAILED — falling back to passive monitor")
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
        settingsCancellable?.cancel()
        settingsCancellable = nil
        isRunning = false
        usingPassiveFallback = false
        os_unfair_lock_lock(&stateLock)
        _previousStage = 0
        os_unfair_lock_unlock(&stateLock)
        debugLog.eventTapStatus = "Stopped"
    }

    // MARK: - Internal (called from C callback)

    fileprivate func handleStageTransition(stage: Int, pressure: Double) {
        let threshold = cachedPressureThreshold

        os_unfair_lock_lock(&stateLock)
        let prevStage = _previousStage

        if prevStage < 2 && stage >= 2 {
            let now = Date()
            guard now.timeIntervalSince(_lastForceClickTime) > Constants.Timing.debounceCooldown else {
                debugLog.log("EventTap", "Stage \(prevStage)→\(stage) DEBOUNCED (cooldown)")
                _previousStage = stage
                os_unfair_lock_unlock(&stateLock)
                return
            }
            guard pressure >= threshold else {
                debugLog.log(
                    "EventTap",
                    "Stage \(prevStage)→\(stage) BELOW THRESHOLD " +
                    "(pressure=\(String(format: "%.3f", pressure)), " +
                    "threshold=\(String(format: "%.3f", threshold)))"
                )
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

    /// Returns true if the event should be suppressed (native Look Up prevented).
    fileprivate func shouldSuppress(stage: Int, pressure: Double) -> Bool {
        let threshold = cachedPressureThreshold

        os_unfair_lock_lock(&stateLock)
        let prevStage = _previousStage
        let lastTime = _lastForceClickTime
        os_unfair_lock_unlock(&stateLock)

        if prevStage < 2 && stage >= 2 && pressure >= threshold {
            let now = Date()
            return now.timeIntervalSince(lastTime) <= 0.05
        }
        return false
    }

    // MARK: - Private

    private func startPassiveMonitor() {
        guard passiveMonitor == nil else {
            logger.info("startPassiveMonitor: already exists, skipping")
            return
        }
        logger.info("startPassiveMonitor: registering .pressure global monitor...")
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .pressure) { [weak self] event in
            guard let self = self else { return }
            let stage = event.stage
            let pressure = Double(event.pressure)

            os_unfair_lock_lock(&self.stateLock)
            let prevStage = self._previousStage
            os_unfair_lock_unlock(&self.stateLock)

            logger.info("PASSIVE pressure event: stage=\(stage) pressure=\(pressure)")
            self.debugLog.log(
                "Passive",
                "stage=\(stage) pressure=\(String(format: "%.3f", pressure)) (prev=\(prevStage))"
            )
            self.handleStageTransition(stage: stage, pressure: pressure)
        }
        guard let monitor = monitor else {
            logger.error("startPassiveMonitor: NSEvent.addGlobalMonitorForEvents returned nil!")
            debugLog.log("EventTap", "WARNING: passive monitor failed to register (nil returned)")
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
            debugLog.log("EventTap", "Health check: tap was disabled, re-enabling")
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
    guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
    let service = Unmanaged<EventTapService>.fromOpaque(userInfo).takeUnretainedValue()

    // Handle tap disabled events
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        service.reEnableTap()
        return Unmanaged.passRetained(event)
    }

    let pressureEventType = CGEventType(rawValue: 34)!
    guard type == pressureEventType else {
        return Unmanaged.passRetained(event)
    }

    guard let nsEvent = NSEvent(cgEvent: event) else {
        return Unmanaged.passRetained(event)
    }

    let stage = nsEvent.stage
    let pressure = Double(nsEvent.pressure)

    os_unfair_lock_lock(&service.stateLock)
    let prevStage = service._previousStage
    os_unfair_lock_unlock(&service.stateLock)

    if stage > 0 || prevStage > 0 {
        service.debugLog.log(
            "Pressure",
            "stage=\(stage) pressure=\(String(format: "%.3f", pressure)) (prev=\(prevStage))"
        )
    }

    // Process the transition
    service.handleStageTransition(stage: stage, pressure: pressure)

    // Suppress native Look Up if we're handling this force-click
    let threshold = service.cachedPressureThreshold
    if prevStage < 2 && stage >= 2 && pressure >= threshold {
        os_unfair_lock_lock(&service.stateLock)
        let lastTime = service._lastForceClickTime
        os_unfair_lock_unlock(&service.stateLock)

        let now = Date()
        if now.timeIntervalSince(lastTime) < 0.1 {
            return nil
        }
    }

    return Unmanaged.passRetained(event)
}
