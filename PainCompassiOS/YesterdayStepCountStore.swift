import Foundation
import HealthKit

@MainActor
final class YesterdayStepCountStore: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(yesterday: Int?, dayBeforeYesterday: Int?)
        case unavailable
    }

    @Published private(set) var state: State = .idle

    private let healthStore: HKHealthStore
    private let calendar: Calendar
    private var loadedStartOfToday: Date?

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    func refresh() {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            state = .unavailable
            return
        }

        state = .loading
        loadedStartOfToday = nil

        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [stepType])
                let now = Date()
                let yesterdayStepCount = try? await stepCount(
                    for: stepType,
                    daysBeforeToday: 1,
                    now: now
                )
                let dayBeforeYesterdayStepCount = try? await stepCount(
                    for: stepType,
                    daysBeforeToday: 2,
                    now: now
                )
                loadedStartOfToday = calendar.startOfDay(for: now)
                state = .loaded(
                    yesterday: yesterdayStepCount,
                    dayBeforeYesterday: dayBeforeYesterdayStepCount
                )
            } catch {
                loadedStartOfToday = nil
                state = .unavailable
            }
        }
    }

    func currentYesterdayStepCount(at referenceDate: Date = Date()) -> Int? {
        guard case .loaded(let stepCount, _) = state,
              loadedStartOfToday == calendar.startOfDay(for: referenceDate) else {
            return nil
        }
        return stepCount
    }

    func currentDayBeforeYesterdayStepCount(at referenceDate: Date = Date()) -> Int? {
        guard case .loaded(_, let stepCount) = state,
              loadedStartOfToday == calendar.startOfDay(for: referenceDate) else {
            return nil
        }
        return stepCount
    }

    private func stepCount(
        for stepType: HKQuantityType,
        daysBeforeToday: Int,
        now: Date
    ) async throws -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        guard let intervalStart = calendar.date(
            byAdding: .day,
            value: -daysBeforeToday,
            to: startOfToday
        ), let intervalEnd = calendar.date(
            byAdding: .day,
            value: -(daysBeforeToday - 1),
            to: startOfToday
        ) else {
            throw StepCountError.invalidDateRange
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: intervalStart,
            end: intervalEnd,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let total = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: max(0, Int(total.rounded())))
            }

            healthStore.execute(query)
        }
    }
}

private enum StepCountError: Error {
    case invalidDateRange
}
