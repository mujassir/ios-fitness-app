import Charts
import SwiftUI

struct SessionDetailView: View {
    let session: HealthActivitySession
    let metric: Bool
    @State private var chartMetric: SessionChartMetric = .speed

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                summaryGrid
                rangeCard(title: "Speed", unit: Formatters.speedUnit(metric: metric)) {
                    (Formatters.speedValue(session.averageSpeedKmh, metric: metric),
                     Formatters.speedValue(session.minSpeedKmh, metric: metric),
                     Formatters.speedValue(session.maxSpeedKmh, metric: metric))
                }
                rangeCard(title: "Pace", unit: metric ? "min/km" : "min/mi") {
                    (Formatters.paceValue(secondsPerMeter: session.averagePaceSecondsPerMeter, metric: metric),
                     Formatters.paceValue(secondsPerMeter: session.minPaceSecondsPerMeter, metric: metric),
                     Formatters.paceValue(secondsPerMeter: session.maxPaceSecondsPerMeter, metric: metric))
                }
                rangeCard(title: "Tempo", unit: "spm") {
                    (Formatters.tempoValue(session.averageTempo),
                     Formatters.tempoValue(session.minTempo),
                     Formatters.tempoValue(session.maxTempo))
                }
                chartCard
                splitsCard
            }
            .padding(20)
        }
        .clearsTabBar()
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: session.kind.symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(session.kind.color)
                .frame(width: 72, height: 72)
                .background(session.kind.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(session.start.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)
                Text("\(session.start.formatted(date: .omitted, time: .shortened)) – \(session.end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Formatters.duration(session.duration))
                    .font(.title3.weight(.bold).monospacedDigit())
            }
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(
                title: "Distance",
                value: Formatters.distanceValue(session.distanceMeters, metric: metric),
                unit: Formatters.distanceUnit(session.distanceMeters, metric: metric),
                symbol: "point.bottomleft.forward.to.point.topright.scurvepath"
            )
            MetricTile(
                title: "Avg speed",
                value: Formatters.speedValue(session.averageSpeedKmh, metric: metric),
                unit: Formatters.speedUnit(metric: metric),
                symbol: "gauge.with.needle"
            )
            MetricTile(
                title: "Energy",
                value: Formatters.calories(session.calories),
                unit: "kcal",
                symbol: "flame.fill"
            )
            MetricTile(
                title: "Steps",
                value: Formatters.steps(session.steps),
                unit: "steps",
                symbol: "shoeprints.fill"
            )
        }
    }

    private func rangeCard(
        title: String,
        unit: String,
        values: () -> (String, String, String)
    ) -> some View {
        let triple = values()
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack {
                labeled("Avg", triple.0)
                Spacer()
                labeled("Min", triple.1)
                Spacer()
                labeled("Max", triple.2)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Graph")
                .font(.headline)

            Picker("Chart", selection: $chartMetric) {
                ForEach(SessionChartMetric.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if session.samples.isEmpty {
                ContentUnavailableView(
                    "No minute data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("This session doesn’t have a speed series from Health.")
                )
                .frame(minHeight: 160)
            } else {
                Chart(session.samples) { sample in
                    LineMark(
                        x: .value("Time", sample.start),
                        y: .value(chartMetric.title, chartValue(sample))
                    )
                    .foregroundStyle(session.kind.color)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Time", sample.start),
                        y: .value(chartMetric.title, chartValue(sample))
                    )
                    .foregroundStyle(session.kind.color.opacity(0.14))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxisLabel(chartMetric.axisLabel(metric: metric))
                .frame(height: 220)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var unitMeters: Double { metric ? 1000 : 1609.344 }

    @ViewBuilder
    private var splitsCard: some View {
        let splits = session.splits(unitMeters: unitMeters)
        if !splits.isEmpty {
            let fastest = splits.filter { !$0.isPartial }.map(\.speedKmh).max() ?? 0
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(metric ? "Each km" : "Each mile")
                        .font(.headline)
                    Spacer()
                    Text(Formatters.speedUnit(metric: metric))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(metric ? "KM" : "MI")
                        .frame(width: 56, alignment: .leading)
                    Text("TIME")
                    Spacer()
                    Text("SPEED")
                }
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)

                ForEach(splits) { split in
                    HStack(spacing: 12) {
                        Text(splitLabel(split))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 56, alignment: .leading)
                        Text(Formatters.duration(split.duration))
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 64, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(session.kind.color.opacity(split.speedKmh >= fastest && !split.isPartial ? 1 : 0.5))
                                .frame(width: max(4, proxy.size.width * split.speedKmh / max(fastest, split.speedKmh, 0.1)))
                        }
                        .frame(height: 8)
                        Text(Formatters.speedValue(split.speedKmh, metric: metric))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(splitLabel(split)): \(Formatters.duration(split.duration)), \(Formatters.speed(split.speedKmh, metric: metric))")
                }
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    /// "1", "2"… for full splits; the last partial one shows its distance, like "0.75".
    private func splitLabel(_ split: SessionSplit) -> String {
        guard split.isPartial else { return "\(split.index)" }
        return String(format: "%.2f", split.distanceMeters / unitMeters)
    }

    private func chartValue(_ sample: SessionSample) -> Double {
        switch chartMetric {
        case .speed:
            return metric ? sample.speedKmh : sample.speedKmh * 0.621371
        case .pace:
            guard let seconds = sample.paceSecondsPerMeter else { return 0 }
            return metric ? seconds * 1000 / 60 : seconds * 1609.344 / 60
        case .tempo:
            return sample.tempo
        }
    }
}

private enum SessionChartMetric: String, CaseIterable, Identifiable {
    case speed
    case pace
    case tempo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speed: "Speed"
        case .pace: "Pace"
        case .tempo: "Tempo"
        }
    }

    func axisLabel(metric: Bool) -> String {
        switch self {
        case .speed: Formatters.speedUnit(metric: metric)
        case .pace: metric ? "min/km" : "min/mi"
        case .tempo: "spm"
        }
    }
}
