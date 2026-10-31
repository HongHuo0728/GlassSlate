import SwiftUI

struct DrawerView: View {
    @Bindable var repository: SlateRepository
    let isPresented: Bool
    let production: String
    let deleted: HistorySnapshot?
    let restore: (HistorySnapshot) -> Void
    let delete: (HistorySnapshot) -> Void
    let undo: () -> Void
    let settings: () -> Void
    let close: () -> Void
    @Environment(\.slateVisualStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var newProject = false
    @State private var editingRecord: HistorySnapshot?
    @State private var classicRecord: UUID?
    @State private var targetedProject: UUID?
    @State private var unfiledTargeted = false
    @State private var failure: String?

    var body: some View {
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
                    Button(action: close) { Image(systemName: "xmark").frame(width: 24, height: 24) }
                        .buttonStyle(SlateActionStyle(compact: true, iconOnly: true)).accessibilityLabel(Text("Close history"))
                }
                Text(verbatim: production.isEmpty ? String(localized: "Your film starts here") : production)
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }.padding(16)
            List {
                if !repository.projects.isEmpty {
                    Section("Projects") {
                        ForEach(repository.projects) { project in
                            DisclosureGroup(isExpanded: Binding(get: { project.isExpanded }, set: { expanded in
                                perform { try await repository.setExpanded(id: project.id, expanded: expanded) }
                            })) {
                                let children = repository.records.filter { $0.projectID == project.id }
                                if children.isEmpty {
                                    Text("Drop slates here").font(.footnote).foregroundStyle(.secondary)
                                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                                }
                                ForEach(children) { record in slateRow(record) }
                            } label: { projectLabel(project) }
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                    }
                }
                Section {
                    let unfiled = repository.records.filter { $0.projectID == nil }
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
                        Text("Slate deleted").font(.caption).lineLimit(1).minimumScaleFactor(0.8)
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
            if !shown { newProject = false; editingRecord = nil; classicRecord = nil }
        }
        .accessibilityAddTraits(.isModal).accessibilityAction(.escape, close)
        .alert("Unable to complete action", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { failure = nil }
        } message: { Text(verbatim: failure ?? "") }
    }
    private func projectLabel(_ project: ProjectFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: project.isExpanded ? "folder.fill" : "folder").foregroundStyle(.blue)
            Text(verbatim: project.name).font(.headline).lineLimit(2)
            Spacer(minLength: 4)
            Text(repository.records.filter { $0.projectID == project.id }.count, format: .number)
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
    }
    @ViewBuilder private func interactiveCard(_ record: HistorySnapshot) -> some View {
        if style == .liquidGlass {
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
        } else {
            HistoryCard(record: record)
                // Present on release so holding and moving can still begin a native drag.
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.45, maximumDistance: 10)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .exclusively(before: TapGesture()).onEnded { gesture in
                    switch gesture {
                    case .first(.second(true, let drag)):
                        guard !repository.isSaving else { return }
                        let movement = drag?.translation ?? .zero
                        guard abs(movement.width) <= 10, abs(movement.height) <= 10 else { return }
                        classicRecord = record.id; SlateHaptics.selection()
                    case .second:
                        if !repository.isSaving { restore(record) }
                    default: break
                    }
                })
                .popover(isPresented: Binding(get: { classicRecord == record.id }, set: { if !$0 { classicRecord = nil } }), arrowEdge: .bottom) {
                    ClassicHistoryPopover(record: record, projects: repository.projects,
                        rename: { try await repository.rename(id: record.id, name: $0) },
                        move: { try await repository.move(id: record.id, projectID: $0) },
                        delete: { delete(record) })
                }
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
