import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isServerRunning {
                DisplayContainerView()
            } else {
                HostSetupView()
            }
        }
        .animation(.easeInOut, value: model.isServerRunning)
    }
}
