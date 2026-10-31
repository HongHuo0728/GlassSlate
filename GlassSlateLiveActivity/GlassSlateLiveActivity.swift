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
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(verbatim: text.isEmpty ? "—" : text).font(.title3.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
