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
                Text("\(info.solar.day)")
                    .font(.system(size: 17, weight: numberWeight, design: .rounded))
                    .foregroundStyle(numberColor)
                    .monospacedDigit()

                Text(cell.inCurrentMonth ? info.cellSubtitle : " ")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(cell.inCurrentMonth ? 1 : 0.32)
    }

    private var numberWeight: Font.Weight {
        if isSelected || info.isToday { return .bold }
        return .medium
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if info.isStatutoryHoliday { return Palette.accent }
        if info.isToday { return Palette.accent }
        return .primary
    }

    private var subtitleColor: Color {
        if isSelected { return Color.white.opacity(0.85) }
        if info.cellSubtitleIsAccent { return Palette.accent }
        return Palette.secondaryText
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
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isWeekendColumn(index) ? Palette.accent.opacity(0.75) : Palette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

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
