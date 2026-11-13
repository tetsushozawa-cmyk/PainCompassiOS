import Foundation

struct DailyPressureDataPoint: Equatable {
    let hectopascals: Double
    let measuredAt: Date
}

enum DailyPressureChangeLevel: Int, Equatable {
    case largeRise = 2
    case smallRise = 1
    case stable = 0
    case smallFall = -1
    case largeFall = -2
}

struct DailyPressureChange: Equatable {
    let differenceHectopascals: Double
    let level: DailyPressureChangeLevel
    let comparisonData: DailyPressureDataPoint
}

enum DailyPressureChangeCalculator {
    static func calculate(
        current: DailyPressureDataPoint,
        candidates: [DailyPressureDataPoint],
        calendar: Calendar = .current
    ) -> DailyPressureChange? {
        let todayStart = calendar.startOfDay(for: current.measuredAt)
        guard let previousDayStart = calendar.date(
            byAdding: .day,
            value: -1,
            to: todayStart
        ), let targetDate = calendar.date(
            byAdding: .day,
            value: -1,
            to: current.measuredAt
        ) else {
            return nil
        }

        let previousDayCandidates = candidates
            .filter { $0.measuredAt >= previousDayStart && $0.measuredAt < todayStart }
        guard let comparisonData = previousDayCandidates.min(by: {
                abs($0.measuredAt.timeIntervalSince(targetDate))
                    < abs($1.measuredAt.timeIntervalSince(targetDate))
            }) else {
            return nil
        }

        let difference = current.hectopascals - comparisonData.hectopascals
        return DailyPressureChange(
            differenceHectopascals: difference,
            level: level(for: difference),
            comparisonData: comparisonData
        )
    }

    static func level(for differenceHectopascals: Double) -> DailyPressureChangeLevel {
        if differenceHectopascals >= 5 { return .largeRise }
        if differenceHectopascals > 1 { return .smallRise }
        if differenceHectopascals >= -1 { return .stable }
        if differenceHectopascals > -5 { return .smallFall }
        return .largeFall
    }
}
