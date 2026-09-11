import SwiftUI

/// 单个日期格子。
struct DayCell: View {
    let cell: CalendarCell
    let isSelected: Bool
    let onTap: () -> Void

    private var info: DayInfo { cell.info }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(verbatim: "\(info.solar.day)")
                    .scaledFont(17, weight: numberWeight, design: .rounded)
                    .foregroundStyle(numberColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(cell.inCurrentMonth ? info.cellSubtitle : " ")
                    .scaledFont(9.5, weight: .medium, design: .rounded)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(cell.inCurrentMonth ? 1 : 0.32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 样式

    private var numberWeight: Font.Weight {
        if isSelected || info.isToday { return .bold }
        return .medium
    }

    /// 日期数字颜色：今天 / 放假 → 主色；调休上班 → 琥珀橙；其余正常。
    ///
    /// 注意：**普通周末不标红**，只有「放假 / 法定节日」才用主色，
    /// 避免整屏标红失去信息量；调休上班（周末却要上班）单独用橙色提示，最容易被漏看。
    private var numberColor: Color {
        if isSelected { return .white }
        if info.isToday { return Palette.accent }
        if info.dayOff == .workday { return Palette.workday }
        if info.isStatutoryHoliday || info.dayOff == .holiday { return Palette.accent }
        return .primary
    }

    private var subtitleColor: Color {
        if isSelected { return Color.white.opacity(0.9) }
        switch info.cellSubtitleTone {
        case .accent: return Palette.accent
        case .adjustedWorkday: return Palette.workday
        case .normal: return Palette.secondaryText
        }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Palette.accent)
        } else if info.isToday {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Palette.accentSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Palette.accent.opacity(0.6), lineWidth: 1.2)
                )
        } else {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.clear)
        }
    }

    /// VoiceOver 朗读文案：把格子里「看得到但读不出来」的信息补全。
    private var accessibilityLabel: String {
        var parts: [String] = ["\(info.solar.year) 年 \(info.solar.month) 月 \(info.solar.day) 日"]
        parts.append(info.solar.weekdayChinese)
        if info.isToday { parts.append("今天") }
        parts.append("农历\(info.lunar.monthChinese)\(info.lunar.dayChinese)")
        if let holiday = info.primaryHoliday { parts.append(holiday.name) }
        if let term = info.lunar.term, info.primaryHoliday?.name != term { parts.append(term) }
        if let badge = info.dayOffBadge {
            parts.append(badge == "休" ? "放假" : "调休上班")
        }
        return parts.joined(separator: "，")
    }
}

/// 月历网格：星期表头 + 6×7 日期。
struct MonthGridView: View {
    let grid: MonthGrid
    @Binding var selectedDate: SolarDate
    var weekStartsOnMonday: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var weekdays: [String] {
        weekStartsOnMonday
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    var body: some View {
        VStack(spacing: 8) {
            // 星期表头
            HStack(spacing: 4) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .scaledFont(12, weight: .semibold, design: .rounded)
                        .foregroundStyle(isWeekendColumn(index) ? Palette.accent.opacity(0.75) : Palette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            // 日期网格
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(grid.cells) { cell in
                    DayCell(
                        cell: cell,
                        isSelected: cell.info.solar == selectedDate,
                        onTap: { select(cell) }
                    )
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Palette.separator.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: Palette.shadow, radius: 14, x: 0, y: 8)
    }

    private func isWeekendColumn(_ index: Int) -> Bool {
        weekStartsOnMonday ? (index >= 5) : (index == 0 || index == 6)
    }

    private func select(_ cell: CalendarCell) {
        withAnimation(.snappy(duration: 0.22)) {
            selectedDate = cell.info.solar
        }
    }
}
