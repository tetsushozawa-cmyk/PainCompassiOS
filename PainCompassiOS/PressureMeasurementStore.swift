import CoreMotion
import Foundation

struct PressureMeasurement: Equatable, Hashable {
    let hectopascals: Double
    let measuredAt: Date
}

struct PressureHistoryEntry: Codable, Equatable {
    let hectopascals: Double
    let measuredAt: Date
}

@MainActor
final class PressureMeasurementStore: ObservableObject {
    enum State: Equatable {
        case idle
        case measuring
        case unavailable
        case failed
    }

    @Published private(set) var latestMeasurement: PressureMeasurement?
    @Published private(set) var state: State = .idle
    @Published private(set) var history: [PressureHistoryEntry] = []

    private let altimeter = CMAltimeter()
    private let historyKey = "barometric_pressure_history_json"
    private let measurementFreshnessInterval: TimeInterval = 60
    private var isMeasuring = false

    var latestPressureChange: PressureChangeCalculationResult {
        guard let latestMeasurement else {
            return .comparisonDataUnavailable
        }

        return PressureChangeCalculator.calculate(
            current: PressureDataPoint(
                hectopascals: latestMeasurement.hectopascals,
                measuredAt: latestMeasurement.measuredAt
            ),
            history: history.map {
                PressureDataPoint(
                    hectopascals: $0.hectopascals,
                    measuredAt: $0.measuredAt
                )
            }
        )
    }

    init() {
        loadHistory()
    }

    func currentMeasurement(at referenceDate: Date = Date()) -> PressureMeasurement? {
        guard isMeasuring,
              state == .measuring,
              let latestMeasurement else {
            return nil
        }

        let age = referenceDate.timeIntervalSince(latestMeasurement.measuredAt)
        guard age >= 0, age <= measurementFreshnessInterval else {
            return nil
        }
        return latestMeasurement
    }

    func startMeasuring() {
        guard !isMeasuring else { return }
        latestMeasurement = nil

        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            state = .unavailable
            return
        }

        isMeasuring = true
        state = .measuring

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }

            if error != nil {
                self.state = .failed
                self.latestMeasurement = nil
                self.altimeter.stopRelativeAltitudeUpdates()
                self.isMeasuring = false
                return
            }

            guard let pressure = data?.pressure.doubleValue else { return }
            let measurement = PressureMeasurement(
                hectopascals: pressure * 10,
                measuredAt: Date()
            )
            self.latestMeasurement = measurement
        }
    }

    func stopMeasuring() {
        guard isMeasuring else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isMeasuring = false
        latestMeasurement = nil

        if state == .measuring {
            state = .idle
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decodedHistory = try? JSONDecoder().decode([PressureHistoryEntry].self, from: data) else {
            history = []
            return
        }

        history = decodedHistory.sorted { $0.measuredAt < $1.measuredAt }
    }
}
