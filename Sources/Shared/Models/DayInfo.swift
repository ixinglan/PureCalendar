import Foundation

/// 一天的完整信息：公历 + 农历 + 黄历 + 节日 + 星座。
/// 这是 UI 层唯一需要的数据模型，所有页面与小组件都基于它渲染。
struct DayInfo: Identifiable, Hashable {
    let solar: SolarDate
    let lunar: LunarDate
    let almanac: AlmanacInfo
    let holidays: [Holiday]
    let constellation: String

    var id: Int { solar.epochDays }

    var isToday: Bool { solar == SolarDate.today }

    /// 首选的展示节日（已按重要度排序）。
    var primaryHoliday: Holiday? { holidays.first }

    /// 月历格子里显示的小字：优先节日 → 节气 → 农历日。
    var cellSubtitle: String {
        if let h = primaryHoliday { return h.name }
        if let term = lunar.term { return term }
        if lunar.day == 1 { return lunar.monthChinese }   // 初一显示月份
        return lunar.dayChinese
    }

    /// 格子小字是否应高亮（节日/节气）。
    var cellSubtitleIsAccent: Bool {
        !holidays.isEmpty || lunar.term != nil
    }

    /// 是否法定节假日（用于红色标注）。
    var isStatutoryHoliday: Bool {
        holidays.contains { $0.kind == .statutory }
    }

    var isWeekend: Bool { solar.weekday == 1 || solar.weekday == 7 }

    /// 组装某天的完整信息。
    static func make(solar: SolarDate) -> DayInfo? {
        guard let lunar = LunarCalendar.lunar(from: solar) else { return nil }
        return DayInfo(
            solar: solar,
            lunar: lunar,
            almanac: Almanac.info(for: lunar),
            holidays: HolidayProvider.holidays(solar: solar, lunar: lunar),
            constellation: Constellation.of(solar)
        )
    }
}
