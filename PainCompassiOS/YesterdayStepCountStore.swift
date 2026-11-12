import Foundation
import HealthKit

@MainActor
final class YesterdayStepCountStore: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(Int)
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
                let stepCount = try await yesterdayStepCount(for: stepType, now: now)
                loadedStartOfToday = calendar.startOfDay(for: now)
                state = .loaded(stepCount)
            } catch {
                loadedStartOfToday = nil
                state = .unavailable
            }
        }
    }

    func currentYesterdayStepCount(at referenceDate: Date = Date()) -> Int? {
        guard case .loaded(let stepCount) = state,
              loadedStartOfToday == calendar.startOfDay(for: referenceDate) else {
            return nil
        }
        return stepCount
    }

    private func yesterdayStepCount(
        for stepType: HKQuantityType,
        now: Date
    ) async throws -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            throw StepCountError.invalidDateRange
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday,
            end: startOfToday,
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
