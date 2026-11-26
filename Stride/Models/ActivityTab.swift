import SwiftUI

/// The optional bottom tabs. Summary and You are always shown.
enum ActivityTab: String, CaseIterable, Identifiable {
    case run
    case jog
    case walk
    case stepper
    case energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .run: "Running"
        case .jog: "Jogging"
        case .walk: "Walk"
        case .stepper: "Steps"
        case .energy: "Energy"
        }
    }

    var symbol: String {
        switch self {
        case .run: ActivityKind.run.symbol
        case .jog: ActivityKind.jog.symbol
        case .walk: ActivityKind.walk.symbol
        case .stepper: "shoeprints.fill"
        case .energy: "flame.fill"
        }
    }

    var focus: StatsFocus {
        switch self {
        case .run: .kind(.run)
        case .jog: .kind(.jog)
        case .walk: .kind(.walk)
        case .stepper: .steps
        case .energy: .energy
        }
    }

    /// One colour per mode, used for its tab icon, switch, goal, rings and
    /// selected day or week.
    var color: Color {
        switch self {
        case .run: ActivityKind.run.color
        case .jog: ActivityKind.jog.color
        case .walk: ActivityKind.walk.color
        case .stepper: Palette.steps
        case .energy: Palette.energy
        }
    }

    static let defaultEnabled: Set<ActivityTab> = [.run]
}

/// What a stats screen shows: everything, one activity kind, or steps.
enum StatsFocus: Hashable {
    var color: Color {
        switch self {
        case .summary: .accentColor
        case .kind(let kind): kind.color
        case .steps: Palette.steps
        case .energy: Palette.energy
        }
    }

    case summary
    case kind(ActivityKind)
    case steps
    case energy

    var title: String {
        switch self {
        case .summary: "Summary"
        case .kind(.run): ActivityTab.run.title
        case .kind(.jog): ActivityTab.jog.title
        case .kind(.walk): ActivityTab.walk.title
        case .steps: ActivityTab.stepper.title
        case .energy: ActivityTab.energy.title
        }
    }
}

/// The period a goal covers. Week and Month views use their own goals.
enum GoalPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    init(_ period: StatsPeriod) {
        switch period {
        case .daily: self = .daily
        case .week: self = .weekly
        case .month: self = .monthly
        }
    }

    var stepRange: ClosedRange<Int> {
        switch self {
        case .daily: 1_000...40_000
        case .weekly: 5_000...280_000
        case .monthly: 20_000...1_200_000
        }
    }

    var stepIncrement: Int {
        switch self {
        case .daily: 500
        case .weekly: 2_500
        case .monthly: 10_000
        }
    }

    var distanceRangeKm: ClosedRange<Double> {
        switch self {
        case .daily: 0.5...50
        case .weekly: 1...300
        case .monthly: 5...1_000
        }
    }

    var distanceIncrementKm: Double {
        switch self {
        case .daily: 0.5
        case .weekly: 1
        case .monthly: 5
        }
    }

    var defaultSteps: Int {
        switch self {
        case .daily: 10_000
        case .weekly: 70_000
        case .monthly: 300_000
        }
    }

    var energyRange: ClosedRange<Int> {
        switch self {
        case .daily: 50...3_000
        case .weekly: 250...20_000
        case .monthly: 1_000...80_000
        }
    }

    var energyIncrement: Int {
        switch self {
        case .daily: 25
        case .weekly: 250
        case .monthly: 1_000
        }
    }

    var defaultEnergy: Int {
        switch self {
        case .daily: 400
        case .weekly: 2_800
        case .monthly: 12_000
        }
    }

    func defaultDistanceKm(for kind: ActivityKind) -> Double {
        switch (kind, self) {
        case (.run, .daily): 3
        case (.run, .weekly): 15
        case (.run, .monthly): 60
        case (.jog, .daily): 2
        case (.jog, .weekly): 10
        case (.jog, .monthly): 40
        case (.walk, .daily): 3
        case (.walk, .weekly): 20
        case (.walk, .monthly): 80
        }
    }
}
