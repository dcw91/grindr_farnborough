import Cocoa

/// A full-width strip at the top of the window that both (a) reveals the
/// window's traffic-light buttons on hover, and (b) is itself always
/// draggable, so the whole bar moves the window  not just the three
/// small buttons.
final class TitlebarDragView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private let hoverHeight: CGFloat = 10

    private var trackingArea: NSTrackingArea?
    private var isHovering: Bool = false {
        didSet {
            if isHovering != oldValue {
                needsDisplay = true
            }
        }
    }

    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        // Only track hover in the top 10 pixels
        let area = NSTrackingArea(
            rect: NSRect(x: 0, y: bounds.height - hoverHeight, width: bounds.width, height: hoverHeight),
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Only draw black background when hovering
        if isHovering {
            NSColor.black.setFill()
            dirtyRect.fill()
        }
    }
}
