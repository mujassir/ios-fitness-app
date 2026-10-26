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
                    (Formatters.speed(session.averageSpeedKmh, metric: metric),
                     Formatters.speed(session.minSpeedKmh, metric: metric),
                     Formatters.speed(session.maxSpeedKmh, metric: metric))
                }
                rangeCard(title: "Pace", unit: Formatters.paceUnit(metric: metric)) {
                    (Formatters.pace(secondsPerMeter: session.averagePaceSecondsPerMeter, metric: metric),
                     Formatters.pace(secondsPerMeter: session.minPaceSecondsPerMeter, metric: metric),
                     Formatters.pace(secondsPerMeter: session.maxPaceSecondsPerMeter, metric: metric))
                }
                rangeCard(title: "Tempo", unit: "spm") {
                    (Formatters.tempo(session.averageTempo),
                     Formatters.tempo(session.minTempo),
                     Formatters.tempo(session.maxTempo))
                }
                chartCard
            }
            .padding(20)
        }
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
                title: "Steps",
                value: Formatters.steps(session.steps),
                unit: "steps",
                symbol: "shoeprints.fill"
            )
            MetricTile(
                title: "Energy",
                value: Formatters.calories(session.calories),
                unit: "kcal",
                symbol: "flame.fill"
            )
            MetricTile(
                title: "Avg pace",
                value: Formatters.pace(secondsPerMeter: session.averagePaceSecondsPerMeter, metric: metric),
                unit: "",
                symbol: "gauge.with.needle"
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
