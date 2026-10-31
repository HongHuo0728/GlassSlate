import SwiftUI

/// No custom drag recognizer here: List owns the native solid destructive swipe action.
struct HistoryCard: View {
    let record: HistorySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(verbatim: record.title).font(.headline).fontDesign(.rounded)
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    .transaction { $0.animation = nil }
                Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(.secondary).padding(.top, 3)
            }
            HStack(spacing: 12) {
                detail("Scene", value: record.values.scene)
                detail("Shot", value: record.values.shot)
                detail("Take", value: record.values.take)
            }
            Text(record.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute().second())
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }.foregroundStyle(.primary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(radius: 16).contentShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
    }
    private func detail(_ label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(verbatim: value.isEmpty ? "—" : value).font(.title3.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
