import AppKit
import Combine

final class EventTapService {
    let forceClickPublisher = PassthroughSubject<NSPoint, Never>()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private var passiveMonitor: Any?
    private let settings = AppSettings.shared

    /// Whether force-touch detection is currently active.
    private(set) var isRunning = false

    /// Previous pressure stage — used to detect the 0→2 transition.
    fileprivate var previousStage = 0

    /// Timestamp of last fired force-click (for debouncing).
    fileprivate var lastForceClickTime: Date = .distantPast

    func start() {
        guard !isRunning else { return }
        guard settings.triggerMethod == .forceClick else { return }

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
            // Fallback: use passive event monitor (cannot suppress native Look Up)
            startPassiveMonitor()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true

        // Health-check timer: re-enable tap if macOS disables it
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: Constants.Timing.healthCheckInterval, repeats: true) { [weak self] _ in
            self?.healthCheck()
        }
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
        previousStage = 0
    }

    // MARK: - Internal (called from C callback)

    fileprivate func handleStageTransition(stage: Int, pressure: Double) {
        if previousStage < 2 && stage >= 2 {
            let now = Date()
            guard now.timeIntervalSince(lastForceClickTime) > Constants.Timing.debounceCooldown else {
                previousStage = stage
                return
            }
            guard pressure >= settings.pressureSensitivity else {
                previousStage = stage
                return
            }
            lastForceClickTime = now
            DispatchQueue.main.async { [weak self] in
                self?.forceClickPublisher.send(NSEvent.mouseLocation)
            }
        }
        previousStage = stage
        if stage == 0 {
            previousStage = 0
        }
    }

    /// Returns true if the event should be suppressed (native Look Up prevented).
    fileprivate func shouldSuppress(stage: Int, pressure: Double) -> Bool {
        if previousStage < 2 && stage >= 2 && pressure >= settings.pressureSensitivity {
            let now = Date()
            return now.timeIntervalSince(lastForceClickTime) <= 0.05 // Just published
        }
        return false
    }

    // MARK: - Private

    private func startPassiveMonitor() {
        passiveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .pressure) { [weak self] event in
            guard let self = self else { return }
            self.handleStageTransition(stage: event.stage, pressure: Double(event.pressure))
        }
        isRunning = true
    }

    fileprivate func healthCheck() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
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
    let prevStage = service.previousStage

    // Process the transition
    service.handleStageTransition(stage: stage, pressure: pressure)

    // Suppress native Look Up if we're handling this force-click
    if prevStage < 2 && stage >= 2 && pressure >= AppSettings.shared.pressureSensitivity {
        let now = Date()
        if now.timeIntervalSince(service.lastForceClickTime) < 0.1 {
            return nil
        }
    }

    return Unmanaged.passRetained(event)
}
