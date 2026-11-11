import SwiftUI

@main
struct PainCompassiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = DiaryRecordStore()
    @StateObject private var pressureStore = PressureMeasurementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(pressureStore)
                .preferredColorScheme(.light)
                .onAppear {
                    if scenePhase == .active {
                        pressureStore.startMeasuring()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        pressureStore.startMeasuring()
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
