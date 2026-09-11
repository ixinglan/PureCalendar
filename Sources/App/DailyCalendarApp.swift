import SwiftUI

/// App 入口。
@main
struct DailyCalendarApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(nil) // 跟随系统浅色/深色
        }
    }
}
