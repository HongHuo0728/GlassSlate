import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor enum SlateHaptics {
    #if canImport(UIKit)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let clapGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    #endif
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }
    static func prepare() {
        #if canImport(UIKit)
        guard enabled else { return }
        clapGenerator.prepare(); selectionGenerator.prepare(); lightGenerator.prepare()
        #endif
    }
    static func selection() {
        #if canImport(UIKit)
        guard enabled else { return }
        selectionGenerator.selectionChanged(); selectionGenerator.prepare()
        #endif
    }
    static func light() {
        #if canImport(UIKit)
        guard enabled else { return }
        lightGenerator.impactOccurred(intensity: 0.65); lightGenerator.prepare()
        #endif
    }
    static func clap() {
        #if canImport(UIKit)
        guard enabled else { return }
        clapGenerator.impactOccurred(intensity: 1); clapGenerator.prepare()
        #endif
    }
    static func success() {
        #if canImport(UIKit)
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.success)
        #endif
    }
    static func warning() {
        #if canImport(UIKit)
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.warning)
        #endif
    }
    static func error() {
        #if canImport(UIKit)
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.error)
        #endif
    }
}
