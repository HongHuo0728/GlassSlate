import SwiftUI

struct DrawerView: View {
    @Bindable var repository: SlateRepository
    let isPresented: Bool
    var isPersistent = false
    let production: String
    let deleted: HistoryDeletion?
    let restore: (HistorySnapshot) -> Void
    let delete: (HistorySnapshot) -> Void
    let deleteProject: (UUID, ProjectDeletionMode) -> Void
    let undo: () -> Void
    let settings: () -> Void
    let close: () -> Void
    let presentationChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var newProject = false
    @State private var editingRecord: HistorySnapshot?
    @State private var deletingProject: ProjectFolder?
    @State private var targetedProject: UUID?
    @State private var unfiledTargeted = false
    @State private var failure: String?

    var body: some View {
        let grouped = Dictionary(grouping: repository.records, by: \.projectID)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("History").font(.title2.bold())
                    Spacer(minLength: 8)
                    Button { newProject = true } label: { Image(systemName: "folder.badge.plus").frame(width: 24, height: 24) }
                        .buttonStyle(SlateActionStyle(compact: true, iconOnly: true)).accessibilityLabel(Text("New project"))
                        .popover(isPresented: $newProject, arrowEdge: .top) {
                            NameEditorPopover(title: "New project", name: "", placeholder: String(localized: "Project name")) {
                                _ = try await repository.createProject(name: $0)
                            }
                        }
                    if !isPersistent {
                        Button(action: close) { Image(systemName: "xmark").frame(width: 24, height: 24) }
                            .buttonStyle(SlateActionStyle(compact: true, iconOnly: true)).accessibilityLabel(Text("Close history"))
                    }
                }
                Text(verbatim: production.isEmpty ? String(localized: "Your film starts here") : production)
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }.padding(16)
            List {
                if !repository.projects.isEmpty {
                    Section("Projects") {
                        ForEach(repository.projects) { project in
                            let children = grouped[project.id] ?? []
                            projectRow(project, count: children.count)
                            if project.isExpanded {
                                if children.isEmpty {
                                    Text("Drop slates here").font(.footnote).foregroundStyle(.secondary)
                                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                                }
                                ForEach(children) { record in slateRow(record) }
                            }
                        }
                    }
                }
                Section {
                    let unfiled = grouped[nil] ?? []
                    if repository.records.isEmpty {
                        ContentUnavailableView("No slates yet", systemImage: "rectangle.stack",
                                               description: Text("Tap the striped clapper. Each take will appear here."))
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    ForEach(unfiled) { record in slateRow(record) }
                } header: {
                    Text(repository.projects.isEmpty ? "All slates" : "Unfiled slates")
                        .textCase(nil).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                        .background(unfiledTargeted ? Color.blue.opacity(0.15) : .clear, in: Capsule())
                        .dropDestination(for: String.self) { values, _ in drop(values, into: nil) }
                            isTargeted: { unfiledTargeted = $0 }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .ignoresSafeArea(.container, edges: .horizontal)
            .animation(reduced ? nil : .snappy(duration: 0.22), value: repository.records)
            .animation(reduced ? nil : .snappy(duration: 0.22), value: repository.projects)
            HStack(spacing: 12) {
                Button(action: settings) { Image(systemName: "slider.horizontal.3").frame(width: 24, height: 24) }
                    .buttonStyle(SlateActionStyle(compact: true, iconOnly: true)).accessibilityLabel(Text("Settings"))
                Spacer(minLength: 0)
                if deleted != nil {
                    HStack(spacing: 12) {
                        Text(deleted?.isProject == true ? "Project deleted" : "Slate deleted")
                            .font(.caption).lineLimit(1).minimumScaleFactor(0.8)
                        Button("Undo", action: undo).font(.subheadline.weight(.semibold)).foregroundStyle(.blue).buttonStyle(.plain)
                            .frame(minHeight: 44).disabled(repository.isSaving)
                    }.padding(.horizontal, 16).glassPanel(radius: 1000)
                        .transition(reduced ? .opacity : .scale(scale: 0.82, anchor: .trailing).combined(with: .opacity))
                } else { Text("\(repository.records.count) slates").font(.caption).monospacedDigit().foregroundStyle(.secondary) }
            }.padding(16)
        }
        // 22 pt circular/capsule radius + 16 pt edge inset = 38 pt outer radius.
        .glassPanel(radius: 38)
        .onChange(of: isPresented) { _, shown in
            if !shown { newProject = false; editingRecord = nil; deletingProject = nil }
        }
        .onChange(of: newProject || editingRecord != nil || deletingProject != nil) { _, value in presentationChanged(value) }
        .onDisappear { presentationChanged(false) }
        .accessibilityAddTraits(isPersistent ? [] : .isModal)
        .accessibilityAction(.escape) { if !isPersistent { close() } }
        .confirmationDialog("Delete project?", isPresented: Binding(get: { deletingProject != nil }, set: { if !$0 { deletingProject = nil } }),
                            titleVisibility: .visible, presenting: deletingProject) { project in
            if repository.records.contains(where: { $0.projectID == project.id }) {
                Button("Delete project, keep slates", role: .destructive) { deleteProject(project.id, .keepSlates) }
                Button("Delete project and all slates", role: .destructive) { deleteProject(project.id, .deleteSlates) }
            } else {
                Button("Delete project", role: .destructive) { deleteProject(project.id, .keepSlates) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { project in
            Text("Delete “\(project.name)”? You can keep its slates in Unfiled slates or delete them with the project.")
        }
        .alert("Unable to complete action", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { failure = nil }
        } message: { Text(verbatim: failure ?? "") }
    }
    private func projectRow(_ project: ProjectFolder, count: Int) -> some View {
        Button { perform { try await repository.setExpanded(id: project.id, expanded: !project.isExpanded) } } label: {
            projectLabel(project, count: count)
        }
        .buttonStyle(.plain).disabled(repository.isSaving)
        .contextMenu {
            Button("Delete project…", systemImage: "trash", role: .destructive) { deletingProject = project }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deletingProject = project } label: { Label("Delete", systemImage: "trash") }.tint(.red)
        }
        .listRowBackground(Color.clear).listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .accessibilityValue(Text(project.isExpanded ? "Expanded" : "Collapsed"))
        .accessibilityAction(named: Text("Delete project")) { deletingProject = project }
    }
    private func projectLabel(_ project: ProjectFolder, count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                .rotationEffect(.degrees(project.isExpanded ? 90 : 0)).foregroundStyle(.secondary)
            Image(systemName: project.isExpanded ? "folder.fill" : "folder").foregroundStyle(.blue)
            Text(verbatim: project.name).font(.headline).lineLimit(2)
            Spacer(minLength: 4)
            Text(count, format: .number)
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }.padding(.vertical, 10).contentShape(Rectangle())
            .background(targetedProject == project.id ? Color.blue.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 16))
            .dropDestination(for: String.self) { values, _ in drop(values, into: project.id) }
                isTargeted: { targetedProject = $0 ? project.id : nil }
            .accessibilityHint(Text("Drop a slate here to move it into this project."))
    }
    private func slateRow(_ record: HistorySnapshot) -> some View {
        interactiveCard(record)
            .draggable(record.id.uuidString)
            .popover(isPresented: Binding(get: { editingRecord?.id == record.id }, set: { if !$0 { editingRecord = nil } }), arrowEdge: .bottom) {
                NameEditorPopover(title: "Rename slate", name: record.displayName ?? "", placeholder: record.title, allowEmpty: true) {
                    try await repository.rename(id: record.id, name: $0)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { delete(record) } label: { Label("Delete", systemImage: "trash") }.tint(.red)
            }
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { restore(record) }
            .accessibilityAction(named: Text("Rename")) { editingRecord = record }
            .accessibilityAction(named: Text("Restore slate")) { restore(record) }
            .accessibilityAction(named: Text("Delete")) { delete(record) }
    }
    private func interactiveCard(_ record: HistorySnapshot) -> some View {
        HistoryCard(record: record)
            .onTapGesture { if !repository.isSaving { restore(record) } }
            .contextMenu {
                Button("Rename", systemImage: "pencil") { editingRecord = record; SlateHaptics.selection() }
                Menu {
                    Button("Unfiled slates") { perform { try await repository.move(id: record.id, projectID: nil) } }
                    ForEach(repository.projects) { project in
                        Button(project.name) { perform { try await repository.move(id: record.id, projectID: project.id) } }
                    }
                } label: { Label("Move to project", systemImage: "folder") }
                Menu {
                    Button("Delete slate", role: .destructive) { delete(record) }
                    Button("Cancel", role: .cancel) { SlateHaptics.selection() }
                } label: { Label("Delete…", systemImage: "trash") }
            }
    }
    private func drop(_ values: [String], into project: UUID?) -> Bool {
        guard !repository.isSaving, let id = values.first.flatMap(UUID.init(uuidString:)), repository.records.contains(where: { $0.id == id }) else { return false }
        perform { try await repository.move(id: id, projectID: project) }
        return true
    }
    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        Task {
            do { try await action(); SlateHaptics.selection() }
            catch { failure = error.localizedDescription; SlateHaptics.error() }
        }
    }
}
