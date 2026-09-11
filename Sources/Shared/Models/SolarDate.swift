import Foundation

/// 公历日期（年月日），本项目内部统一用它做日期运算，避免时区带来的误差。
struct SolarDate: Hashable, Comparable, Codable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// 从系统 Date 构造（使用当前日历/时区）。
    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 1
        self.month = c.month ?? 1
        self.day = c.day ?? 1
    }

    /// 今天。
    static var today: SolarDate { SolarDate(date: Date()) }

    /// 转成 Date（当天 0 点，使用当前时区）。
    func toDate(calendar: Calendar = .current) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return calendar.date(from: c) ?? Date()
    }

    /// 星期几：1 = 周日，2 = 周一 … 7 = 周六（与 Foundation 一致）。
    var weekday: Int {
        Weekday.weekday(of: self)
    }

    /// 中文星期，如「星期三」。
    var weekdayChinese: String {
        let names = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        return names[(weekday - 1 + 7) % 7]
    }

    /// 星期简称，如「周三」。
    var weekdayShort: String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return "周" + names[(weekday - 1 + 7) % 7]
    }

    /// 自 1970-01-01 起的天数（Howard Hinnant 的 days_from_civil 算法，纯整数、跨时区稳定）。
    var epochDays: Int { DayMath.daysFromCivil(year, month, day) }

    func adding(days: Int) -> SolarDate {
        DayMath.civilFromDays(epochDays + days)
    }

    static func < (lhs: SolarDate, rhs: SolarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// 星期计算工具。
enum Weekday {
    /// 返回 1(周日)…7(周六)，与 Foundation `Calendar.component(.weekday)` 一致。
    /// 基于 1970-01-01 是星期四这一事实推算。
    static func weekday(of date: SolarDate) -> Int {
        // Foundation 中：周日=1 … 周四=5 … 周六=7。1970-01-01 是周四 → 基准 5。
        // epochDays 可能为负，用 ((x % 7) + 7) % 7 保证非负。
        let base = 5
        let offset = ((date.epochDays % 7) + 7) % 7
        let w = ((base - 1 + offset) % 7) + 1
        return w
    }
}

/// 公历日期 ↔ 天数的互转（纯整数算法，无时区依赖）。
enum DayMath {
    /// 自 1970-01-01 起的天数。
    static func daysFromCivil(_ y: Int, _ m: Int, _ d: Int) -> Int {
        var y = y
        y -= (m <= 2) ? 1 : 0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400                                   // [0, 399]
        let mp = (m + 9) % 12                                     // [0, 11]
        let doy = (153 * mp + 2) / 5 + d - 1                      // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy           // [0, 146096]
        return era * 146097 + doe - 719468
    }

    /// 天数转公历日期。
    static func civilFromDays(_ z: Int) -> SolarDate {
        var z = z
        z += 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097                                // [0, 146096]
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)         // [0, 365]
        let mp = (5 * doy + 2) / 153                              // [0, 11]
        let d = doy - (153 * mp + 2) / 5 + 1                      // [1, 31]
        let m = mp < 10 ? mp + 3 : mp - 9                         // [1, 12]
        return SolarDate(year: y + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    /// 某年某月的天数。
    static func daysInMonth(_ y: Int, _ m: Int) -> Int {
        switch m {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(y) ? 29 : 28
        default: return 30
        }
    }

    static func isLeapYear(_ y: Int) -> Bool {
        (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
    }
}
