import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

private struct VisualStyleKey: EnvironmentKey {
    static let defaultValue: SlateVisualStyle = .liquidGlass
}
private struct StaticPreviewKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var staticSlatePreview: Bool {
        get { self[StaticPreviewKey.self] }
        set { self[StaticPreviewKey.self] = newValue }
    }
    var slateVisualStyle: SlateVisualStyle {
        get { self[VisualStyleKey.self] }
        set { self[VisualStyleKey.self] = newValue }
    }
}
extension Color {
    static var slateSurface: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    static var slateCanvas: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

struct GlassPanel: ViewModifier {
    @Environment(\.slateVisualStyle) private var style
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 24
    var interactive = false
    var tint: Color? = nil
    @ViewBuilder func body(content: Content) -> some View {
        let shape = radius >= 1000 ? AnyShape(Capsule(style: .circular)) : AnyShape(RoundedRectangle(cornerRadius: radius))
        if style == .liquidGlass {
            content.modifier(NativeGlassSurface(shape: shape, tint: tint, interactive: interactive))
        } else {
            content
                .background {
                    // A matte surface needs no live backdrop filter on every scrolling card.
                    // Shadows belong to the surface, not to every glyph/control inside it.
                    shape.fill(Color.slateSurface)
                        .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.035), radius: 3, y: 2)
                        .shadow(color: .black.opacity(scheme == .dark ? 0.18 : 0.06), radius: 14, y: 7)
                }
        }
    }
}
extension View {
    func glassPanel(radius: CGFloat = 24, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassPanel(radius: radius, interactive: interactive, tint: tint))
    }
    func staggeredEntrance(_ index: Int) -> some View { modifier(StaggeredEntrance(index: index)) }
}

struct SlateActionStyle: ButtonStyle {
    var prominent = false
    var compact = false
    var iconOnly = false
    var roundedRectangle = false
    @Environment(\.slateVisualStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        let color: Color = configuration.role == .destructive ? .red : .accentColor
        let shape: AnyShape = style == .liquidGlass && !roundedRectangle
            ? (iconOnly ? AnyShape(Circle()) : AnyShape(Capsule(style: .circular)))
            : AnyShape(RoundedRectangle(cornerRadius: 16))
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, compact ? 10 : 15).padding(.vertical, compact ? 10 : 12)
            .frame(minWidth: 44, minHeight: 44)
            .frame(width: iconOnly && style == .liquidGlass ? 44 : nil,
                   height: iconOnly && style == .liquidGlass ? 44 : nil)
            .foregroundStyle(prominent ? Color.white : color)
            .background { if prominent { shape.fill(color.gradient).allowsHitTesting(false) } }
            .modifier(ActionSurface(shape: shape, style: style, pressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed && !reduced ? 0.965 : 1)
            .opacity(enabled ? 1 : 0.45)
            // The entire unscaled layout box remains tappable, including the padded edges.
            .contentShape(.interaction, Rectangle())
            .animation(reduced ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { SlateHaptics.light() } }
    }
}

struct SlateToggleStyle: ToggleStyle {
    @Environment(\.slateVisualStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduced
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if style == .liquidGlass {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
        } else {
            HStack(spacing: 16) {
                configuration.label
                Spacer(minLength: 12)
                Capsule().fill(configuration.isOn ? Color.blue : Color.secondary.opacity(0.23))
                    .overlay {
                        Circle().fill(.white).frame(width: 27, height: 27)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .offset(x: configuration.isOn ? 10 : -10)
                    }.frame(width: 51, height: 31)
            }.frame(minHeight: 44).contentShape(Rectangle())
                .onTapGesture { configuration.isOn.toggle() }
                .animation(reduced ? nil : .spring(duration: 0.22, bounce: 0.04), value: configuration.isOn)
                .accessibilityRepresentation {
                    Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
                }
        }
    }
}
private struct ActionSurface: ViewModifier {
    let shape: AnyShape
    let style: SlateVisualStyle
    let pressed: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if style == .liquidGlass { content.modifier(NativeGlassSurface(shape: shape, interactive: true)) }
        else {
            content.background {
                shape.fill(Color.slateSurface)
                    .shadow(color: .black.opacity(0.035), radius: 2, y: 1)
                    .shadow(color: .black.opacity(0.05), radius: 7, y: 4)
            }
                .overlay { if pressed { shape.fill(.primary.opacity(0.06)).allowsHitTesting(false) } }
        }
    }
}

/// Keep glyphs opaque. Only the native glass background and its legibility backing change.
private struct NativeGlassSurface: ViewModifier {
    let shape: AnyShape
    var tint: Color? = nil
    var interactive = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduced
    @ViewBuilder func body(content: Content) -> some View {
        if reduced {
            content.background { shape.fill(Color.slateSurface).allowsHitTesting(false) }
        } else {
            // Regular glass diffuses background text and high-contrast slate stripes.
            // Clear glass made overlapping history surfaces read like transparent lenses.
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
                .background {
                    shape.fill(Color.slateSurface.opacity(contrast == .increased ? 0.24 : 0.10))
                        .allowsHitTesting(false)
                }
        }
    }
}

/// The system owns the popover host; classic mode supplies the standard frosted material.
/// A native context menu cannot select an older iOS material at runtime.
struct SlatePopoverSurface: ViewModifier {
    @Environment(\.slateVisualStyle) private var style
    @ViewBuilder func body(content: Content) -> some View {
        if style == .classic { content.presentationBackground(.regularMaterial).presentationCornerRadius(36) }
        else { content }
    }
}
struct SlateFieldPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduced
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.primary.opacity(configuration.isPressed ? 0.07 : 0), in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed && !reduced ? 0.985 : 1)
            .contentShape(.interaction, Rectangle())
            .animation(reduced ? nil : .snappy(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, down in if down { SlateHaptics.selection() } }
    }
}
struct StaggeredEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var visible = false
    @Environment(\.staticSlatePreview) private var preview
    func body(content: Content) -> some View {
        content.opacity(visible || preview ? 1 : 0).offset(y: visible || reduced || preview ? 0 : 10)
            .animation(reduced ? nil : .smooth(duration: 0.26).delay(Double(index) * 0.045), value: visible)
            .onAppear { visible = true }
    }
}

struct SlateBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.slateVisualStyle) private var style
    var body: some View {
        LinearGradient(colors: scheme == .dark
                       ? [Color(red: 0.12, green: 0.23, blue: 0.36), Color(red: 0.035, green: 0.07, blue: 0.12)]
                       : [Color(red: 0.70, green: 0.85, blue: 0.98), .white],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { if style == .classic { Color.slateCanvas.opacity(scheme == .dark ? 0.4 : 0.15) } }
            .ignoresSafeArea().accessibilityHidden(true)
    }
}

/// Push-out line breaking balances short titles without a single-word final line.
struct BalancedTitle: View {
    let text: String
    var fontSize: CGFloat = 17
    @State private var width: CGFloat = 0
    var body: some View {
        Text(verbatim: balanced)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .lineLimit(2).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
    private var balanced: String {
        let words = text.split(separator: " ")
        guard width > 0, words.count >= 3 else { return text }
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        #else
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        #endif
        func measure(_ value: String) -> CGFloat { (value as NSString).size(withAttributes: [.font: font]).width }
        guard measure(text) > width else { return text }
        let choices = (1..<words.count).compactMap { index -> (String, CGFloat)? in
            let first = words[..<index].joined(separator: " ")
            let second = words[index...].joined(separator: " ")
            guard words.count - index > 1, measure(first) <= width, measure(second) <= width else { return nil }
            return (first + "\n" + second, abs(measure(first) - measure(second)))
        }
        return choices.min(by: { $0.1 < $1.1 })?.0 ?? text
    }
}
