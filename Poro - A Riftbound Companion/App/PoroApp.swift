import SwiftUI
import FirebaseCore

@main
struct PoroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authService: AuthService

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authService: authService)
        }
    }
}
