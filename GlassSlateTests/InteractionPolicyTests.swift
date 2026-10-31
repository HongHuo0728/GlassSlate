import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import SlateCore
#else
@testable import GlassSlate
#endif

struct InteractionPolicyTests {
    @Test func liveActivityPayloadLimitsUnicodeAndEscapedControlText() throws {
        let name = ActivityPayloadText.limited(String(repeating: "影片🎬e\u{301}", count: 1000), bytes: 240)
        #expect(name.utf8.count <= 240)
        #expect(!name.contains("�"))
        let controls = ActivityPayloadText.limited(String(repeating: "\u{01}", count: 2000), bytes: 240)
        let fields = ["production": controls, "scene": String(controls.prefix(40)), "shot": String(controls.prefix(40)),
                      "take": String(controls.prefix(40)), "message": String(controls.prefix(160))]
        #expect(try JSONEncoder().encode(fields).count < 3500)
    }
    @Test @MainActor func glassPreferenceOnlyAppliesOnNextLaunch() throws {
        let suite = "GlassSlate.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = SettingsStore(defaults: defaults)
        #expect(first.liveActivitiesEnabled)
        first.liveActivitiesEnabled = false
        #expect(!SettingsStore(defaults: defaults).liveActivitiesEnabled)
        #expect(first.liquidGlassEnabled)
        #expect(first.activeVisualStyle == .liquidGlass)
        first.liquidGlassEnabled = false
        #expect(first.restartRequired)
        #expect(first.activeVisualStyle == .liquidGlass)
        let restarted = SettingsStore(defaults: defaults)
        #expect(restarted.activeVisualStyle == .classic)
        #expect(!restarted.restartRequired)
        restarted.liquidGlassEnabled = true
        #expect(restarted.activeVisualStyle == .classic)
        #expect(restarted.restartRequired)
        #expect(SettingsStore(defaults: defaults).activeVisualStyle == .liquidGlass)
    }

    @Test func landscapeAllocatesClapperAndAllThreeDataRows() {
        for (width, height) in [(750.0, 369.0), (756, 335), (724, 300), (724, 275), (780, 360), (896, 390)] {
            let layout = SlateStageGeometry(width: width, height: height)
            #expect(layout.isLandscape)
            #expect(abs(layout.clapperHeight + layout.boardHeight + 24 - height) < 0.01)
            #expect(abs(layout.railWidth + layout.stageWidth + 36 - width) < 0.01)
            #expect(layout.boardHeight > 160)
            #expect(layout.clapperHeight < height * 0.4)
        }
    }

    @Test func drawerRejectsVerticalScrollAndRightwardDeletionRecovery() {
        #expect(DrawerGesturePolicy.shouldBegin(velocityX: -300, velocityY: 25))
        #expect(!DrawerGesturePolicy.shouldBegin(velocityX: 300, velocityY: 25))
        #expect(!DrawerGesturePolicy.shouldBegin(velocityX: -50, velocityY: -300))
        #expect(!DrawerGesturePolicy.shouldBegin(velocityX: -20, velocityY: 0))
        #expect(DrawerGesturePolicy.shouldClose(translation: -100, velocity: -100, width: 370))
        #expect(DrawerGesturePolicy.shouldClose(translation: -25, velocity: -700, width: 370))
        #expect(!DrawerGesturePolicy.shouldClose(translation: -20, velocity: -50, width: 370))
    }

    @Test func drawerNavigationOnlyStartsAtPhysicalScreenEdges() {
        #expect(DrawerGesturePolicy.startsAtEdge(x: 5, width: 390, opening: true))
        #expect(DrawerGesturePolicy.startsAtEdge(x: 385, width: 390, opening: false))
        // Includes the partially revealed delete button and a resumed swipe in the history row.
        for x: CGFloat in [40, 180, 280, 330, 350] {
            #expect(!DrawerGesturePolicy.startsAtEdge(x: x, width: 390, opening: false))
        }
        #expect(!DrawerGesturePolicy.startsAtEdge(x: -1, width: 390, opening: true))
        #expect(!DrawerGesturePolicy.startsAtEdge(x: 391, width: 390, opening: false))
        #expect(DrawerGesturePolicy.shouldBeginOpening(velocityX: 300, velocityY: 10))
        #expect(!DrawerGesturePolicy.shouldBeginOpening(velocityX: -300, velocityY: 10))
        #expect(!DrawerGesturePolicy.shouldBeginOpening(velocityX: 50, velocityY: 300))
        #expect(DrawerGesturePolicy.shouldOpen(translation: 100, velocity: 100, width: 350))
        #expect(!DrawerGesturePolicy.shouldOpen(translation: 10, velocity: 100, width: 350))
    }

    @Test func closedDrawerAndShadowClearLandscapeSafeAreas() {
        for (width, safeArea): (CGFloat, CGFloat) in [(351, 0), (380, 47), (380, 59), (380, 0)] {
            let drawer = DrawerGeometry(panelWidth: width, leadingSafeArea: safeArea)
            let physicalRightEdge = safeArea + drawer.leadingInset + width + drawer.offset(isOpen: false, translation: 0)
            #expect(physicalRightEdge + drawer.shadowClearance <= 0)
            #expect(drawer.offset(isOpen: true, translation: 0) == 0)
            #expect(drawer.offset(isOpen: false, translation: drawer.travel) == 0)
            #expect(drawer.offset(isOpen: true, translation: -drawer.travel) == drawer.closedOffset)
            // Opening starts at the physical edge, rather than requiring a drag through the shadow clearance.
            let firstOpeningEdge = safeArea + drawer.leadingInset + width + drawer.offset(isOpen: false, translation: 1)
            #expect(firstOpeningEdge == 1)
            #expect(drawer.offset(isOpen: true, translation: -drawer.travel / 2) == -drawer.travel / 2)
            #expect(drawer.offset(isOpen: false, translation: -100) == drawer.closedOffset)
            #expect(drawer.offset(isOpen: true, translation: 100) == 0)
        }
    }
}
