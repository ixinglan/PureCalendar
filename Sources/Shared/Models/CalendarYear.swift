import Foundation

/// 年视图数据模型：某一年 12 个月的月历网格。
///
/// 与 `MonthGrid` 一样，`title` 使用**纯 String 拼接**，避免 SwiftUI 的
/// `LocalizedStringKey` 把年份格式化成「2,026」；UI 层请用 `Text(verbatim:)` 渲染。
struct CalendarYear: Identifiable {
    let year: Int
    /// 12 个月，索引 0 对应 1 月。
    let months: [MonthGrid]

    var id: Int { year }

    /// 标题，如「2026 年」。
    var title: String { "\(year) 年" }

    /// 该年的干支 + 生肖（按农历年口径，与全局一致）。
    ///
    /// 这里刻意**不**去构建 12 个月网格，而是直接算该年 7 月 1 日所属的农历年——
    /// 7 月必然晚于春节（最晚 2 月下旬），因此能稳定取到该公历年对应的农历年。
    var ganZhiZodiac: String? {
        CalendarYear.ganZhiZodiac(of: year)
    }

    /// 轻量计算：某公历年对应的干支年与生肖。
    static func ganZhiZodiac(of year: Int) -> String? {
        guard let lunar = LunarCalendar.lunar(from: SolarDate(year: year, month: 7, day: 1)) else { return nil }
        return "\(lunar.ganZhiYear)年 · 属\(lunar.zodiac)"
    }

    // MARK: - 缓存

    private static let cacheLock = NSLock()
    private static var cache: [String: CalendarYear] = [:]

    /// 生成某年的 12 个月网格。
    ///
    /// 一次生成要计算 12 × 42 = 504 天的完整信息，代价不低；而年视图在父视图每次
    /// 重绘时都会重新求值，所以这里按「年份 + 每周起始」做一层缓存，避免重复计算。
    static func make(year: Int, weekStartsOnMonday: Bool = false) -> CalendarYear {
        let key = "\(year)-\(weekStartsOnMonday)"
        cacheLock.lock()
        if let hit = cache[key] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()

        let months = (1...12).map {
            MonthGrid.make(year: year, month: $0, weekStartsOnMonday: weekStartsOnMonday)
        }
        let result = CalendarYear(year: year, months: months)

        cacheLock.lock()
        if cache.count > 24 { cache.removeAll() }   // 简单上限，避免无界增长
        cache[key] = result
        cacheLock.unlock()
        return result
    }
}
