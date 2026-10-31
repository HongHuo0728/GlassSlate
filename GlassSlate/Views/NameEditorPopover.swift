import SwiftUI

struct NameEditorPopover: View {
    let title: LocalizedStringKey
    let placeholder: String
    let allowEmpty: Bool
    let save: (String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.slateVisualStyle) private var style
    @State private var name: String
    @State private var saving = false
    @State private var failure: String?
    @FocusState private var focused: Bool
    init(title: LocalizedStringKey, name: String, placeholder: String = "", allowEmpty: Bool = false,
         save: @escaping (String) async throws -> Void) {
        self.title = title; self.placeholder = placeholder; self.allowEmpty = allowEmpty; self.save = save
        _name = State(initialValue: name)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            TextField(placeholder, text: $name).textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .glassPanel(radius: style == .liquidGlass ? 1000 : 12)
                .focused($focused).submitLabel(.done).onSubmit(commit)
                .accessibilityLabel(Text("Name"))
            if let failure { Text(verbatim: failure).font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Cancel").frame(maxWidth: .infinity, minHeight: 20)
                }.buttonStyle(SlateActionStyle(compact: true)).disabled(saving)
                Button(action: commit) {
                    HStack { if saving { ProgressView() }; Text("Save") }
                        .frame(maxWidth: .infinity, minHeight: 20)
                }.buttonStyle(SlateActionStyle(prominent: true, compact: true))
                    .disabled(saving || (!allowEmpty && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }.padding(20).frame(width: 300).presentationCompactAdaptation(.popover)
            .modifier(SlatePopoverSurface())
            .task { focused = true }
    }
    private func commit() {
        guard !saving, allowEmpty || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saving = true
        Task {
            do { try await save(name); SlateHaptics.success(); dismiss() }
            catch { saving = false; failure = error.localizedDescription; SlateHaptics.error() }
        }
    }
}
