import SwiftUI

@main
struct JukeboxGuestApp: App {
    @StateObject private var client = GuestAPIClient()

    var body: some Scene {
        WindowGroup {
            GuestRootView()
                .environmentObject(client)
                .preferredColorScheme(.dark)
        }
    }
}
