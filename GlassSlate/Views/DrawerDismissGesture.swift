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
        override func layoutSubviews() { super.layoutSubviews(); windowChanged?() }
    }
    @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: DrawerEdgeGestures
        private weak var anchor: UIView?
        private weak var attachedWindow: UIWindow?
        private var pan: UIPanGestureRecognizer?
        private var openingGesture = false
        private var windowSize: CGSize = .zero
        init(_ parent: DrawerEdgeGestures) { self.parent = parent }
        func attach(_ view: UIView) {
            anchor = view
            guard attachedWindow !== view.window else { invalidateIfResized(); return }
            detach()
            guard let window = view.window else { return }
            attachedWindow = window
            windowSize = window.bounds.size
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
            pan.maximumNumberOfTouches = 1; pan.delegate = self
            window.addGestureRecognizer(pan)
            self.pan = pan
            updateEnabled()
        }
        private func invalidateIfResized() {
            guard let window = attachedWindow, windowSize != window.bounds.size else { return }
            windowSize = window.bounds.size
            if pan?.state == .began || pan?.state == .changed {
                pan?.isEnabled = false
                updateEnabled()
            }
        }
        func updateEnabled() {
            if pan?.isEnabled != parent.allowed { pan?.isEnabled = parent.allowed }
        }
        func detach() {
            if let pan { attachedWindow?.removeGestureRecognizer(pan) }
            pan = nil; attachedWindow = nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.allowed, let window = attachedWindow else { return false }
            openingGesture = !parent.isOpen
            let x = touch.location(in: window).x - window.bounds.minX
            guard DrawerGesturePolicy.startsAtEdge(x: x, width: window.bounds.width, opening: openingGesture),
                  !hasPresentation(window.rootViewController) else { return false }
            return true
        }
        private func hasPresentation(_ controller: UIViewController?) -> Bool {
            guard let controller else { return false }
            return controller.presentedViewController != nil || controller.children.contains { hasPresentation($0) }
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.allowed, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            // UIPan waits for movement; direction is independent of the speed of a slow drag.
            let movement = pan.translation(in: attachedWindow)
            return openingGesture
                ? DrawerGesturePolicy.shouldBeginOpening(velocityX: movement.x, velocityY: movement.y)
                : DrawerGesturePolicy.shouldBegin(velocityX: movement.x, velocityY: movement.y)
        }
        @objc private func panned(_ pan: UIPanGestureRecognizer) {
            let translation = pan.translation(in: attachedWindow).x
            let velocity = pan.velocity(in: attachedWindow).x
            if openingGesture {
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
