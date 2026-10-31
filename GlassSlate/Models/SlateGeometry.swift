import Foundation

enum HistoryLayout {
    static let sidebarWidth: CGFloat = 300
    static func usesSidebar(isPad: Bool, width: CGFloat) -> Bool { isPad && width >= 744 }
}

enum ClapMotion {
    static let closing = 0.035
    static let contact = 0.020
    static let reopening = 0.085
    static let duration = closing + contact + reopening
}

struct SlateStageGeometry {
    let width: CGFloat
    let height: CGFloat
    var isLandscape: Bool { width > height }
    var railWidth: CGFloat { 52 }
    var stageWidth: CGFloat { max(1, width - railWidth - 36) }
    var stickHeight: CGFloat { min(28, max(20, height * 0.078)) }
    var openAngle: Double { height < 310 ? 3.0 : 4.5 }
    var clapperHeight: CGFloat { stageWidth * sin(openAngle * .pi / 180) + stickHeight * 2 + 10 }
    var boardHeight: CGFloat { max(1, height - 24 - clapperHeight) }
}

struct DrawerGeometry {
    let panelWidth: CGFloat
    let leadingSafeArea: CGFloat
    let leadingInset: CGFloat = 8
    let shadowClearance: CGFloat = 48
    var travel: CGFloat { panelWidth + leadingInset + max(0, leadingSafeArea) + shadowClearance }
    var closedOffset: CGFloat { -travel }
    func offset(isOpen: Bool, translation: CGFloat) -> CGFloat {
        // Park shadows beyond the screen at rest, but start the card at the physical
        // edge as soon as an opening gesture moves, without a dead drag distance.
        let start = isOpen ? 0 : closedOffset + (translation > 0 ? shadowClearance : 0)
        return min(0, max(closedOffset, start + translation))
    }
}

enum DrawerGesturePolicy {
    static func startsAtEdge(x: CGFloat, width: CGFloat, opening: Bool) -> Bool {
        guard width > 0, x >= 0, x <= width else { return false }
        return opening ? x <= 20 : x >= width - 20
    }
    static func shouldBeginOpening(velocityX: CGFloat, velocityY: CGFloat) -> Bool {
        velocityX > 0 && abs(velocityX) > abs(velocityY) * 1.5
    }
    static func shouldOpen(translation: CGFloat, velocity: CGFloat, width: CGFloat) -> Bool {
        translation > min(85, width * 0.25) || velocity > 550
    }
    static func shouldBegin(velocityX: CGFloat, velocityY: CGFloat) -> Bool {
        velocityX < 0 && abs(velocityX) > abs(velocityY) * 1.5
    }
    static func shouldClose(translation: CGFloat, velocity: CGFloat, width: CGFloat) -> Bool {
        translation < -min(85, width * 0.25) || velocity < -550
    }
}
