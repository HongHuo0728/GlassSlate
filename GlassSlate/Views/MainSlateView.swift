import SwiftUI
import UIKit

struct MainSlateView: View {
    @Bindable var repository: SlateRepository
    @Bindable var audio: ClapAudioService
    @Bindable var settings: SettingsStore
    let liveActivity: LiveActivityService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var drawerOpen = false
    @State private var drawerTranslation: CGFloat = 0
    @State private var settingsOpen = false
    @State private var editing: SlateField?
    @State private var newSlateConfirmation = false
    @State private var locked = false
    @State private var isClapping = false
    @State private var closure: CGFloat = 0
    @State private var clapValues: SlateValues?
    @State private var animationTask: Task<Void, Never>?
    @State private var deletionNoticeID = UUID()
    @State private var deletionNoticeExpiresAt: Date?
    @State private var deleted: HistorySnapshot?
    @State private var error: String?
    private var busy: Bool { isClapping || repository.isSaving }

    var body: some View {
        GeometryReader { geometry in
            let width = min(380, geometry.size.width * 0.9)
            let drawer = DrawerGeometry(panelWidth: width, leadingSafeArea: geometry.safeAreaInsets.leading)
            ZStack(alignment: .leading) {
                SlateBackground()
                SlateStageView(values: clapValues ?? repository.draft, recordCount: repository.records.count,
                               locked: locked, busy: busy, closure: closure,
                               history: openDrawer, settings: openSettings, toggleLock: { locked.toggle() },
                               newSlate: { newSlateConfirmation = true }, edit: { editing = $0 }, clap: clap)
                    .accessibilityHidden(drawerOpen)
                Color.black.opacity(0.24 * (drawerOpen ? max(0, 1 + drawerTranslation / width) : min(1, max(0, drawerTranslation / width))))
                    .ignoresSafeArea().allowsHitTesting(drawerOpen)
                    .onTapGesture(perform: closeDrawer).accessibilityHidden(true)
                DrawerView(repository: repository, isPresented: drawerOpen, production: repository.draft.production,
                           deleted: deleted, restore: restore, delete: delete, undo: undoDelete,
                           settings: openSettings, close: closeDrawer)
                    .frame(width: width).padding(.vertical, 8).padding(.leading, 8)
                    .offset(x: drawer.offset(isOpen: drawerOpen, translation: drawerTranslation))
                    // Contain the drawer and its shadows to this viewport while it slides away.
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                    .clipped()
                    .allowsHitTesting(drawerOpen).accessibilityHidden(!drawerOpen)
            }
            .background(DrawerEdgeGestures(isOpen: drawerOpen,
                allowed: !settingsOpen && editing == nil && !newSlateConfirmation && error == nil,
                opening: { drawerTranslation = min(drawer.travel, max(0, $0)) },
                opened: { translation, velocity in
                    if DrawerGesturePolicy.shouldOpen(translation: translation, velocity: velocity, width: width) { openDrawer() }
                    else { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { drawerTranslation = 0 } }
                },
                closing: { drawerTranslation = max(-drawer.travel, min(0, $0)) },
                closed: { translation, velocity in endDrawerDrag(translation, velocity: velocity, width: width) }))
        }
        .sheet(item: $editing) { field in
            SlateFieldEditor(field: field, values: repository.draft) { try await repository.saveDraft($0) }
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .sheet(isPresented: $settingsOpen) {
            SettingsView(settings: settings, audio: audio, liveActivity: liveActivity).preferredColorScheme(settings.appearance.colorScheme)
        }
        .alert("New blank slate?", isPresented: $newSlateConfirmation) {
            Button("New slate", role: .destructive) {
                Task {
                    do { try await repository.saveDraft(SlateValues()); SlateHaptics.success() }
                    catch { report("Could not save changes. Please try again.") }
                }
            }
            Button("Cancel", role: .cancel) { SlateHaptics.selection() }
        } message: { Text("Your current working slate will be replaced. History is kept.") }
        .alert("Unable to complete action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(verbatim: error ?? "") }
        .task { audio.warmUp(); SlateHaptics.prepare(); await syncLiveActivity() }
        .task(id: deletionNoticeID) {
            guard deleted != nil, let deadline = deletionNoticeExpiresAt else { return }
            let token = deletionNoticeID
            do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
            guard token == deletionNoticeID else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.24)) { deleted = nil; deletionNoticeExpiresAt = nil }
        }
        .onChange(of: repository.draft) { _, _ in Task { await syncLiveActivity() } }
        .onChange(of: settings.liveActivitiesEnabled) { _, _ in Task { await syncLiveActivity() } }
        .onChange(of: locked) { _, value in UIApplication.shared.isIdleTimerDisabled = value && phase == .active }
        .onChange(of: phase) { _, value in
            UIApplication.shared.isIdleTimerDisabled = locked && value == .active
            if value == .active { audio.warmUp(); SlateHaptics.prepare(); Task { await syncLiveActivity() } }
            else {
                animationTask?.cancel(); isClapping = false; closure = 0; clapValues = nil
                if !audio.isPlaying { audio.suspend() }
            }
        }
        .onChange(of: audio.notice) { _, notice in
            if let notice, !settingsOpen, editing == nil { error = notice; audio.clearNotice() }
        }
        .onDisappear { animationTask?.cancel(); UIApplication.shared.isIdleTimerDisabled = false }
    }
    private func openDrawer() {
        SlateHaptics.selection()
        withAnimation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.04)) { drawerTranslation = 0; drawerOpen = true }
    }
    private func closeDrawer() {
        SlateHaptics.selection()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { drawerTranslation = 0; drawerOpen = false }
    }
    private func openSettings() {
        if drawerOpen { closeDrawer() }
        settingsOpen = true
    }
    private func endDrawerDrag(_ translation: CGFloat, velocity: CGFloat, width: CGFloat) {
        if DrawerGesturePolicy.shouldClose(translation: translation, velocity: velocity, width: width) { closeDrawer() }
        else { withAnimation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.1)) { drawerTranslation = 0 } }
    }
    private func restore(_ record: HistorySnapshot) {
        guard !busy else { return }
        Task {
            do { try await repository.restore(record); SlateHaptics.success(); closeDrawer() }
            catch { report("Could not restore this slate. Please try again.") }
        }
    }
    private func delete(_ record: HistorySnapshot) {
        guard !repository.isSaving else { return }
        Task {
            do {
                try await repository.delete(id: record.id)
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                    deleted = record; deletionNoticeID = UUID(); deletionNoticeExpiresAt = Date().addingTimeInterval(5)
                }
                SlateHaptics.warning()
            }
            catch { report("Could not delete this slate. Please try again.") }
        }
    }
    private func undoDelete() {
        guard let deleted else { return }
        Task {
            do {
                try await repository.undoDelete(deleted)
                if self.deleted?.id == deleted.id {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.24)) {
                        self.deleted = nil; deletionNoticeID = UUID(); deletionNoticeExpiresAt = nil
                    }
                }
                SlateHaptics.success()
            }
            catch { report("Could not save changes. Please try again.") }
        }
    }
    private func report(_ key: String.LocalizationValue) {
        error = String(localized: key)
        SlateHaptics.error()
    }
    private func syncLiveActivity() async {
        await liveActivity.sync(values: repository.draft, enabled: settings.liveActivitiesEnabled, allowStart: phase == .active)
    }
    private func clap() {
        let snapshot: HistorySnapshot
        let operation: Task<HistorySnapshot, Error>
        do {
            (snapshot, operation) = try repository.startClap(autoIncrement: settings.autoIncrement, soundName: audio.soundIdentifier)
        } catch { report("Could not start the clap. Please try again."); return }
        animationTask?.cancel()
        clapValues = snapshot.values
        isClapping = true
        // No debounce or intentional audio delay; every user tap is accepted and queued for storage.
        do { try audio.playImmediate() }
        catch { report("The sound could not play. The slate will still be saved.") }
        SlateHaptics.clap()
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.025)) { closure = 1 }
        Task {
            do {
                _ = try await operation.value
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Take marked"))
                await syncLiveActivity()
            } catch { report("The clap could not be saved. Your working slate is unchanged. Please try again.") }
        }
        animationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(35))
                withAnimation(reduceMotion ? nil : .spring(duration: 0.09, bounce: 0.05)) { closure = 0 }
                try await Task.sleep(for: .milliseconds(90))
                isClapping = false; clapValues = nil
                SlateHaptics.prepare()
            } catch { return }
        }
    }
}
