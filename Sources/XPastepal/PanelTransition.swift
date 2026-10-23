import AppKit
import QuartzCore

@MainActor
final class PanelTransition {
    private struct Destination {
        let frame: NSRect
        let position: PanelPosition
        let screenFrame: NSRect

        @MainActor
        func hiddenTransform(for panel: QuickPanel) -> CATransform3D {
            let frame = panel.frame
            let offset: NSPoint
            switch position {
            case .bottom: offset = NSPoint(x: 0, y: screenFrame.minY - frame.maxY)
            case .top: offset = NSPoint(x: 0, y: screenFrame.maxY - frame.minY)
            case .left: offset = NSPoint(x: screenFrame.minX - frame.maxX, y: 0)
            case .right: offset = NSPoint(x: screenFrame.maxX - frame.minX, y: 0)
            }
            let y = panel.contentView?.isFlipped == true ? -offset.y : offset.y
            return CATransform3DMakeTranslation(offset.x, y, 0)
        }
    }

    private(set) var isPresented = false
    private(set) var isAnimating = false
    private var destination: Destination?
    private var currentEdge: Destination?
    private var generation = 0
    private var shadowBeforeAnimation: Bool?
    private let animationKey = "XPastepal.panelSlide"

    func show(panel: QuickPanel, frame: NSRect, position: PanelPosition, screen: NSScreen) {
        let next = Destination(frame: frame, position: position, screenFrame: screen.frame)
        let canContinue = panel.isVisible && currentEdge?.position == position &&
            currentEdge?.screenFrame == screen.frame && panel.frame == frame
        cancelAnimation(panel: panel)
        destination = next
        currentEdge = next
        isPresented = true
        panel.animationBehavior = .none
        panel.contentView?.wantsLayer = true
        if !canContinue {
            panel.setFrame(frame, display: false)
            setTransform(next.hiddenTransform(for: panel), on: panel)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        animate(panel: panel, to: CATransform3DIdentity)
    }

    func hide(panel: QuickPanel, animated: Bool = true, completion: (() -> Void)? = nil) {
        isPresented = false
        cancelAnimation(panel: panel)
        let finish = { [weak self, weak panel] in
            guard let self, !self.isPresented else { return }
            panel?.orderOut(nil)
            completion?()
        }
        guard animated, panel.isVisible, let currentEdge else { finish(); return }
        animate(panel: panel, to: currentEdge.hiddenTransform(for: panel), completion: finish)
    }

    func reposition(panel: QuickPanel, frame: NSRect, position: PanelPosition, screen: NSScreen) {
        let old = currentEdge
        let next = Destination(frame: frame, position: position, screenFrame: screen.frame)
        destination = next
        cancelAnimation(panel: panel)
        guard isPresented else { panel.orderOut(nil); panel.setFrame(frame, display: false); return }
        guard let old, old.position != position || old.screenFrame != screen.frame || panel.frame != frame else {
            currentEdge = next
            animate(panel: panel, to: CATransform3DIdentity)
            return
        }
        animate(panel: panel, to: old.hiddenTransform(for: panel)) { [weak self, weak panel] in
            guard let self, let panel, self.isPresented else { return }
            self.currentEdge = next
            panel.setFrame(frame, display: false)
            self.setTransform(next.hiddenTransform(for: panel), on: panel)
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.displayIfNeeded()
            self.animate(panel: panel, to: CATransform3DIdentity)
        }
    }

    func finish(panel: QuickPanel) {
        cancelAnimation(panel: panel)
        if isPresented, let destination {
            currentEdge = destination
            panel.setFrame(destination.frame, display: true)
            setTransform(CATransform3DIdentity, on: panel)
        } else { panel.orderOut(nil) }
    }

    private func cancelAnimation(panel: QuickPanel) {
        generation += 1
        if let layer = panel.contentView?.layer, layer.animation(forKey: animationKey) != nil {
            // Reverse from the visible position, rather than the model-layer endpoint.
            let visible = layer.presentation()?.transform ?? layer.transform
            layer.removeAnimation(forKey: animationKey)
            setTransform(visible, on: panel)
        }
        isAnimating = false
        restoreShadow(on: panel)
    }

    private func animate(panel: QuickPanel, to target: CATransform3D, completion: (() -> Void)? = nil) {
        guard let layer = panel.contentView?.layer,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !CATransform3DEqualToTransform(layer.transform, target) else {
            setTransform(target, on: panel)
            completion?()
            return
        }
        let request = generation
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = NSValue(caTransform3D: layer.transform)
        animation.toValue = NSValue(caTransform3D: target)
        animation.duration = 0.18
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.delegate = AnimationCompletion { [weak self, weak panel] in
            guard let self, let panel, self.generation == request else { return }
            self.isAnimating = false
            self.restoreShadow(on: panel)
            completion?()
        }
        shadowBeforeAnimation = panel.hasShadow
        panel.hasShadow = false
        isAnimating = true
        // Keep the window fixed. The compositor moves cached layers without per-frame
        // window moves, SwiftUI relayout, or a timer competing with keyboard input.
        setTransform(target, on: panel)
        layer.add(animation, forKey: animationKey)
    }

    private func setTransform(_ transform: CATransform3D, on panel: QuickPanel) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.contentView?.layer?.transform = transform
        CATransaction.commit()
    }

    private func restoreShadow(on panel: QuickPanel) {
        if let shadowBeforeAnimation {
            panel.hasShadow = shadowBeforeAnimation
            self.shadowBeforeAnimation = nil
        }
    }

    private final class AnimationCompletion: NSObject, CAAnimationDelegate {
        let onComplete: @MainActor () -> Void
        init(onComplete: @escaping @MainActor () -> Void) { self.onComplete = onComplete }
        func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            guard finished else { return }
            MainActor.assumeIsolated { onComplete() }
        }
    }
}
