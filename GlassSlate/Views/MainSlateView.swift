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
    @State private var persistentHistory = false
    @State private var drawerModalPresented = false
    @State private var settingsOpen = false
    @State private var editing: SlateField?
    @State private var newSlateConfirmation = false
    @State private var locked = false
    @State private var isClapping = false
    @State private var clapTrigger = 0
    @State private var clapValues: SlateValues?
    @State private var animationTask: Task<Void, Never>?
    @State private var deletionNotice: DeletionNotice?
    @State private var error: String?
    private var busy: Bool { isClapping || repository.isSaving }

    var body: some View {
        GeometryReader { geometry in
            let width = min(380, geometry.size.width * 0.9)
            let drawer = DrawerGeometry(panelWidth: width, leadingSafeArea: geometry.safeAreaInsets.leading)
            let sidebar = HistoryLayout.usesSidebar(isPad: UIDevice.current.userInterfaceIdiom == .pad, width: geometry.size.width)
            let scrimOpacity = settings.activeVisualStyle == .liquidGlass ? 0.32 : 0.24
            ZStack(alignment: .leading) {
                SlateBackground()
                if sidebar {
                    HStack(spacing: 12) {
                        history(persistent: true).frame(width: HistoryLayout.sidebarWidth)
                        stage(persistent: true).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.padding(12)
                } else {
                    stage(persistent: false).accessibilityHidden(drawerOpen)
                    Color.black.opacity(scrimOpacity * (drawerOpen ? max(0, 1 + drawerTranslation / width) : min(1, max(0, drawerTranslation / width))))
                        .ignoresSafeArea().allowsHitTesting(drawerOpen)
                        .onTapGesture(perform: closeDrawer).accessibilityHidden(true)
                    history(persistent: false)
                        .frame(width: width).padding(.vertical, 8).padding(.leading, 8)
                        .offset(x: drawer.offset(isOpen: drawerOpen, translation: drawerTranslation))
                        // Contain the drawer and its shadows to this viewport while it slides away.
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                        .clipped()
                        .allowsHitTesting(drawerOpen).accessibilityHidden(!drawerOpen)
                }
            }
            .background(DrawerEdgeGestures(isOpen: drawerOpen,
                allowed: !sidebar && !drawerModalPresented && !settingsOpen && editing == nil && !newSlateConfirmation && error == nil,
                opening: { drawerTranslation = min(drawer.travel, max(0, $0)) },
                opened: { translation, velocity in
                    if DrawerGesturePolicy.shouldOpen(translation: translation, velocity: velocity, width: width) { openDrawer() }
                    else { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { drawerTranslation = 0 } }
                },
                closing: { drawerTranslation = max(-drawer.travel, min(0, $0)) },
                closed: { translation, velocity in endDrawerDrag(translation, velocity: velocity, width: width) }))
            .onChange(of: geometry.size) { _, _ in drawerTranslation = 0 }
            .onChange(of: sidebar, initial: true) { _, value in
                persistentHistory = value; drawerTranslation = 0; drawerOpen = false
            }
        }
        .sheet(item: $editing) { field in
            SlateFieldEditor(field: field, values: repository.draft) { try await repository.saveField($0) }
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
        .task(id: deletionNotice?.id) {
            guard let notice = deletionNotice else { return }
            do { try await Task.sleep(for: .seconds(max(0, notice.expiresAt.timeIntervalSinceNow))) } catch { return }
            guard notice.id == deletionNotice?.id else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.24)) { deletionNotice = nil }
        }
        .onChange(of: repository.draft) { _, _ in Task { await syncLiveActivity() } }
        .onChange(of: settings.liveActivitiesEnabled) { _, _ in Task { await syncLiveActivity() } }
        .onChange(of: locked) { _, value in UIApplication.shared.isIdleTimerDisabled = value && phase == .active }
        .onChange(of: phase) { _, value in
            UIApplication.shared.isIdleTimerDisabled = locked && value == .active
            if value == .active { audio.warmUp(); SlateHaptics.prepare(); Task { await syncLiveActivity() } }
            else {
                animationTask?.cancel(); isClapping = false; clapValues = nil
                if !audio.isPlaying { audio.suspend() }
            }
        }
        .onChange(of: audio.notice, initial: true) { _, notice in
            if let notice, !settingsOpen, editing == nil { error = notice; audio.clearNotice() }
        }
        .onDisappear { animationTask?.cancel(); UIApplication.shared.isIdleTimerDisabled = false }
    }
    private func stage(persistent: Bool) -> some View {
        SlateStageView(values: clapValues ?? repository.draft, recordCount: repository.records.count,
                       locked: locked, busy: busy, clapTrigger: clapTrigger, persistentHistory: persistent,
                       history: openDrawer, settings: openSettings, toggleLock: { locked.toggle() },
                       newSlate: { newSlateConfirmation = true }, edit: { editing = $0 }, clap: clap)
    }
    private func history(persistent: Bool) -> some View {
        DrawerView(repository: repository, isPresented: persistent || drawerOpen, isPersistent: persistent,
                   production: repository.draft.production, deleted: deletionNotice?.deletion,
                   restore: restore, delete: delete, deleteProject: deleteProject, undo: undoDelete,
                   settings: openSettings, close: closeDrawer, presentationChanged: { drawerModalPresented = $0 })
    }
    private func openDrawer() {
        guard !persistentHistory else { return }
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
            do { try await repository.restore(record); SlateHaptics.success(); if !persistentHistory { closeDrawer() } }
            catch { report("Could not restore this slate. Please try again.") }
        }
    }
    private func delete(_ record: HistorySnapshot) {
        guard !repository.isSaving else { return }
        Task {
            do {
                try await repository.delete(id: record.id)
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                    deletionNotice = DeletionNotice(.slate(record))
                }
                SlateHaptics.warning()
            }
            catch { report("Could not delete this slate. Please try again.") }
        }
    }
    private func deleteProject(_ id: UUID, mode: ProjectDeletionMode) {
        guard !repository.isSaving else { return }
        Task {
            do {
                let snapshot = try await repository.deleteProject(id: id, mode: mode)
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                    deletionNotice = DeletionNotice(.project(snapshot))
                }
                SlateHaptics.warning()
            } catch { report("Could not delete this project. Please try again.") }
        }
    }
    private func undoDelete() {
        guard let notice = deletionNotice, notice.canUndo(at: .now) else { return }
        Task {
            do {
                switch notice.deletion {
                case .slate(let record): try await repository.undoDelete(record)
                case .project(let snapshot): try await repository.undoProjectDelete(snapshot)
                }
                if deletionNotice?.id == notice.id {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.24)) {
                        deletionNotice = nil
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
        clapTrigger &+= 1
        // No debounce or intentional audio delay; every user tap is accepted and queued for storage.
        do { try audio.playImmediate() }
        catch { report("The sound could not play. The slate will still be saved.") }
        SlateHaptics.clap()
        Task {
            do {
                _ = try await operation.value
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Take marked"))
                await syncLiveActivity()
            } catch { report("The clap could not be saved. Your working slate is unchanged. Please try again.") }
        }
        animationTask = Task { @MainActor in
            do {
                // This task only releases the frozen field values; the arm animates independently.
                try await Task.sleep(for: .seconds(ClapMotion.duration))
                isClapping = false; clapValues = nil
                SlateHaptics.prepare()
            } catch { return }
        }
    }
}
