import Charts
import SwiftUI

struct WeeklyStepsChart: View {
    let days: [DailyStepCount]
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.headline)

            if days.isEmpty {
                ContentUnavailableView(
                    "No step history yet",
                    systemImage: "chart.bar",
                    description: Text("Allow Apple Health access to fill this chart.")
                )
                .frame(height: 160)
            } else {
                Chart(days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Steps", day.steps)
                    )
                    .foregroundStyle(day.steps >= goal ? Color.accentColor : Color.accentColor.opacity(0.45))
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Formatters.weekday(date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
