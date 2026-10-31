import SwiftUI

/// Classic mode uses an anchored popover instead of the current OS's glass context menu.
struct ClassicHistoryPopover: View {
    let record: HistorySnapshot
    let projects: [ProjectFolder]
    let rename: (String) async throws -> Void
    let move: (UUID?) async throws -> Void
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var page: Page = .actions
    @State private var saving = false
    @State private var failure: String?
    private enum Page { case actions, rename, projects, delete }

    var body: some View {
        Group {
            if page == .rename {
                NameEditorPopover(title: "Rename slate", name: record.displayName ?? "",
                                  placeholder: record.title, allowEmpty: true, save: rename)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if page == .delete {
                        Text("Delete slate?").font(.headline)
                        Text("This removes this snapshot from history.").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button { navigate(.actions) } label: {
                                Text("Cancel").frame(maxWidth: .infinity, minHeight: 20)
                            }.buttonStyle(SlateActionStyle(compact: true))
                            Button(role: .destructive) { delete(); dismiss() } label: {
                                Text("Delete").frame(maxWidth: .infinity, minHeight: 20)
                            }.buttonStyle(SlateActionStyle(prominent: true, compact: true))
                        }
                    } else {
                        Text(verbatim: record.title).font(.headline).lineLimit(2)
                        if page == .projects {
                            Text("Move to project").font(.subheadline).foregroundStyle(.secondary)
                            ScrollView {
                                VStack(spacing: 10) {
                                    projectButton(nil, name: String(localized: "Unfiled slates"))
                                    ForEach(projects) { project in projectButton(project.id, name: project.name) }
                                }.padding(4)
                            }.frame(maxHeight: 220)
                            action("Cancel", icon: "chevron.left") { navigate(.actions) }
                        } else {
                            action("Rename", icon: "pencil") { navigate(.rename) }
                            action("Move to project", icon: "folder") { navigate(.projects) }
                            Button(role: .destructive) { navigate(.delete) } label: {
                                Label("Delete…", systemImage: "trash").frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(SlateActionStyle(compact: true))
                            action("Cancel", icon: "xmark") { dismiss() }
                        }
                    }
                    if let failure {
                        Text(verbatim: failure).font(.footnote).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if saving { ProgressView().frame(maxWidth: .infinity) }
                }.padding(20).frame(width: 300).disabled(saving)
            }
        }
        .presentationCompactAdaptation(.popover)
        .modifier(SlatePopoverSurface())
    }

    private func action(_ title: LocalizedStringKey, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(SlateActionStyle(compact: true))
    }
    private func projectButton(_ id: UUID?, name: String) -> some View {
        Button {
            saving = true; failure = nil
            Task {
                do { try await move(id); SlateHaptics.success(); dismiss() }
                catch { saving = false; failure = error.localizedDescription; SlateHaptics.error() }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                Text(verbatim: name).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                if record.projectID == id { Image(systemName: "checkmark") }
            }
        }.buttonStyle(SlateActionStyle(compact: true))
    }
    private func navigate(_ destination: Page) {
        SlateHaptics.selection()
        withAnimation(reduced ? nil : .easeInOut(duration: 0.16)) { page = destination; failure = nil }
    }
}
