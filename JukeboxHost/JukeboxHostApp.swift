import SwiftUI

@main
struct JukeboxHostApp: App {
    init() {
        SecretsLoader.load()
    }

    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 1024, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}
