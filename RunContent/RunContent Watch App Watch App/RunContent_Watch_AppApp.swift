import SwiftUI

@main
struct RunContent_Watch_App_Watch_AppApp: App {
    @StateObject private var connectivityManager =
        ConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
