import SwiftUI

struct SlateFieldEditor: View {
    let field: SlateField
    let save: (SlateFieldEdit) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var date: Date
    @State private var saving = false
    @State private var failure = false
    @FocusState private var focused: Bool
    init(field: SlateField, values: SlateValues, save: @escaping (SlateFieldEdit) async throws -> Void) {
        self.field = field; self.save = save
        _text = State(initialValue: values[field]); _date = State(initialValue: values.date)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey(field.rawValue)).font(.title2.bold())
                Spacer(minLength: 12)
                Button("Cancel") { dismiss() }.buttonStyle(SlateActionStyle(compact: true)).disabled(saving)
            }.padding(20).staggeredEntrance(0)
            ScrollView {
                VStack(spacing: 20) {
                    if field == .date {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.graphical).padding(16).glassPanel(radius: 24)
                            .onChange(of: date) { _, _ in SlateHaptics.selection() }
                    } else {
                        TextField(String(localized: "Enter a value"), text: $text, axis: .vertical)
                            .font(.title2).monospacedDigit().lineLimit(1...4).padding(16).glassPanel(radius: 24, interactive: true)
                            .focused($focused).autocorrectionDisabled().textInputAutocapitalization(.sentences)
                            .submitLabel(.done).onSubmit(commit)
                            .accessibilityLabel(Text(LocalizedStringKey(field.rawValue)))
                    }
                    Button(action: commit) {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Text("Save").font(.headline)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(SlateActionStyle(prominent: true)).disabled(saving)
                }.padding(.horizontal, 20).padding(.bottom, 20).staggeredEntrance(1)
            }.scrollBounceBehavior(.basedOnSize)
        }
        .background { SlateBackground() }.presentationBackground(.clear)
        .presentationDetents(field == .date ? [.large] : [.medium, .large]).presentationDragIndicator(.visible)
        .interactiveDismissDisabled(saving)
        .task { if field != .date { focused = true } }
        .alert("Unable to save", isPresented: $failure) { Button("OK", role: .cancel) {} }
            message: { Text("Could not save changes. Please try again.") }
    }
    private func commit() {
        guard !saving else { return }
        let updated: SlateFieldEdit = field == .date ? .date(date) : .text(field, text)
        saving = true
        Task {
            do { try await save(updated); SlateHaptics.success(); dismiss() }
            catch { saving = false; failure = true; SlateHaptics.error() }
        }
    }
}
