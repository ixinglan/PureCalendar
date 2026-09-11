import Foundation

/// 月历小字（`cellSubtitle`）的语义色调，由视图层映射成具体颜色。
enum SubtitleTone {
    /// 节日 / 节气 / 放假——用主色高亮。
    case accent
    /// 调休上班——用警示色，提醒「这天要上班」。
    case adjustedWorkday
    /// 普通农历日。
    case normal
}

/// 一天的完整信息：公历 + 农历 + 黄历 + 节日 + 星座 + 年度放假安排。
/// 这是 UI 层唯一需要的数据模型，所有页面与小组件都基于它渲染。
struct DayInfo: Identifiable, Hashable {
    let solar: SolarDate
    let lunar: LunarDate
    let almanac: AlmanacInfo
    let holidays: [Holiday]
    let constellation: String
    /// 该日在国务院年度安排中的状态（休 / 班）；无该年度数据时为 nil。
    let dayOff: DayOffKind?

    var id: Int { solar.epochDays }

    var isToday: Bool { solar == SolarDate.today }

    /// 首选的展示节日（已按重要度排序）。
    var primaryHoliday: Holiday? { holidays.first }

    /// 是否为法定节假日（仅表示「节日性质」）。
    var isStatutoryHoliday: Bool {
        holidays.contains { $0.kind == .statutory }
    }

    var isWeekend: Bool { solar.weekday == 1 || solar.weekday == 7 }

    /// 是否休息日（用于日期数字标红）。
    ///
    /// 规则：**有年度安排以安排为准**（调休上班的周六不算休息日，放假的工作日算），
    /// 没有当年数据时退回「周末或法定节日」的推断，保证不会因为缺数据而显示错误。
    var isRestDay: Bool {
        if let dayOff { return dayOff == .holiday }
        return isWeekend || isStatutoryHoliday
    }

    /// 休 / 班角标文字；无安排时为 nil。
    var dayOffBadge: String? { dayOff?.badge }

    /// 月历格子里显示的小字：优先节日 → 节气 → 放假安排 → 农历日。
    ///
    /// 把「休 / 班」放在农历日之前，是因为它对用户当天安排的影响更大
    /// （尤其「班」——周末却要上班，最容易漏看）。
    var cellSubtitle: String {
        if let h = primaryHoliday { return h.name }
        if let term = lunar.term { return term }
        if let badge = dayOffBadge { return badge }
        if lunar.day == 1 { return lunar.monthChinese }   // 初一显示月份
        return lunar.dayChinese
    }

    /// 小字的色调。
    var cellSubtitleTone: SubtitleTone {
        if primaryHoliday != nil || lunar.term != nil { return .accent }
        switch dayOff {
        case .workday: return .adjustedWorkday
        case .holiday: return .accent
        case nil: return .normal
        }
    }

    /// 组装某天的完整信息。
    static func make(solar: SolarDate) -> DayInfo? {
        guard let lunar = LunarCalendar.lunar(from: solar) else { return nil }
        return DayInfo(
            solar: solar,
            lunar: lunar,
            almanac: Almanac.info(for: lunar),
            holidays: HolidayProvider.holidays(solar: solar, lunar: lunar),
            constellation: Constellation.of(solar),
            dayOff: HolidayStore.kind(for: solar)
        )
    }
}
