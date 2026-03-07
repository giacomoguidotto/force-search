import AppKit
import ApplicationServices
import NaturalLanguage

final class TextExtractorService {
    private let debugLog = DebugLogStore.shared
    private let screenshotService = ScreenshotService()
    private let ocrService = OCRService()

    /// The last screenshot captured during extraction, for use by the AI provider.
    private(set) var lastScreenshot: CGImage?

    /// Async extraction pipeline: AX selected text → AX word under cursor → Screenshot + OCR.
    func extractText(at point: NSPoint? = nil) async -> String? {
        let cursorPoint = point ?? NSEvent.mouseLocation

        // Try AX selected text first (works when user pre-selected text)
        if let text = extractViaAccessibility(), !text.isEmpty {
            debugLog.log("TextExtractor", "Got text via Accessibility", level: .debug)
            // Still capture screenshot for AI if enabled
            if AppSettings.shared.aiEnabled {
                captureScreenshot(at: cursorPoint)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to get the word under cursor via AX element at position
        if let text = extractWordUnderCursor() {
            debugLog.log("TextExtractor", "Got text via word-under-cursor", level: .debug)
            if AppSettings.shared.aiEnabled {
                captureScreenshot(at: cursorPoint)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: Screenshot + OCR
        captureScreenshot(at: cursorPoint)
        if let screenshot = lastScreenshot, let ocrResult = await ocrService.recognizeText(in: screenshot) {
            let text = ocrResult.wordNearestCenter ?? ocrResult.fullText
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
