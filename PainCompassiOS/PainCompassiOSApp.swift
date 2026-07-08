import SwiftUI

@main
struct PainCompassiOSApp: App {
    @StateObject private var store = DiaryRecordStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
