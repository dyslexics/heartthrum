import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    enum Range: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var labelKey: String {
            switch self {
            case .day: return "Day"
            case .week: return "Week"
            case .month: return "Month"
            }
        }
        var interval: TimeInterval {
            switch self {
            case .day: return 86_400
            case .week: return 7 * 86_400
            case .month: return 30 * 86_400
            }
        }
    }

    @Query(sort: \PulseRecord.date, order: .reverse) private var records: [PulseRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var range: Range = .week

    private var visible: [PulseRecord] {
        let cutoff = Date().addingTimeInterval(-range.interval)
        return records.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView {
                        Label("No measurements yet", systemImage: "heart.text.square")
                    } description: {
                        Text("Your saved measurements appear here.")
                    }
                } else {
                    List {
                        Section {
                            Picker("Range", selection: $range) {
                                ForEach(Range.allCases) { r in
                                    Text(LocalizedStringKey(r.labelKey)).tag(r)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowSeparator(.hidden)

                            if visible.isEmpty {
                                Text("No measurements in this period.")
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                            } else {
                                chart
                                    .frame(height: 200)
                                stats
                            }
                        }
                        Section {
                            ForEach(records) { record in
                                row(record)
                            }
                            .onDelete { offsets in
                                for i in offsets { modelContext.delete(records[i]) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }

    private var chart: some View {
        Chart(visible) { record in
            LineMark(x: .value("Date", record.date), y: .value("BPM", record.bpm))
                .foregroundStyle(.pink)
                .interpolationMethod(.catmullRom)
            PointMark(x: .value("Date", record.date), y: .value("BPM", record.bpm))
                .foregroundStyle(.pink)
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }

    private var stats: some View {
        let values = visible.map(\.bpm)
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / values.count
        return HStack {
            statBox("Average", value: avg)
            statBox("Min", value: values.min() ?? 0)
            statBox("Max", value: values.max() ?? 0)
        }
    }

    private func statBox(_ titleKey: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.pink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ record: PulseRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(record.bpm) BPM")
                        .font(.headline)
                    if let mood = record.mood, (1...3).contains(mood) {
                        Text(["😕", "🙂", "😄"][mood - 1])
                    }
                }
                Text(record.date, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let raw = record.tag, let tag = MeasureTag(rawValue: raw) {
                Label(LocalizedStringKey(tag.labelKey), systemImage: tag.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
    }
}
