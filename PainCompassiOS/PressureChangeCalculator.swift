import Foundation

struct PressureDataPoint: Equatable {
    let hectopascals: Double
    let measuredAt: Date
}

enum PressureChangeDirection: Equatable {
    case rising
    case falling
    case unchanged
}

struct PressureChange: Equatable {
    let differenceHectopascals: Double
    let direction: PressureChangeDirection
    let comparisonData: PressureDataPoint
}

enum PressureChangeCalculationResult: Equatable {
    case calculated(PressureChange)
    case comparisonDataUnavailable
}

enum PressureChangeCalculator {
    private static let comparisonInterval: TimeInterval = 24 * 60 * 60
    private static let comparisonTolerance: TimeInterval = 3 * 60 * 60

    static func calculate(
        current: PressureDataPoint,
        history: [PressureDataPoint]
    ) -> PressureChangeCalculationResult {
        let targetDate = current.measuredAt.addingTimeInterval(-comparisonInterval)
        let comparisonData = history
            .filter { abs($0.measuredAt.timeIntervalSince(targetDate)) <= comparisonTolerance }
            .min {
                abs($0.measuredAt.timeIntervalSince(targetDate))
                    < abs($1.measuredAt.timeIntervalSince(targetDate))
            }

        guard let comparisonData else {
            return .comparisonDataUnavailable
        }

        let difference = current.hectopascals - comparisonData.hectopascals
        let direction: PressureChangeDirection
        if difference > 0 {
            direction = .rising
        } else if difference < 0 {
            direction = .falling
        } else {
            direction = .unchanged
        }

        return .calculated(
            PressureChange(
                differenceHectopascals: difference,
                direction: direction,
                comparisonData: comparisonData
            )
        )
    }
}
