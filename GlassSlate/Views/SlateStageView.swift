import SwiftUI

/// The same responsive stage is used by the app and by native layout previews.
struct SlateStageView: View {
    let values: SlateValues
    let recordCount: Int
    let locked: Bool
    let busy: Bool
    let clapTrigger: Int
    var persistentHistory = false
    let history: () -> Void
    let settings: () -> Void
    let toggleLock: () -> Void
    let newSlate: () -> Void
    let edit: (SlateField) -> Void
    let clap: () -> Void
    var body: some View {
        GeometryReader { geometry in
            let metrics = SlateStageGeometry(width: geometry.size.width, height: geometry.size.height)
            if persistentHistory { tablet(width: geometry.size.width, height: geometry.size.height) }
            else if metrics.isLandscape { landscape(metrics) }
            else { portrait(width: geometry.size.width) }
        }
    }
    private func landscape(_ metrics: SlateStageGeometry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                tools
                Spacer(minLength: 0)
                Text(recordCount, format: .number).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityLabel(Text("\(recordCount) slates"))
            }.frame(width: metrics.railWidth).staggeredEntrance(0)
            VStack(spacing: 0) {
                ClapperView(clapTrigger: clapTrigger, availableWidth: metrics.stageWidth,
                            stickHeight: metrics.stickHeight, openAngle: metrics.openAngle, action: clap)
                    .staggeredEntrance(1)
                SlateBoardSurface(values: values, locked: locked, busy: busy,
                                  landscapeHeight: metrics.boardHeight, edit: edit)
                    .frame(height: metrics.boardHeight).staggeredEntrance(2)
            }.frame(width: metrics.stageWidth)
        }.padding(12)
    }
    private func portrait(width: CGFloat) -> some View {
        VStack(spacing: 4) {
            HStack {
                tool("sidebar.left", label: "History and settings", action: history)
                Spacer()
                VStack(spacing: 2) {
                    Text("GlassSlate").font(.headline).fontDesign(.rounded)
                    Text("READY FOR ACTION").font(.caption2).tracking(1.5).foregroundStyle(.secondary)
                }
                Spacer()
                tool(locked ? "lock.fill" : "lock.open", label: locked ? "Unlock fields" : "Lock fields and keep screen awake", action: toggleLock)
            }.padding(.horizontal, 16).staggeredEntrance(0)
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        ClapperView(clapTrigger: clapTrigger, availableWidth: min(680, width - 32), action: clap)
                            .staggeredEntrance(1)
                        SlateBoardSurface(values: values, locked: locked, busy: busy, edit: edit).staggeredEntrance(2)
                    }
                    Label(locked ? "Fields locked · screen stays awake" : "Tap the striped clapper to mark a take",
                          systemImage: locked ? "lock.fill" : "hand.tap")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).staggeredEntrance(3)
                    HStack {
                        Label { Text("\(recordCount) slates").monospacedDigit() } icon: { Image(systemName: "rectangle.stack") }
                        Spacer()
                        tool("slider.horizontal.3", label: "Settings", action: settings)
                        tool("plus", label: "New slate", action: newSlate).disabled(locked || busy)
                    }.font(.footnote).staggeredEntrance(4)
                }.frame(maxWidth: 680).padding(.horizontal, 16).padding(.bottom, 16).frame(maxWidth: .infinity)
            }.scrollBounceBehavior(.basedOnSize)
        }.padding(.top, 4)
    }
    private var tools: some View {
        Group {
            tool("sidebar.left", label: "History and settings", action: history)
            tool("slider.horizontal.3", label: "Settings", action: settings)
            tool(locked ? "lock.fill" : "lock.open", label: locked ? "Unlock fields" : "Lock fields and keep screen awake", action: toggleLock)
            tool("plus", label: "New slate", action: newSlate).disabled(locked || busy)
        }
    }
    private func tablet(width: CGFloat, height: CGFloat) -> some View {
        let boardWidth = min(1000, max(1, width - 32))
        let stickHeight: CGFloat = 36
        let angle = min(10.0, max(4.5, Double(height / boardWidth) * 9))
        let clapperHeight = boardWidth * sin(angle * .pi / 180) + stickHeight * 2 + 13
        let boardHeight = max(270, min(650, height - clapperHeight - 100))
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("GlassSlate").font(.title2.bold()).fontDesign(.rounded)
                Spacer(minLength: 8)
                tool("slider.horizontal.3", label: "Settings", action: settings)
                tool(locked ? "lock.fill" : "lock.open", label: locked ? "Unlock fields" : "Lock fields and keep screen awake", action: toggleLock)
                tool("plus", label: "New slate", action: newSlate).disabled(locked || busy)
            }.padding(.horizontal, 16)
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        ClapperView(clapTrigger: clapTrigger, availableWidth: boardWidth,
                                    stickHeight: stickHeight, openAngle: angle, action: clap)
                        SlateBoardSurface(values: values, locked: locked, busy: busy,
                                          landscapeHeight: boardHeight, edit: edit).frame(height: boardHeight)
                    }.frame(width: boardWidth)
                    Label(locked ? "Fields locked · screen stays awake" : "Tap the striped clapper to mark a take",
                          systemImage: locked ? "lock.fill" : "hand.tap")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.horizontal, 16).padding(.bottom, 16).frame(maxWidth: .infinity)
            }.scrollBounceBehavior(.basedOnSize)
        }.padding(.top, 8)
    }
    private func tool(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
            Button(action: action) { Image(systemName: icon).contentTransition(.symbolEffect(.replace)).frame(width: 24, height: 24) }
            .buttonStyle(SlateActionStyle(compact: true, iconOnly: true)).accessibilityLabel(Text(label))
    }
}

struct SlateBoardSurface: View {
    let values: SlateValues
    let locked: Bool
    let busy: Bool
    var landscapeHeight: CGFloat? = nil
    let edit: (SlateField) -> Void
    @Environment(\.slateVisualStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.dynamicTypeSize) private var typeSize
    private var classic: Bool { style == .classic }
    private var innerHeight: CGFloat? { landscapeHeight.map { max(1, $0 - 16 - (classic ? 16 : 2)) } }
    var body: some View {
        VStack(spacing: classic ? 8 : 0) {
            cell(.production, prominent: true, rowHeight: innerHeight.map { $0 * 0.25 })
                .modifier(FieldInset(classic: classic))
            if !classic { Divider() }
            HStack(spacing: classic ? 8 : 0) {
                ForEach([SlateField.roll, .scene, .shot, .take]) { field in
                    cell(field, prominent: true, rowHeight: innerHeight.map { $0 * 0.40 })
                        .modifier(FieldInset(classic: classic))
                }
            }
            if !classic { Divider() }
            if let innerHeight {
                HStack(spacing: classic ? 8 : 0) {
                    ForEach([SlateField.director, .cameraman, .date]) { field in
                        cell(field, rowHeight: innerHeight * 0.35).modifier(FieldInset(classic: classic))
                    }
                }
            } else {
                if typeSize.isAccessibilitySize {
                    cell(.director).modifier(FieldInset(classic: classic))
                    cell(.cameraman).modifier(FieldInset(classic: classic))
                } else {
                    HStack(spacing: classic ? 8 : 0) {
                        cell(.director).modifier(FieldInset(classic: classic))
                        cell(.cameraman).modifier(FieldInset(classic: classic))
                    }
                }
                if !classic { Divider() }
                cell(.date).modifier(FieldInset(classic: classic))
            }
        }
        .padding(8)
        // Inner 16 + inset 8 = outer 24.
        .glassPanel(radius: 24, tint: locked && !classic ? .cyan.opacity(0.10) : nil)
    }
    private func cell(_ field: SlateField, prominent: Bool = false, rowHeight: CGFloat? = nil) -> some View {
        let value = values[field]
        return Button { edit(field) } label: {
            VStack(alignment: .leading, spacing: rowHeight == nil ? 6 : 2) {
                Text(LocalizedStringKey(field.rawValue))
                    .font(rowHeight == nil ? .caption.weight(.semibold) : .system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                Group {
                    if value.isEmpty { Text("Tap to edit").foregroundStyle(.tertiary) }
                    else if field == .production && rowHeight == nil { BalancedTitle(text: value, fontSize: 32).foregroundStyle(.primary) }
                    else { Text(verbatim: value).foregroundStyle(.primary) }
                }
                .font(valueFont(prominent: prominent, height: rowHeight))
                .fontWeight(prominent ? .semibold : .medium).fontDesign(classic ? .default : .rounded)
                .monospacedDigit()
                .lineLimit(rowHeight == nil && field == .production ? 2 : 1).minimumScaleFactor(0.55)
                .contentTransition(.numericText())
                .animation(reduced ? nil : .snappy(duration: 0.2), value: value)
            }
            .frame(maxWidth: .infinity, maxHeight: rowHeight == nil ? nil : .infinity, alignment: .leading)
            .padding(.horizontal, rowHeight == nil ? 12 : 10).padding(.vertical, rowHeight == nil ? 13 : 4)
            .frame(maxWidth: .infinity, minHeight: rowHeight == nil ? 64 : nil, maxHeight: rowHeight == nil ? nil : .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(SlateFieldPressStyle()).disabled(locked || busy)
        .frame(height: rowHeight)
        .accessibilityLabel(Text(LocalizedStringKey(field.rawValue)))
        .accessibilityValue(Text(verbatim: value.isEmpty ? String(localized: "Empty") : value))
        .accessibilityHint(Text(locked ? "Unlock to edit" : "Double tap to edit"))
    }
    private func valueFont(prominent: Bool, height: CGFloat?) -> Font {
        if let height { return .system(size: min(prominent ? 32 : 23, max(15, height * (prominent ? 0.43 : 0.34)))) }
        return prominent ? .largeTitle : .title3
    }
}
private struct FieldInset: ViewModifier {
    let classic: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if classic { content.background(Color.slateCanvas.opacity(0.65), in: RoundedRectangle(cornerRadius: 16)) }
        else { content }
    }
}
