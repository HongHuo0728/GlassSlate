import Foundation
import Observation
import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum SlateVisualStyle: Sendable { case liquidGlass, classic }

@MainActor @Observable final class SettingsStore {
    private let defaults: UserDefaults
    /// Changing the preference takes effect on the next full launch, not on foregrounding.
    let activeVisualStyle: SlateVisualStyle
    var liquidGlassEnabled: Bool { didSet { defaults.set(liquidGlassEnabled, forKey: "liquidGlassEnabled") } }
    var restartRequired: Bool { liquidGlassEnabled != (activeVisualStyle == .liquidGlass) }
    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var autoIncrement: Bool { didSet { defaults.set(autoIncrement, forKey: "autoIncrement") } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    var liveActivitiesEnabled: Bool { didSet { defaults.set(liveActivitiesEnabled, forKey: "liveActivitiesEnabled") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let glass = defaults.object(forKey: "liquidGlassEnabled") as? Bool ?? true
        liquidGlassEnabled = glass
        activeVisualStyle = glass ? .liquidGlass : .classic
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        autoIncrement = defaults.object(forKey: "autoIncrement") as? Bool ?? true
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        liveActivitiesEnabled = defaults.object(forKey: "liveActivitiesEnabled") as? Bool ?? true
    }
}
