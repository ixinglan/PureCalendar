import SwiftUI

/// 迷你月历网格（供小组件与年视图共用）。
///
/// 只画「日期数字 + 节日标记点」，不画农历小字，因此在很窄的宽度下（约 90pt）也能清晰显示。
///
/// 两种尺寸模式：
/// - **内容决定高度**（默认，`fillHeight == nil`）：字号由 `numberSize` 给定，行高 = 字号 + `cellPadding` + 圆点。
///   适合年视图、中尺寸组件这类「高度由内容说了算」的场景。
/// - **撑满给定高度**（`fillHeight != nil`）：字号由「可用高度 ÷ 行数」**反推**，
///   使整个网格恰好铺满给定高度。适合大尺寸组件——画布是固定的 4×4，
///   内容必须把画布填满才不显空，而且系统字体放大时网格会自动缩小让位，**永远不会溢出被裁**
///   （小组件不能滚动，溢出就是内容丢失）。
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
    /// 给定总高度时，自动把行高与字号撑满该高度（见类型注释）。
    var fillHeight: CGFloat? = nil

    /// 字号倍率只读一次，避免 42 个格子各建一个环境依赖。
    @Environment(\.fontScale) private var fontScale

    private var rows: [[CalendarCell]] {
        stride(from: 0, to: grid.cells.count, by: 7)
            .map { Array(grid.cells[$0..<min($0 + 7, grid.cells.count)]) }
    }

    private var weekdayNames: [String] {
        weekStartsOnMonday ? ["一", "二", "三", "四", "五", "六", "日"] : ["日", "一", "二", "三", "四", "五", "六"]
    }

    /// 系统字体行高相对字号的经验系数（`.system(size: s)` 的行高约为 1.2s）。
    private static let lineHeightFactor: CGFloat = 1.2

    /// 表头文字相对日期字号的比列。
    private static let headerRatio: CGFloat = 0.78

    /// 实际生效的日期字号。
    ///
    /// - 未指定 `fillHeight`：就是 `numberSize × 倍率`（原行为）。
    /// - 指定了 `fillHeight`：由高度反推，并夹在合理区间内。
    private var resolvedNumberSize: CGFloat {
        guard let fillHeight, !rows.isEmpty else { return numberSize * fontScale }

        let rowCount = CGFloat(rows.count)
        // 表头自己占一行（高度 ≈ 表头字号 × 行高系数）。
        let headerFactor = showWeekHeader ? Self.headerRatio * Self.lineHeightFactor : 0
        // 行与行（含表头）之间的总间距。
        let gapCount = rowCount + (showWeekHeader ? 1 : 0) - 1
        let spacingTotal = gapCount * rowSpacing * fontScale
        // 每行除字号外还固定占用「内边距 + 圆点」。
        let extraPerRow = (cellPadding + dotSize) * fontScale

        // 解方程：size × headerFactor + rowCount × (size + extraPerRow) + spacingTotal = fillHeight
        let denominator = headerFactor + rowCount
        let size = (fillHeight - spacingTotal - rowCount * extraPerRow) / denominator

        // 下限保证可读；上限避免极端比例下数字大得离谱。
        return min(max(size, 6), numberSize * 2.6)
    }

    var body: some View {
        VStack(spacing: rowSpacing * fontScale) {
            if showWeekHeader {
                HStack(spacing: 0) {
                    ForEach(Array(weekdayNames.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(.system(size: max(6, resolvedNumberSize * Self.headerRatio),
                                          weight: .semibold, design: .rounded))
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
                        cellView(cell, size: resolvedNumberSize)
                    }
                }
            }
        }
    }

    private func isWeekendColumn(_ index: Int) -> Bool {
        weekStartsOnMonday ? (index >= 5) : (index == 0 || index == 6)
    }

    private func cellView(_ cell: CalendarCell, size: CGFloat) -> some View {
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
