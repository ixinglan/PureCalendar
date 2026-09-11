import Foundation

/// 节日/纪念日类型，用于决定展示优先级与配色。
enum HolidayKind: Int, Comparable {
    case statutory = 0    // 法定节假日
    case traditional = 1  // 传统节日
    case solarTerm = 2    // 二十四节气
    case solarFestival = 3 // 公历节日
    case foreign = 4      // 西方节日

    static func < (lhs: HolidayKind, rhs: HolidayKind) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 一个节日条目。
struct Holiday: Hashable {
    let name: String
    let kind: HolidayKind
}

/// 节日数据源：公历节日 + 农历节日 + 节气 + 法定节假日标记。
///
/// 说明：法定节假日的「放假/调休安排」由国务院每年公布，V1 仅标记节日性质（是否为法定节假日），
/// 不展示具体调休，避免使用过时数据。后续可接入年度更新的远程数据。
enum HolidayProvider {

    /// 公历固定节日：(月, 日) → (名称, 类型)。
    private static let solarFixed: [String: (String, HolidayKind)] = [
        "1-1": ("元旦", .statutory),
        "2-14": ("情人节", .foreign),
        "3-8": ("妇女节", .solarFestival),
        "3-12": ("植树节", .solarFestival),
        "4-1": ("愚人节", .foreign),
        "5-1": ("劳动节", .statutory),
        "5-4": ("青年节", .solarFestival),
        "6-1": ("儿童节", .solarFestival),
        "7-1": ("建党节", .solarFestival),
        "8-1": ("建军节", .solarFestival),
        "9-10": ("教师节", .solarFestival),
        "10-1": ("国庆节", .statutory),
        "12-24": ("平安夜", .foreign),
        "12-25": ("圣诞节", .foreign),
    ]

    /// 农历固定节日：(月, 日) → (名称, 类型)。闰月不计。
    private static let lunarFixed: [String: (String, HolidayKind)] = [
        "1-1": ("春节", .statutory),
        "1-15": ("元宵节", .traditional),
        "2-2": ("龙抬头", .traditional),
        "5-5": ("端午节", .statutory),
        "7-7": ("七夕", .traditional),
        "7-15": ("中元节", .traditional),
        "8-15": ("中秋节", .statutory),
        "9-9": ("重阳节", .traditional),
        "12-8": ("腊八节", .traditional),
        "12-23": ("小年", .traditional),
    ]

    /// 计算某天命中的所有节日（按重要度排序：法定 > 传统 > 节气 > 公历 > 西方）。
    static func holidays(solar: SolarDate, lunar: LunarDate) -> [Holiday] {
        var result: [Holiday] = []

        // 1) 公历固定节日
        if let item = solarFixed["\(solar.month)-\(solar.day)"] {
            result.append(Holiday(name: item.0, kind: item.1))
        }

        // 2) 农历固定节日（闰月不算节日）
        if !lunar.isLeap {
            if let item = lunarFixed["\(lunar.month)-\(lunar.day)"] {
                result.append(Holiday(name: item.0, kind: item.1))
            }
            // 除夕：腊月最后一天
            if lunar.month == 12, lunar.day == LunarCalendar.lunarMonthDays(lunar.year, 12) {
                result.append(Holiday(name: "除夕", kind: .traditional))
            }
        }

        // 3) 节气（清明同时是法定节假日）
        if let term = lunar.term {
            let isQingMing = (term == "清明")
            result.append(Holiday(name: term, kind: isQingMing ? .statutory : .solarTerm))
        }

        // 去重 + 排序
        var seen = Set<String>()
        return result
            .filter { seen.insert($0.name).inserted }
            .sorted { $0.kind < $1.kind }
    }

    /// 是否为法定节假日（用于判断是否显示红色/放假标记）。
    static func isStatutory(_ holiday: Holiday) -> Bool { holiday.kind == .statutory }
}

/// 星座计算。
enum Constellation {
    /// (结束日, 星座名) —— 按公历月日判断。
    private static let boundaries: [(month: Int, day: Int, name: String)] = [
        (1, 19, "摩羯座"), (2, 18, "水瓶座"), (3, 20, "双鱼座"), (4, 19, "白羊座"),
        (5, 20, "金牛座"), (6, 21, "双子座"), (7, 22, "巨蟹座"), (8, 22, "狮子座"),
        (9, 22, "处女座"), (10, 23, "天秤座"), (11, 22, "天蝎座"), (12, 21, "射手座"),
    ]

    static func of(_ solar: SolarDate) -> String {
        for b in boundaries where (solar.month, solar.day) <= (b.month, b.day) {
            return b.name
        }
        return "摩羯座" // 12/22 之后
    }
}
