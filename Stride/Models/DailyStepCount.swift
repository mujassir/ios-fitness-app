import Foundation

struct DailyStepCount: Identifiable, Hashable {
    var date: Date
    var steps: Int

    var id: Date { date }
}
