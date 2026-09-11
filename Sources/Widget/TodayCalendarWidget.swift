import WidgetKit
import SwiftUI

/// 小组件时间线条目。
struct CalendarEntry: TimelineEntry {
    let date: Date
    let info: DayInfo
    let grid: MonthGrid
}

/// 时间线提供者：每天 0 点自动刷新。
struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry { makeEntry(Date()) }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(makeEntry(Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(now)
        // 下一天 0 点后再刷新
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func makeEntry(_ date: Date) -> CalendarEntry {
        let solar = SolarDate(date: date)
        // 日期必然落在 1900–2100，兜底取今天。
        let info = DayInfo.make(solar: solar) ?? DayInfo.make(solar: SolarDate.today)!
        let grid = MonthGrid.make(year: solar.year, month: solar.month)
        return CalendarEntry(date: date, info: info, grid: grid)
    }
}

/// 依据组件尺寸选择对应布局。
struct TodayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalendarEntry

    var body: some View {
        content
            // 小组件同样需要字号倍率：在组件视图树顶层注入一次即可（勿重复调用）。
            .providesFontScale()
            .widgetURL(URL(string: "dailycalendar://day/\(entry.info.solar.year)-\(entry.info.solar.month)-\(entry.info.solar.day)"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(info: entry.info)
        case .systemMedium:
            MediumWidgetView(info: entry.info, grid: entry.grid)
        case .systemLarge:
            LargeWidgetView(info: entry.info, grid: entry.grid)
        #if os(iOS)
        case .accessoryRectangular:
            AccessoryRectangularView(info: entry.info)
        case .accessoryInline:
            AccessoryInlineView(info: entry.info)
        #endif
        default:
            SmallWidgetView(info: entry.info)
        }
    }
}

/// 今日黄历日历小组件。
struct TodayCalendarWidget: Widget {
    let kind = "TodayCalendarWidget"

    /// 支持的组件尺寸（锁屏配件尺寸仅 iOS 提供）。
    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline]
        #else
        return [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Palette.background
                }
        }
        .configurationDisplayName("今日黄历日历")
        .description("一眼查看今日农历、宜忌，以及当月月历。")
        .supportedFamilies(supportedFamilies)
    }
}
