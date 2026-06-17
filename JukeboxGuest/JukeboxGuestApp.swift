import SwiftUI

@main
struct JukeboxGuestApp: App {
    @StateObject private var client = GuestAPIClient()

    var body: some Scene {
        WindowGroup {
            GuestRootView()
                .environmentObject(client)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "jukeboxguest" {
            return
        }
        if url.scheme == "http" || url.scheme == "https" {
            Task { await client.connectToHost(url.absoluteString) }
        }
    }
}
