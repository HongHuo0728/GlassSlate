import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main struct GlassSlateWidgetBundle: WidgetBundle {
    var body: some Widget { GlassSlateLiveActivity() }
}
struct GlassSlateLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SlateActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("GlassSlate", systemImage: "film").font(.headline).fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    Text(verbatim: context.state.production).font(.subheadline).lineLimit(1)
                }
                HStack(spacing: 16) {
                    value("Scene", context.state.scene)
                    value("Shot", context.state.shot)
                    value("Take", context.state.take)
                    clapButton
                }
                if let message = context.state.message { Text(verbatim: message).font(.caption).foregroundStyle(.red).lineLimit(2) }
            }.padding(16)
                .modifier(LockScreenGlassSurface())
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("GlassSlate", systemImage: "film").font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { value("Take", context.state.take) }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: context.state.production).font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack { value("Scene", context.state.scene); value("Shot", context.state.shot); clapButton }
                        if let message = context.state.message { Text(verbatim: message).font(.caption2).foregroundStyle(.red).lineLimit(2) }
                    }
                }
            } compactLeading: {
                Image(systemName: "film")
            } compactTrailing: {
                Text(verbatim: context.state.take.isEmpty ? "—" : context.state.take).font(.caption.weight(.semibold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: 60)
            } minimal: { Image(systemName: "film") }
                .keylineTint(.blue)
        }
    }
    private var clapButton: some View {
        Button(intent: ClapSlateIntent()) {
            Image(systemName: "movieclapper.fill").font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44).contentShape(Circle())
        }
            .buttonStyle(.plain).background(.blue.gradient, in: Circle()).foregroundStyle(.white)
            .frame(width: 44, height: 44).contentShape(Circle())
            .fixedSize().accessibilityLabel(Text("Clap slate"))
            .accessibilityHint(Text("Saves a snapshot and plays the clap sound."))
    }
    private func value(_ label: LocalizedStringKey, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.primary.opacity(0.9))
            Text(verbatim: text.isEmpty ? "—" : text).font(.title3.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Lock Screen host otherwise supplies an opaque dark/light activity background.
/// Request native regular glass without a second opaque host surface. WidgetKit owns
/// final compositing; the backing remains readable if a host omits the glass effect.
private struct LockScreenGlassSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reducedTransparency
    @Environment(\.isLuminanceReduced) private var reducedLuminance

    func body(content: Content) -> some View {
        let shape = ContainerRelativeShape()
        let backing: Color = scheme == .dark ? .black : .white
        return Group {
            if reducedTransparency || reducedLuminance {
                content.background(backing, in: shape)
            } else {
                content.background {
                    ZStack {
                        // Native glass already supplies diffusion and contrast. Keep only
                        // a light backing so the Lock Screen wallpaper can show through.
                        shape.fill(backing.opacity(contrast == .increased ? 0.85 : 0.15))
                        // Keep the content outside the effect's subtree so text and the
                        // intent button remain present even if a widget host omits glass.
                        Color.clear.glassEffect(.regular, in: shape)
                    }
                }
            }
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.primary)
    }
}
