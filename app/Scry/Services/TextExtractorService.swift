import AppKit
import ApplicationServices
import NaturalLanguage

final class TextExtractorService {
    private let debugLog = DebugLogStore.shared
    private let screenshotService = ScreenshotService()
    private let ocrService = OCRService()

    /// The last screenshot captured during extraction, for use by the AI provider.
    private(set) var lastScreenshot: CGImage?

    /// Selection snapshot taken at mouse-down, before force-click auto-selects text.
    private var preGestureSelection: String?

    /// Whether the current AI configuration needs a screenshot.
    private var aiNeedsScreenshot: Bool {
        let settings = AppSettings.shared
        guard settings.aiEnabled else { return false }
        if settings.aiProviderType == .ollama {
            return OllamaService.shared.modelSupportsVision(settings.aiModel)
        }
        return true
    }

    /// Snapshots the current selection at mouse-down time (before force-click
    /// auto-selects text). Tries AX first, then clipboard simulation for browsers.
    func snapshotSelection() {
        // Try AX selected text (fast, works for native apps)
        if let text = extractViaAccessibility(), !text.isEmpty {
            preGestureSelection = text
            debugLog.log("TextExtractor", "Snapshot: got selection via AX", level: .debug)
            return
        }
        // Try clipboard simulation (works for browsers and other apps where AX fails)
        captureSelectionViaClipboard()
    }

    /// Async extraction pipeline: pre-gesture selection → word under cursor → Screenshot + OCR.
    func extractText(at point: NSPoint? = nil) async -> String? {
        let cursorPoint = point ?? NSEvent.mouseLocation

        // Use pre-gesture selection (force-click) or grab it now (hotkey/double-tap)
        var savedSelection = preGestureSelection
        preGestureSelection = nil
        if savedSelection == nil {
            savedSelection = extractViaAccessibility()
            if savedSelection == nil {
                savedSelection = extractSelectionViaClipboard()
            }
        }
        if let text = savedSelection, !text.isEmpty {
            debugLog.log("TextExtractor", "Got text via selection", level: .debug)
            if aiNeedsScreenshot {
                captureScreenshot(at: cursorPoint)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to get the word under cursor via AX element at position
        if let text = extractWordUnderCursor() {
            debugLog.log("TextExtractor", "Got text via word-under-cursor", level: .debug)
            if aiNeedsScreenshot {
                captureScreenshot(at: cursorPoint)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: Screenshot + OCR
        captureScreenshot(at: cursorPoint)
        if let screenshot = lastScreenshot, let ocrResult = await ocrService.recognizeText(in: screenshot) {
            let text = ocrResult.lineNearestCenter ?? ocrResult.fullText
            if !text.isEmpty {
                debugLog.log("TextExtractor", "Got text via OCR: \"\(text)\"", level: .debug)
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        debugLog.log("TextExtractor", "All extraction methods failed", level: .warning)
        return nil
    }

    /// Sync AX-only extraction (for backward compatibility).
    func extractSelectedText() -> String? {
        if let text = extractViaAccessibility(), !text.isEmpty {
            debugLog.log("TextExtractor", "Got text via Accessibility", level: .debug)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let text = extractWordUnderCursor() {
            debugLog.log("TextExtractor", "Got text via word-under-cursor", level: .debug)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        debugLog.log("TextExtractor", "All extraction methods failed", level: .warning)
        return nil
    }

    // MARK: - Screenshot

    private func captureScreenshot(at point: NSPoint) {
        let size = AppSettings.shared.screenshotRegionSize
        lastScreenshot = screenshotService.captureRegion(around: point, size: size)
    }

    // MARK: - Clipboard-based Selection (for browsers)

    /// Simulates Cmd+C to capture the current selection via the clipboard.
    /// Saves and restores the previous clipboard content. Returns the selected text.
    private func extractSelectionViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        // Save current clipboard contents
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> (String, Data)? in
            guard let type = item.types.first,
                  let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        } ?? []

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        // Virtual key 0x08 = 'c'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Wait briefly for the app to process the copy command
        usleep(50_000) // 50ms

        // Check if clipboard changed (meaning something was copied)
        var result: String?
        if pasteboard.changeCount != previousChangeCount,
           let text = pasteboard.string(forType: .string), !text.isEmpty {
            result = text
            debugLog.log("TextExtractor", "Got selection via clipboard (\(text.count) chars)", level: .debug)
        }

        // Restore previous clipboard contents
        pasteboard.clearContents()
        for (typeRaw, data) in savedItems {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(typeRaw))
        }

        return result
    }

    /// Called at mouse-down to snapshot selection before force-click auto-selects.
    private func captureSelectionViaClipboard() {
        preGestureSelection = extractSelectionViaClipboard()
    }

    // MARK: - Accessibility

    private func extractViaAccessibility() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            debugLog.log("TextExtractor", "AX: no frontmost app", level: .debug)
            return nil
        }

        let bundleID = frontApp.bundleIdentifier ?? "unknown"
        debugLog.log("TextExtractor", "AX: frontmost app = \(bundleID) (pid \(frontApp.processIdentifier))", level: .debug)

        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            debugLog.log("TextExtractor", "AX: frontmost is Scry, skipping", level: .debug)
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedValue: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusResult == .success else {
            debugLog.log("TextExtractor", "AX: failed to get focused element (error \(focusResult.rawValue))", level: .debug)
            return nil
        }

        // swiftlint:disable:next force_cast
        let focusedElement = focusedValue as! AXUIElement

        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        guard textResult == .success, let text = selectedTextValue as? String, !text.isEmpty else {
            debugLog.log("TextExtractor", "AX: no selected text (error \(textResult.rawValue))", level: .debug)
            return nil
        }

        return text
    }

    // MARK: - Word Under Cursor

    private func extractWordUnderCursor() -> String? {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first else { return nil }
        let axPoint = CGPoint(x: mouseLocation.x, y: screen.frame.height - mouseLocation.y)

        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(axPoint.x), Float(axPoint.y), &elementRef)
        guard result == .success, let element = elementRef else {
            debugLog.log("TextExtractor", "Word: no AX element at cursor position", level: .debug)
            return nil
        }

        var textValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)
        guard textResult == .success, let fullText = textValue as? String, !fullText.isEmpty else {
            debugLog.log("TextExtractor", "Word: no text found on element", level: .debug)
            return nil
        }

        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

        var offset = 0
        if rangeResult == .success, let axValue = rangeValue {
            var range = CFRange(location: 0, length: 0)
            // swiftlint:disable:next force_cast
            AXValueGetValue(axValue as! AXValue, .cfRange, &range)
            offset = range.location
        }

        return wordAt(offset: offset, in: fullText)
    }

    // MARK: - Helpers

    /// Uses NLTokenizer to find the word at the given character offset.
    private func wordAt(offset: Int, in text: String) -> String? {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        let index = text.index(text.startIndex, offsetBy: min(offset, text.count - 1), limitedBy: text.endIndex) ?? text.startIndex
        let range = tokenizer.tokenRange(at: index)

        guard range.lowerBound != range.upperBound else { return nil }
        return String(text[range])
    }
}
