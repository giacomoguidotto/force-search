import AppKit
import ApplicationServices
import NaturalLanguage

final class TextExtractorService {
    private let debugLog = DebugLogStore.shared

    /// Extracts the currently selected text from the frontmost application.
    func extractSelectedText() -> String? {
        // Try AX selected text first
        if let text = extractViaAccessibility(), !text.isEmpty {
            debugLog.log("TextExtractor", "Got text via Accessibility")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: try word under cursor via AX element at position
        if let text = extractWordUnderCursor() {
            debugLog.log("TextExtractor", "Got text via word-under-cursor")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: simulate Cmd+C and read clipboard
        if let text = extractViaClipboard() {
            debugLog.log("TextExtractor", "Got text via clipboard fallback")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        debugLog.log("TextExtractor", "All extraction methods failed")
        return nil
    }

    // MARK: - Accessibility

    private func extractViaAccessibility() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            debugLog.log("TextExtractor", "AX: no frontmost app")
            return nil
        }

        let bundleID = frontApp.bundleIdentifier ?? "unknown"
        debugLog.log("TextExtractor", "AX: frontmost app = \(bundleID) (pid \(frontApp.processIdentifier))")

        // Skip if Scry itself is frontmost — we won't have selected text in our own windows
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            debugLog.log("TextExtractor", "AX: frontmost is Scry, skipping")
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Get focused element
        var focusedValue: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusResult == .success else {
            debugLog.log("TextExtractor", "AX: failed to get focused element (error \(focusResult.rawValue))")
            return nil
        }

        // swiftlint:disable:next force_cast
        let focusedElement = focusedValue as! AXUIElement

        // Get selected text
        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        guard textResult == .success, let text = selectedTextValue as? String, !text.isEmpty else {
            debugLog.log("TextExtractor", "AX: no selected text (error \(textResult.rawValue))")
            return nil
        }

        return text
    }

    // MARK: - Word Under Cursor Fallback

    private func extractWordUnderCursor() -> String? {
        let mouseLocation = NSEvent.mouseLocation

        // Convert from AppKit bottom-left to AX top-left coordinates
        guard let screen = NSScreen.screens.first else { return nil }
        let axPoint = CGPoint(x: mouseLocation.x, y: screen.frame.height - mouseLocation.y)

        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(axPoint.x), Float(axPoint.y), &elementRef)
        guard result == .success, let element = elementRef else { return nil }

        // Try to get the full text value
        var textValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)
        guard textResult == .success, let fullText = textValue as? String, !fullText.isEmpty else {
            return nil
        }

        // Get insertion point or find word at cursor position
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

        var offset = 0
        if rangeResult == .success, let axValue = rangeValue {
            var range = CFRange(location: 0, length: 0)
            // swiftlint:disable:next force_cast
            AXValueGetValue(axValue as! AXValue, .cfRange, &range)
            offset = range.location
        }

        // Use NLTokenizer to find the word boundary at this offset
        return wordAt(offset: offset, in: fullText)
    }

    /// Uses NLTokenizer to find the word at the given character offset.
    private func wordAt(offset: Int, in text: String) -> String? {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        let index = text.index(text.startIndex, offsetBy: min(offset, text.count - 1), limitedBy: text.endIndex) ?? text.startIndex
        let range = tokenizer.tokenRange(at: index)

        guard range.lowerBound != range.upperBound else { return nil }
        return String(text[range])
    }

    // MARK: - Clipboard Fallback

    /// Simulates Cmd+C to copy the current selection, then reads from the pasteboard.
    private func extractViaClipboard() -> String? {
        // Save current clipboard content to restore later
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // 'c' key
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)

        // Brief wait for the copy to complete
        usleep(50_000)  // 50ms

        // Check if clipboard changed
        guard pasteboard.changeCount != previousChangeCount else {
            debugLog.log("TextExtractor", "Clipboard: pasteboard unchanged after Cmd+C")
            return nil
        }

        let copiedText = pasteboard.string(forType: .string)

        // Restore previous clipboard content
        if let previous = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }

        guard let text = copiedText, !text.isEmpty else {
            debugLog.log("TextExtractor", "Clipboard: no text after Cmd+C")
            return nil
        }

        return text
    }
}
