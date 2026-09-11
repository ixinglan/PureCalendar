import Foundation

/// 农历日期及其派生的干支、生肖、节气信息。
struct LunarDate: Hashable {
    let year: Int          // 农历年（如 2026）
    let month: Int         // 农历月 1…12
    let day: Int           // 农历日 1…30
    let isLeap: Bool       // 是否闰月

    let yearChinese: String    // 二〇二六
    let monthChinese: String   // 六月 / 闰六月
    let dayChinese: String     // 初一
    let ganZhiYear: String     // 干支年，如 丙午
    let ganZhiMonth: String    // 干支月
    let ganZhiDay: String      // 干支日
    let zodiac: String         // 生肖，如 马
    let term: String?          // 当日节气（若不是节气日则为 nil）

    /// 完整农历描述，如「农历丙午年六月十九」。
    var fullDescription: String {
        "农历\(ganZhiYear)年\(monthChinese)\(dayChinese)"
    }
}

/// 农历核心计算引擎。
///
/// 采用中文农历界通用的「1900–2100 查表算法」：
/// - `LunarData.lunarInfo` 编码每年的闰月与每月大小（29/30 天）；
/// - `LunarData.termInfo` 编码每年的二十四节气日期。
///
/// 该算法与数据被广泛验证，覆盖 1900-01-31 ~ 2100-12-31。
enum LunarCalendar {

    // MARK: - 底层查表

    /// 农历某年的总天数。
    static func lunarYearDays(_ year: Int) -> Int {
        guard year >= 1900, year <= 2100 else { return 0 }
        let info = LunarData.lunarInfo[year - 1900]
        var sum = 348 // 12 个月 × 29 天
        var bit = 0x8000
        while bit > 0x8 {
            if info & bit != 0 { sum += 1 }
            bit >>= 1
        }
        return sum + leapDays(year)
    }

    /// 农历某年闰月的月份，无闰月返回 0。
    static func leapMonth(_ year: Int) -> Int {
        guard year >= 1900, year <= 2100 else { return 0 }
        return LunarData.lunarInfo[year - 1900] & 0xF
    }

    /// 农历某年闰月的天数（无闰月返回 0）。
    static func leapDays(_ year: Int) -> Int {
        guard leapMonth(year) != 0 else { return 0 }
        return (LunarData.lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29
    }

    /// 农历某年某月（非闰月）的天数。
    static func lunarMonthDays(_ year: Int, _ month: Int) -> Int {
        guard year >= 1900, year <= 2100, (1...12).contains(month) else { return -1 }
        return (LunarData.lunarInfo[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29
    }

    // MARK: - 节气

    /// 公历 `year` 年第 `n` 个节气（n 从 1 起，1=小寒…24=冬至）所在的日。
    static func termDay(_ year: Int, _ n: Int) -> Int {
        guard year >= 1900, year <= 2100, (1...24).contains(n) else { return -1 }
        let table = Array(LunarData.termInfo[year - 1900])
        var days: [Int] = []
        for chunk in 0..<6 {
            let start = chunk * 5
            guard start + 5 <= table.count else { return -1 }
            let hex = String(table[start..<(start + 5)])
            guard let value = UInt32(hex, radix: 16) else { return -1 }
            var digits = Array(String(value))          // 十进制字符串
            while digits.count < 6 { digits.insert("0", at: 0) } // 兜底补齐到 6 位
            days.append(Int(String(digits[0..<1])) ?? 0)
            days.append(Int(String(digits[1..<3])) ?? 0)
            days.append(Int(String(digits[3..<4])) ?? 0)
            days.append(Int(String(digits[4..<6])) ?? 0)
        }
        return days[n - 1]
    }

    /// 某公历日对应的节气名（若不是节气日返回 nil）。同时给出该节气在一年中的序号。
    static func solarTerm(on solar: SolarDate) -> (name: String, index: Int)? {
        guard solar.year >= 1900, solar.year <= 2100 else { return nil }
        let first = solar.month * 2 - 1   // 本月「节」
        let second = solar.month * 2      // 本月「气」
        if termDay(solar.year, first) == solar.day {
            return (LunarData.terms[first - 1], first)
        }
        if termDay(solar.year, second) == solar.day {
            return (LunarData.terms[second - 1], second)
        }
        return nil
    }

    // MARK: - 干支

    /// 天干地支（60 甲子）循环。
    static func ganZhi(_ offset: Int) -> String {
        let gan = LunarData.gan[((offset % 10) + 10) % 10]
        let zhi = LunarData.zhi[((offset % 12) + 12) % 12]
        return gan + zhi
    }

    // MARK: - 公历 → 农历

    /// 公历转农历（含干支、生肖、节气）。
    static func lunar(from solar: SolarDate) -> LunarDate? {
        let y = solar.year, m = solar.month, d = solar.day
        guard y >= 1900, y <= 2100 else { return nil }
        if y == 1900 && m == 1 && d < 31 { return nil }
        let maxDay = DayMath.daysInMonth(y, m)
        guard (1...12).contains(m), d >= 1, d <= maxDay else { return nil }

        // 与 1900-01-31（农历 1900 年正月初一）相差的天数
        var offset = DayMath.daysFromCivil(y, m, d) - DayMath.daysFromCivil(1900, 1, 31)

        // 1) 定位农历年
        var i = 1900
        var temp = 0
        while i < 2101 && offset > 0 {
            temp = lunarYearDays(i)
            offset -= temp
            i += 1
        }
        if offset < 0 { offset += temp; i -= 1 }
        let lunarYear = i

        // 2) 定位农历月 / 日
        let leap = leapMonth(lunarYear)
        var isLeap = false
        i = 1
        while i < 13 && offset > 0 {
            if leap > 0 && i == leap + 1 && !isLeap {
                i -= 1
                isLeap = true
                temp = leapDays(lunarYear)
            } else {
                temp = lunarMonthDays(lunarYear, i)
            }
            if isLeap && i == leap + 1 { isLeap = false }
            offset -= temp
            i += 1
        }
        if offset == 0 && leap > 0 && i == leap + 1 {
            if isLeap { isLeap = false } else { isLeap = true; i -= 1 }
        }
        if offset < 0 { offset += temp; i -= 1 }
        let lunarMonth = i
        let lunarDay = offset + 1

        // 3) 干支
        // 年柱：采用「农历年」口径（正月初一换年），与生肖保持一致，符合主流消费级日历 App 的展示惯例。
        // （严格干支纪年应以「立春」换年，此处为产品一致性与大众习惯做了取舍。）
        let gzYear = ganZhi(lunarYear - 4)
        // 月柱：以「节」为界（立春、惊蛰…），这是传统历法通行的月柱规则。
        let firstNode = termDay(y, m * 2 - 1)
        var gzMonth = ganZhi((y - 1900) * 12 + m + 11)
        if d >= firstNode {
            gzMonth = ganZhi((y - 1900) * 12 + m + 12)
        }
        // 日柱：以 1970-01-01 为参照的天数 + 固定偏移
        let gzDay = ganZhi(DayMath.daysFromCivil(y, m, d) + 25577)

        // 4) 生肖（按农历年，与年柱一致）
        let zodiac = LunarData.animals[(((lunarYear - 4) % 12) + 12) % 12]

        // 5) 节气
        let term = solarTerm(on: solar)?.name

        return LunarDate(
            year: lunarYear,
            month: lunarMonth,
            day: lunarDay,
            isLeap: isLeap,
            yearChinese: chineseYear(lunarYear),
            monthChinese: (isLeap ? "闰" : "") + chineseMonth(lunarMonth),
            dayChinese: chineseDay(lunarDay),
            ganZhiYear: gzYear,
            ganZhiMonth: gzMonth,
            ganZhiDay: gzDay,
            zodiac: zodiac,
            term: term
        )
    }

    // MARK: - 农历 → 公历

    static func solar(fromLunar year: Int, month: Int, day: Int, isLeapMonth: Bool = false) -> SolarDate? {
        guard year >= 1900, year <= 2100 else { return nil }
        let leap = leapMonth(year)
        if isLeapMonth && leap != month { return nil }
        if (year == 2100 && month == 12 && day > 1) || (year == 1900 && month == 1 && day < 31) { return nil }
        let mDays = isLeapMonth ? leapDays(year) : lunarMonthDays(year, month)
        guard day >= 1, day <= mDays else { return nil }

        var offset = 0
        var y = 1900
        while y < year { offset += lunarYearDays(y); y += 1 }

        var isAdded = false
        var m = 1
        while m < month {
            if !isAdded && leap > 0 && leap <= m {
                offset += leapDays(year)
                isAdded = true
            }
            offset += lunarMonthDays(year, m)
            m += 1
        }
        if isLeapMonth { offset += mDays }

        // 1900 年正月一日 = 1900-01-31
        let base = DayMath.daysFromCivil(1900, 1, 31)
        return DayMath.civilFromDays(base + offset + day - 1)
    }

    // MARK: - 中文格式化

    /// 农历年 → 「二〇二六」。
    static func chineseYear(_ y: Int) -> String {
        let digits = LunarData.nStr4
        return "\(digits[(y / 1000) % 10])\(digits[(y / 100) % 10])\(digits[(y / 10) % 10])\(digits[y % 10])"
    }

    /// 农历月 → 「正月」「腊月」…
    static func chineseMonth(_ m: Int) -> String {
        guard (1...12).contains(m) else { return "" }
        return LunarData.nStr3[m - 1] + "月"
    }

    /// 农历日 → 「初一」「十五」「廿三」…
    static func chineseDay(_ d: Int) -> String {
        switch d {
        case 10: return "初十"
        case 20: return "二十"
        case 30: return "三十"
        default:
            let prefix = LunarData.nStr2[d / 10]
            let unit = LunarData.nStr1[d % 10]
            return prefix + unit
        }
    }
}
