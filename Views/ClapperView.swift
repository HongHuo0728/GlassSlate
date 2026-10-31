import SwiftUI

struct DiagonalStripes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stripe = max(22, rect.width / 10)
        for index in -2...14 where index.isMultiple(of: 2) {
            let x = CGFloat(index) * stripe
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x + stripe, y: 0))
            path.addLine(to: CGPoint(x: x + stripe - rect.height * 0.6, y: rect.height))
            path.addLine(to: CGPoint(x: x - rect.height * 0.6, y: rect.height))
            path.closeSubpath()
        }
        return path
    }
}
struct ClapperView: View {
    let closure: CGFloat
    let busy: Bool
    let availableWidth: CGFloat
    var stickHeight: CGFloat = 36
    var openAngle: Double = 13
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.slateVisualStyle) private var style
    private func stick(glass: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.07))
            DiagonalStripes().fill(Color(white: 0.96)).clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(height: stickHeight)
        .overlay {
            if style == .liquidGlass {
                RoundedRectangle(cornerRadius: 7).fill(LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.08)], startPoint: .top, endPoint: .bottom))
            }
        }
        .modifier(StickSurface(glass: glass))
    }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                // Keep the moving arm vector-only. The stationary arm carries native glass;
                // the compositor need not recalculate refraction during an 80 ms impact.
                stick(glass: false).rotationEffect(.degrees(reduceMotion ? 0 : -openAngle * (1 - closure)), anchor: .bottomLeading)
                stick(glass: style == .liquidGlass)
            }
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.gray.gradient).frame(width: 22, height: stickHeight * 1.8)
                    .overlay {
                        VStack { Circle().fill(.black.opacity(0.7)); Spacer(); Circle().fill(.black.opacity(0.7)) }.padding(8)
                    }
            }
            .padding(.top, reduceMotion ? 6 : availableWidth * sin(openAngle * .pi / 180) + 6)
            .padding(.bottom, 4).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Clap slate"))
        .accessibilityHint(Text("Saves a snapshot and plays the clap sound."))
    }
}
private struct StickSurface: ViewModifier {
    let glass: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if glass { content.glassEffect(.clear, in: RoundedRectangle(cornerRadius: 7)) }
        else { content.shadow(color: .black.opacity(0.12), radius: 2, y: 1).shadow(color: .black.opacity(0.08), radius: 7, y: 4) }
    }
}
