import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isServerRunning {
                DisplayView()
            } else {
                HostSetupView()
            }
        }
        .animation(.easeInOut, value: model.isServerRunning)
    }
}
