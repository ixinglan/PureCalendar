import SwiftUI

/// 迷你月历网格（供小组件使用）。
struct MiniMonthGrid: View {
    let grid: MonthGrid
    let highlight: SolarDate
    var showWeekHeader: Bool = true
    var numberSize: CGFloat = 11
    var rowSpacing: CGFloat = 2

    private var rows: [[CalendarCell]] {
        stride(from: 0, to: grid.cells.count, by: 7).map { Array(grid.cells[$0..<min($0 + 7, grid.cells.count)]) }
    }

    private let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: rowSpacing) {
            if showWeekHeader {
                HStack(spacing: 0) {
                    ForEach(weekdayNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: numberSize * 0.78, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.secondaryText)
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

    private func cellView(_ cell: CalendarCell) -> some View {
        let isToday = cell.info.solar == highlight
        return VStack(spacing: 0) {
            ZStack {
                if isToday {
                    Circle().fill(Palette.accent).frame(width: numberSize + 6, height: numberSize + 6)
                }
                Text("\(cell.info.solar.day)")
                    .font(.system(size: numberSize, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isToday ? Color.white : (cell.inCurrentMonth ? Color.primary : Palette.secondaryText.opacity(0.4)))
                    .monospacedDigit()
            }
            .frame(height: numberSize + 7)

            Circle()
                .fill(cell.info.holidays.isEmpty && cell.info.lunar.term == nil ? Color.clear : Palette.accent)
                .frame(width: 3, height: 3)
                .opacity(cell.inCurrentMonth ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 小尺寸

struct SmallWidgetView: View {
    let info: DayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(info.solar.month) 月")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.secondaryText)
                Spacer()
                Text(info.solar.weekdayShort)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.secondaryText)
            }

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(info.solar.day)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.lunar.dayChinese)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text("\(info.lunar.monthChinese)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            Spacer(minLength: 2)

            if let holiday = info.primaryHoliday {
                TagChip(text: holiday.name,
                        color: holiday.kind == .statutory ? Palette.accent : Palette.secondaryText,
                        filled: holiday.kind == .statutory)
            } else {
                HStack(spacing: 6) {
                    yiJiMini("宜", info.almanac.yi.first, Palette.yi)
                    yiJiMini("忌", info.almanac.ji.first, Palette.ji)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func yiJiMini(_ label: String, _ value: String?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(value ?? "—")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - 中尺寸

struct MediumWidgetView: View {
    let info: DayInfo
    let grid: MonthGrid

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("今天是")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(info.solar.day)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                        .monospacedDigit()
                    Text(info.solar.weekdayShort)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text(info.lunar.fullDescription)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let holiday = info.primaryHoliday {
                    TagChip(text: holiday.name,
                            color: holiday.kind == .statutory ? Palette.accent : Palette.secondaryText,
                            filled: holiday.kind == .statutory)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    compactPair("宜", info.almanac.yi.prefix(2), Palette.yi)
                    compactPair("忌", info.almanac.ji.prefix(2), Palette.ji)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MiniMonthGrid(grid: grid, highlight: info.solar, numberSize: 10.5)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func compactPair(_ label: String, _ items: ArraySlice<String>, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(items.joined(separator: " "))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

// MARK: - 大尺寸

struct LargeWidgetView: View {
    let info: DayInfo
    let grid: MonthGrid

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: grid.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text("今天 \(info.solar.day) 日 · \(info.lunar.dayChinese)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondaryText)
            }

            MiniMonthGrid(grid: grid, highlight: info.solar, numberSize: 12.5, rowSpacing: 4)

            Divider().overlay(Palette.separator)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(info.lunar.fullDescription)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text("\(info.almanac.zhiXing)日 · \(info.almanac.luckText)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(info.almanac.isAuspiciousDay ? Palette.yi : Palette.secondaryText)
                }

                HStack(alignment: .top, spacing: 10) {
                    yiJiBlock("宜", info.almanac.yi.prefix(4), Palette.yi)
                    yiJiBlock("忌", info.almanac.ji.prefix(4), Palette.ji)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func yiJiBlock(_ label: String, _ items: ArraySlice<String>, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(items.joined(separator: " · "))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 锁屏（配件）尺寸

struct AccessoryRectangularView: View {
    let info: DayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text("\(info.solar.month)/\(info.solar.day)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(info.lunar.dayChinese)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                if let holiday = info.primaryHoliday {
                    Text(holiday.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            Text("宜 \(info.almanac.yi.prefix(3).joined(separator: " "))")
                .font(.system(size: 11, design: .rounded))
                .lineLimit(1)
            Text("忌 \(info.almanac.ji.prefix(3).joined(separator: " "))")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineView: View {
    let info: DayInfo
    var body: some View {
        Text("\(info.lunar.dayChinese) · 宜\(info.almanac.yi.first ?? "—") 忌\(info.almanac.ji.first ?? "—")")
    }
}
