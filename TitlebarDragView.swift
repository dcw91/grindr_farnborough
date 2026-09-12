import Cocoa

/// A full-width strip at the top of the window that both (a) reveals the
/// window's traffic-light buttons on hover, and (b) is itself always
/// draggable, so the whole bar moves the window — not just the three
/// small buttons.
final class TitlebarDragView: NSView {
    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
