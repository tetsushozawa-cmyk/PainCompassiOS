import SwiftUI

@main
struct PainCompassiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = DiaryRecordStore()
    @StateObject private var pressureStore = PressureMeasurementStore()
    @StateObject private var stepCountStore = YesterdayStepCountStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(pressureStore)
                .environmentObject(stepCountStore)
                .preferredColorScheme(.light)
                .onAppear {
                    if scenePhase == .active {
                        pressureStore.startMeasuring()
                        stepCountStore.refresh()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        pressureStore.startMeasuring()
                        stepCountStore.refresh()
                    } else {
                        pressureStore.stopMeasuring()
                    }
                }
                .onDisappear {
                    pressureStore.stopMeasuring()
                }
        }
    }
}
