import Foundation

/// 月历网格中的一个格子。
struct CalendarCell: Identifiable {
    let id: Int
    let info: DayInfo
    let inCurrentMonth: Bool
}

/// 一个月的月历网格（固定 6 行 × 7 列 = 42 格，含前后月补位）。
struct MonthGrid: Identifiable {
    let year: Int
    let month: Int
    let cells: [CalendarCell]

    var id: String { "\(year)-\(month)" }

    /// 标题，如「2026 年 9 月」。
    var title: String { "\(year) 年 \(month) 月" }

    /// 该月第一天。
    var firstDay: SolarDate { SolarDate(year: year, month: month, day: 1) }

    /// 生成月历网格。
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 1…12
    ///   - weekStartsOnMonday: true 表示周一为每周第一天，默认 false（周日开始，符合多数中文日历习惯）
    static func make(year: Int, month: Int, weekStartsOnMonday: Bool = false) -> MonthGrid {
        let first = SolarDate(year: year, month: month, day: 1)
        let weekdayOfFirst = first.weekday                 // 1=周日 … 7=周六
        // 计算第一格需要向前补几天
        let leading: Int
        if weekStartsOnMonday {
            leading = (weekdayOfFirst - 2 + 7) % 7
        } else {
            leading = weekdayOfFirst - 1
        }

        let startDate = first.adding(days: -leading)
        var cells: [CalendarCell] = []
        cells.reserveCapacity(42)
        for i in 0..<42 {
            let solar = startDate.adding(days: i)
            guard let info = DayInfo.make(solar: solar) else { continue }
            cells.append(CalendarCell(id: i, info: info, inCurrentMonth: solar.month == month))
        }
        return MonthGrid(year: year, month: month, cells: cells)
    }

    /// 上一月 / 下一月的年月。
    func previous() -> (year: Int, month: Int) {
        month == 1 ? (year - 1, 12) : (year, month - 1)
    }
    func next() -> (year: Int, month: Int) {
        month == 12 ? (year + 1, 1) : (year, month + 1)
    }
}
