import SwiftUI
import UIKit

/// Only physical screen-edge gestures navigate the drawer. History-row swipes never enter this recognizer.
struct DrawerEdgeGestures: UIViewRepresentable {
    let isOpen: Bool
    let allowed: Bool
    let opening: (CGFloat) -> Void
    let opened: (CGFloat, CGFloat) -> Void
    let closing: (CGFloat) -> Void
    let closed: (CGFloat, CGFloat) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> Anchor {
        let view = Anchor(); view.isUserInteractionEnabled = false
        view.windowChanged = { [weak coordinator = context.coordinator, weak view] in
            if let view { coordinator?.attach(view) }
        }
        return view
    }
    func updateUIView(_ uiView: Anchor, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attach(uiView)
        context.coordinator.updateEnabled()
    }
    static func dismantleUIView(_ uiView: Anchor, coordinator: Coordinator) { coordinator.detach() }
    final class Anchor: UIView {
        var windowChanged: (() -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); windowChanged?() }
    }
    @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: DrawerEdgeGestures
        private weak var anchor: UIView?
        private weak var attachedWindow: UIWindow?
        private var left: UIScreenEdgePanGestureRecognizer?
        private var right: UIScreenEdgePanGestureRecognizer?
        init(_ parent: DrawerEdgeGestures) { self.parent = parent }
        func attach(_ view: UIView) {
            anchor = view
            guard attachedWindow !== view.window else { return }
            detach()
            guard let window = view.window else { return }
            attachedWindow = window
            left = edge(.left, window: window); right = edge(.right, window: window)
            updateEnabled()
        }
        private func edge(_ edges: UIRectEdge, window: UIWindow) -> UIScreenEdgePanGestureRecognizer {
            let pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(panned))
            pan.edges = edges; pan.maximumNumberOfTouches = 1
            pan.delegate = self
            window.addGestureRecognizer(pan)
            return pan
        }
        func updateEnabled() {
            let openEnabled = parent.allowed && !parent.isOpen
            let closeEnabled = parent.allowed && parent.isOpen
            if left?.isEnabled != openEnabled { left?.isEnabled = openEnabled }
            if right?.isEnabled != closeEnabled { right?.isEnabled = closeEnabled }
        }
        func detach() {
            if let left { attachedWindow?.removeGestureRecognizer(left) }
            if let right { attachedWindow?.removeGestureRecognizer(right) }
            left = nil; right = nil; attachedWindow = nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.allowed, let window = attachedWindow,
                  let pan = gestureRecognizer as? UIScreenEdgePanGestureRecognizer else { return false }
            let x = touch.location(in: window).x
            guard DrawerGesturePolicy.startsAtEdge(x: x, width: window.bounds.width, opening: pan.edges == .left) else { return false }
            var responder: UIResponder? = anchor
            while let current = responder {
                if let controller = current as? UIViewController {
                    if controller.presentedViewController != nil { return false }
                    break
                }
                responder = current.next
            }
            return true
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIScreenEdgePanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: attachedWindow)
            return pan.edges == .left
                ? DrawerGesturePolicy.shouldBeginOpening(velocityX: velocity.x, velocityY: velocity.y)
                : DrawerGesturePolicy.shouldBegin(velocityX: velocity.x, velocityY: velocity.y)
        }
        @objc private func panned(_ pan: UIScreenEdgePanGestureRecognizer) {
            let translation = pan.translation(in: attachedWindow).x
            let velocity = pan.velocity(in: attachedWindow).x
            if pan.edges == .left {
                switch pan.state {
                case .began, .changed: parent.opening(max(0, translation))
                case .ended: parent.opened(translation, velocity)
                case .cancelled, .failed: parent.opened(0, 0)
                default: break
                }
            } else {
                switch pan.state {
                case .began, .changed: parent.closing(min(0, translation))
                case .ended: parent.closed(translation, velocity)
                case .cancelled, .failed: parent.closed(0, 0)
                default: break
                }
            }
        }
    }
}
