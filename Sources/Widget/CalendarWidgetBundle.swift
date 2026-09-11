import WidgetKit
import SwiftUI

/// 小组件扩展入口。
@main
struct DailyCalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayCalendarWidget()
    }
}
