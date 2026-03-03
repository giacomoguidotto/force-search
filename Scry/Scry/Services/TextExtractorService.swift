import AppKit
import ApplicationServices
import NaturalLanguage

final class TextExtractorService {
    /// Extracts the currently selected text from the frontmost application.
    func extractSelectedText() -> String? {
        // Try AX selected text first
        if let text = extractViaAccessibility(), !text.isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: try word under cursor via AX element at position
        if let text = extractWordUnderCursor() {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    // MARK: - Accessibility

    private func extractViaAccessibility() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Get focused element
        var focusedValue: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusResult == .success else { return nil }

        // swiftlint:disable:next force_cast
        let focusedElement = focusedValue as! AXUIElement

        // Get selected text
        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        guard textResult == .success, let text = selectedTextValue as? String, !text.isEmpty else {
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
}
