import AppKit
import SwiftUI

/// Borderless, non-activating floating panel that shows on every space and over full-screen apps.
final class IslandPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    // Never take focus away from Zoom or whatever you're using.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosts the SwiftUI view and lets you drag the panel around.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    private var mouseStart: NSPoint = .zero
    private var originStart: NSPoint = .zero
    private var didDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation
        NSCursor.closedHand.set()
        originStart = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if !didDrag {
            didDrag = true
            onDragStarted?()
        }
        window.setFrameOrigin(NSPoint(
            x: originStart.x + mouse.x - mouseStart.x,
            y: originStart.y + mouse.y - mouseStart.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else if didDrag {
            onDragEnded?()
        }
        NSCursor.openHand.set()
    }
}
