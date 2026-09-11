import SwiftUI

/// 单个日期格子。
///
/// 性能要点（勿改）：
/// 1. `scale` 由父视图**以参数传入**，格子内部不持有任何 `@ScaledMetric` / `@Environment`；
/// 2. 字号与行高都用 `.frame(height:)` **写死高度**，避免逐格测量内容固有尺寸；
/// 3. 用 `.onTapGesture` 而不是 `Button`——一个月 42 个 `Button` 会各自参与触摸/手势仲裁，
///    在 ScrollView 里会拖慢滚动的响应；
/// 4. 「非本月日期变淡」用**文字颜色带透明度**实现，而不是给整个格子加 `.opacity()`——
///    后者会让 42 个格子各自产生一个合成图层。
struct DayCell: View {
    let cell: CalendarCell
    let isSelected: Bool
    /// 全站字号倍率，由 `MonthGridView` 统一读取后传入。
    let scale: CGFloat
    let onTap: () -> Void

    private var info: DayInfo { cell.info }

    /// 格子固定高度（随字号倍率一起放大）。
    private var cellHeight: CGFloat { 46 * scale }

    /// 非本月日期的淡化系数（作用于颜色，而非整视图透明度）。
    private var dim: Double { cell.inCurrentMonth ? 1 : 0.32 }

    var body: some View {
        #if DEBUG
        let _: Void = { RenderCounter.dayCellBody += 1 }()
        #endif
        VStack(spacing: 1) {
            Text(verbatim: "\(info.solar.day)")
                .font(.system(size: 17 * scale, weight: numberWeight, design: .rounded))
                .foregroundStyle(numberColor.opacity(dim))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(cell.inCurrentMonth ? info.cellSubtitle : " ")
                .font(.system(size: 9.5 * scale, weight: .medium, design: .rounded))
                .foregroundStyle(subtitleColor.opacity(dim))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        // 用 onTapGesture 替代 Button 后，手动补回「按钮」语义，VoiceOver 体验不变。
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
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

    /// 选中 / 今天的底色。
    ///
    /// 其余日期返回 `Color.clear`：透明填充不需要真实绘制，代价可忽略，
    /// 省掉一层 `@ViewBuilder` 分支判断。
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
            Color.clear
        }
    }

    /// VoiceOver 朗读文案：把格子里「看得到但读不出来」的信息补全。
    private var accessibilityLabel: String {
        let solar = info.solar
        var text = "\(solar.year) 年 \(solar.month) 月 \(solar.day) 日，\(solar.weekdayChinese)"
        if info.isToday { text += "，今天" }
        text += "，农历\(info.lunar.monthChinese)\(info.lunar.dayChinese)"
        if let holiday = info.primaryHoliday { text += "，\(holiday.name)" }
        if let term = info.lunar.term, info.primaryHoliday?.name != term { text += "，\(term)" }
        if let badge = info.dayOffBadge { text += badge == "休" ? "，放假" : "，调休上班" }
        return text
    }
}

/// 月历网格：星期表头 + 6×7 日期。
///
/// 性能要点：这里**刻意不用 `LazyVGrid`**。一个月固定 42 格、且全部在屏幕内，
/// 惰性容器带来的是纯粹开销（惰性子视图管理 + 逐格测量）。
/// 改成「手工切行 + 固定行高」后布局退化成简单的算术，成本大幅下降。
struct MonthGridView: View {
    let grid: MonthGrid
    @Binding var selectedDate: SolarDate
    var weekStartsOnMonday: Bool

    /// 全站字号倍率。这里**读一次**并传给 42 个格子，避免每格各建一个环境依赖。
    @Environment(\.fontScale) private var fontScale

    /// 每行 7 个格子，按周切分。
    private var rows: [[CalendarCell]] {
        stride(from: 0, to: grid.cells.count, by: 7).map {
            Array(grid.cells[$0..<min($0 + 7, grid.cells.count)])
        }
    }

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
                        .font(.system(size: 12 * fontScale, weight: .semibold, design: .rounded))
                        .foregroundStyle(isWeekendColumn(index) ? Palette.accent.opacity(0.75) : Palette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            // 日期网格：手工切行，行与列都用固定间距，布局无需测量
            VStack(spacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(row) { cell in
                            DayCell(
                                cell: cell,
                                isSelected: cell.info.solar == selectedDate,
                                scale: fontScale,
                                onTap: { select(cell) }
                            )
                        }
                    }
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
        .shadow(color: Palette.shadow, radius: 10, x: 0, y: 5)
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
