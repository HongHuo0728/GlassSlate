#if DEBUG
import SwiftUI

private struct StagePreview: View {
    let style: SlateVisualStyle
    let landscape: Bool
    @State private var closure: CGFloat = 0
    private var values: SlateValues {
        var value = SlateValues()
        value.production = "The Last Blue Hour"
        value.roll = "A001"; value.scene = "12A"; value.shot = "03"; value.take = "009"
        value.director = "Maya Chen"; value.cameraman = "Alex Morgan"
        return value
    }
    var body: some View {
        ZStack {
            SlateBackground()
            SlateStageView(values: values, recordCount: 12, locked: false, busy: false, closure: closure,
                           history: {}, settings: {}, toggleLock: {}, newSlate: {}, edit: { _ in }, clap: {
                withAnimation(.easeIn(duration: 0.08)) { closure = 1 }
                Task { try? await Task.sleep(for: .milliseconds(120)); withAnimation(.spring(duration: 0.16)) { closure = 0 } }
            })
            .padding(.horizontal, landscape ? 47 : 0)
            .padding(.top, landscape ? 0 : 47).padding(.bottom, landscape ? 21 : 34)
        }.environment(\.slateVisualStyle, style).preferredColorScheme(.light)
    }
}
#Preview("12 Pro · Portrait · Glass", traits: .fixedLayout(width: 390, height: 844)) {
    StagePreview(style: .liquidGlass, landscape: false)
}
#Preview("12 Pro · Landscape · Glass", traits: .fixedLayout(width: 844, height: 390)) {
    StagePreview(style: .liquidGlass, landscape: true)
}
#Preview("12 Pro · Landscape · Classic", traits: .fixedLayout(width: 844, height: 390)) {
    StagePreview(style: .classic, landscape: true)
}
#endif
