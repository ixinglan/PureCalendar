import SwiftUI

/// 迷你月历网格（供小组件与年视图共用）。
///
/// 只画「日期数字 + 节日标记点」，不画农历小字，因此在很窄的宽度下（约 90pt）也能清晰显示。
struct MiniMonthGrid: View {
    let grid: MonthGrid
    /// 需要高亮（用主色圆底突出）的日期；为 nil 或不在本网格内则不画。
    var highlight: SolarDate?
    var showWeekHeader: Bool = true
    var numberSize: CGFloat = 11
    var rowSpacing: CGFloat = 2
    /// 日期数字行在字号之外额外占用的高度（越小越紧凑）。
    /// 中尺寸组件纵向空间紧张时调小该值，年视图保持默认即可。
    var cellPadding: CGFloat = 7
    /// 日期下方「节日/节气标记点」的直径；设为 0 可彻底不占高度。
    var dotSize: CGFloat = 3
    /// 周一为每周第一天（与主视图设置保持一致）。
    var weekStartsOnMonday: Bool = false

    /// 字号倍率只读一次，避免 42 个格子各建一个环境依赖。
    @Environment(\.fontScale) private var fontScale

    private var rows: [[CalendarCell]] {
        stride(from: 0, to: grid.cells.count, by: 7)
            .map { Array(grid.cells[$0..<min($0 + 7, grid.cells.count)]) }
    }

    private var weekdayNames: [String] {
        weekStartsOnMonday ? ["一", "二", "三", "四", "五", "六", "日"] : ["日", "一", "二", "三", "四", "五", "六"]
    }

    /// 按字号倍率放大后的日期字号（所有尺寸都按同一倍率缩放，保证比例不变）。
    private var scaledNumberSize: CGFloat { numberSize * fontScale }

    var body: some View {
        VStack(spacing: rowSpacing * fontScale) {
            if showWeekHeader {
                HStack(spacing: 0) {
                    ForEach(Array(weekdayNames.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(.system(size: max(6, scaledNumberSize * 0.78), weight: .semibold, design: .rounded))
                            .foregroundStyle(isWeekendColumn(index)
                                             ? Palette.accent.opacity(0.7)
                                             : Palette.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(row) { cell in
                        cellView(cell)
                    }
                }
            }
        }
    }

    private func isWeekendColumn(_ index: Int) -> Bool {
        weekStartsOnMonday ? (index >= 5) : (index == 0 || index == 6)
    }

    private func cellView(_ cell: CalendarCell) -> some View {
        let size = scaledNumberSize
        let isHighlighted = highlight != nil && cell.info.solar == highlight
        return VStack(spacing: 0) {
            ZStack {
                if isHighlighted {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: size + 6, height: size + 6)
                }
                Text(verbatim: "\(cell.info.solar.day)")
                    .font(.system(size: size, weight: isHighlighted ? .bold : .medium, design: .rounded))
                    .foregroundStyle(numberColor(cell, isHighlighted: isHighlighted))
                    .monospacedDigit()
            }
            .frame(height: size + cellPadding * fontScale)

            Circle()
                .fill(dotColor(cell))
                .frame(width: dotSize * fontScale, height: dotSize * fontScale)
                .opacity(cell.inCurrentMonth ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func numberColor(_ cell: CalendarCell, isHighlighted: Bool) -> Color {
        if isHighlighted { return .white }
        if !cell.inCurrentMonth { return Palette.secondaryText.opacity(0.4) }
        if cell.info.dayOff == .workday { return Palette.workday }
        if cell.info.isRestDay { return Palette.accent }
        return .primary
    }

    private func dotColor(_ cell: CalendarCell) -> Color {
        if cell.info.dayOff == .workday { return Palette.workday }
        if !cell.info.holidays.isEmpty || cell.info.lunar.term != nil { return Palette.accent }
        return .clear
    }
}
