import SwiftUI
import KeyboardExtensionUtils

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            if DevAppIdentity.sharedContainerURL != nil {
                MainAppContent()
            } else {
                ContentUnavailableView(
                    "azooKey Dev: 共有領域がありません",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("本体とKeyboard.appexの署名・App Groupsを確認してください。正規版の設定変更は不要です。詳細はREADMEの切り分け手順を参照してください。")
                )
            }
        }
    }
}

private struct MainAppContent: View {
    @StateObject private var router = AppRouter()
    @StateObject private var keyboardConfiguration = KeyboardConfigurationState()
    @StateObject private var onboarding = OnboardingState()
    @StateObject private var reviewPrompt = RequestReviewManager()
    @StateObject private var customizationWalkthrough = CustomizationWalkthroughState()

    var body: some View {
        AppRootView()
                .environmentObject(router)
                .environmentObject(keyboardConfiguration)
                .environmentObject(onboarding)
                .environmentObject(reviewPrompt)
                .environmentObject(customizationWalkthrough)
                .onAppear {
                    AppLaunchTasks.performInitialSetup()
                }
    }
}
