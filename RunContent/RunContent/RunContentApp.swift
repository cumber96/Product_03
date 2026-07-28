import SwiftUI

@main
struct RunContentApp: App {
    @StateObject private var connectivityManager =
        ConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
