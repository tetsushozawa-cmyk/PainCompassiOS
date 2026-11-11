import CoreMotion
import Foundation

struct PressureMeasurement: Equatable, Hashable {
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

    private let altimeter = CMAltimeter()
    private var isMeasuring = false

    func startMeasuring() {
        guard !isMeasuring else { return }

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
                return
            }

            guard let pressure = data?.pressure.doubleValue else { return }
            self.latestMeasurement = PressureMeasurement(
                hectopascals: pressure * 10,
                measuredAt: Date()
            )
        }
    }

    func stopMeasuring() {
        guard isMeasuring else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isMeasuring = false

        if state == .measuring {
            state = .idle
        }
    }
}
