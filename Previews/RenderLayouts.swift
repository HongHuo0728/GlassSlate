// Native macOS offscreen layout checks; these images are not iOS device screenshots.
import AppKit
import Observation
import SwiftUI

@MainActor @Observable private final class MotionState { var trigger = 0 }
private struct MotionProbe: View {
    let state: MotionState
    var body: some View {
        ZStack {
            SlateBackground()
            ClapperView(clapTrigger: state.trigger, availableWidth: 358, action: {})
                .padding(16)
        }.frame(width: 390, height: 200)
            .environment(\.slateVisualStyle, .classic)
            .environment(\.colorScheme, .light)
    }
}

@main struct RenderLayouts {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let repository = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        var sample = repository.draft
        sample.production = "The Last Blue Hour"
        sample.roll = "A001"; sample.scene = "12A"; sample.shot = "03"; sample.take = "009"
        sample.director = "Maya Chen"; sample.cameraman = "Alex Morgan"
        sample.date = Date(timeIntervalSince1970: 1793404800)
        try await repository.saveDraft(sample)
        let project = try await repository.createProject(name: "Blue Hour · Day 1")
        let folded = try await repository.createProject(name: "Evening interiors")
        try await repository.setExpanded(id: folded.id, expanded: false)
        for index in 0..<7 {
            let record = try await repository.clap(autoIncrement: true, soundName: "default", now: Date(timeIntervalSince1970: 1793404800 + Double(index)))
            if index < 3 { try await repository.move(id: record.id, projectID: project.id) }
        }
        for (name, width, height, tablet, dark, large) in [
            ("iPhone-Portrait-Light", 390.0, 844.0, false, false, false),
            ("iPhone-Landscape-Light", 844, 390, false, false, false),
            ("iPad-Portrait-744-Light", 744, 1133, true, false, false),
            ("iPad-Landscape-Dark", 1133, 744, true, true, false),
            ("iPad-Narrow-600-Light", 600, 900, false, false, false),
            ("iPad-Large-Type-Light", 834, 1194, true, false, true)
        ] {
            let view = ZStack {
                SlateBackground()
                if tablet {
                    HStack(spacing: 12) {
                        DrawerView(repository: repository, isPresented: true, isPersistent: true,
                                   production: sample.production, deleted: nil, restore: { _ in }, delete: { _ in },
                                   deleteProject: { _, _ in }, undo: {}, settings: {}, close: {}, presentationChanged: { _ in })
                            .frame(width: HistoryLayout.sidebarWidth)
                        stage(sample, persistent: true)
                    }.padding(12)
                } else {
                    stage(sample, persistent: false)
                        .padding(.horizontal, width > height ? 47 : 0)
                        .padding(.top, width > height ? 0 : 47).padding(.bottom, width > height ? 21 : 34)
                }
            }.frame(width: width, height: height)
                .environment(\.slateVisualStyle, .classic).environment(\.staticSlatePreview, true)
                .environment(\.colorScheme, dark ? .dark : .light)
                .environment(\.dynamicTypeSize, large ? .accessibility2 : .large)
            try render(view, name: name, output: output)
        }
        try renderMotion(output: output)
    }
    @MainActor private static func stage(_ values: SlateValues, persistent: Bool) -> some View {
        SlateStageView(values: values, recordCount: 7, locked: false, busy: false, clapTrigger: 0, persistentHistory: persistent,
                       history: {}, settings: {}, toggleLock: {}, newSlate: {}, edit: { _ in }, clap: {})
    }
    @MainActor private static func render<V: View>(_ view: V, name: String, output: URL) throws {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        host.layoutSubtreeIfNeeded()
        // Populate the native List before capturing its layout.
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.displayIfNeeded()
        try capture(host, name: name, output: output)
        window.close()
    }
    @MainActor private static func capture<V: View>(_ host: NSHostingView<V>, name: String, output: URL) throws {
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: output.appendingPathComponent(name + ".png"))
        print("\(name): \(bitmap.pixelsWide) × \(bitmap.pixelsHigh), macOS offscreen classic layout")
    }
    @MainActor private static func renderMotion(output: URL) throws {
        let state = MotionState()
        let host = NSHostingView(rootView: MotionProbe(state: state))
        host.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 200))
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        try capture(host, name: "Clap-Rest", output: output)
        state.trigger += 1
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.045))
        try capture(host, name: "Clap-Triggered", output: output)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        try capture(host, name: "Clap-Reopened", output: output)
        window.close()
    }
}
