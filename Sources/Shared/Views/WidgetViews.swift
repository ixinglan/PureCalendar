import SwiftUI

// 说明：
// - 迷你月历网格 `MiniMonthGrid` 已抽取到 `Sources/Shared/Views/MiniMonthGrid.swift`，
//   以便主 App 的年视图与小组件共用同一份实现。
// - 所有字号统一走 `scaledFont(...)`，让组件也能随系统「动态字体」缩放
//   （倍率由 `TodayWidgetEntryView` 顶层的 `providesFontScale()` 注入一次）。
// - 展示公历年的文字一律用 `Text(verbatim:)`，避免被格式化成「2,026」。

// MARK: - 小尺寸

struct SmallWidgetView: View {
    let info: DayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 年 + 月 + 星期
            HStack(spacing: 4) {
                Text(verbatim: "\(info.solar.year) 年 \(info.solar.month) 月")
                    .scaledFont(12, weight: .semibold, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Text(info.solar.weekdayShort)
                    .scaledFont(12, weight: .semibold, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
            }

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(info.solar.day)")
                    .scaledFont(44, weight: .bold, design: .rounded)
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.lunar.dayChinese)
                        .scaledFont(13, weight: .semibold, design: .rounded)
                    Text(info.lunar.monthChinese)
                        .scaledFont(10, weight: .medium, design: .rounded)
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
                .scaledFont(9, weight: .bold, design: .rounded)
                .foregroundStyle(color)
            Text(value ?? "—")
                .scaledFont(11, weight: .medium, design: .rounded)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                // 年 + 月
                Text(verbatim: "\(info.solar.year) 年 \(info.solar.month) 月")
                    .scaledFont(11, weight: .semibold, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(info.solar.day)")
                        .scaledFont(32, weight: .bold, design: .rounded)
                        .foregroundStyle(Palette.accent)
                        .monospacedDigit()
                    Text(info.solar.weekdayShort)
                        .scaledFont(13, weight: .semibold, design: .rounded)
                        .foregroundStyle(.primary)
                }

                Text(info.lunar.fullDescription)
                    .scaledFont(12, weight: .semibold, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

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

            VStack(spacing: 2) {
                Text(verbatim: "\(grid.month) 月")
                    .scaledFont(10, weight: .bold, design: .rounded)
                    .foregroundStyle(Palette.accent)
                // 中尺寸纵向空间紧张：用更小的字号 + 更紧的行高，确保 6 行月历完整落在卡片内。
                MiniMonthGrid(grid: grid, highlight: info.solar,
                              numberSize: 10, rowSpacing: 1.5,
                              cellPadding: 3, dotSize: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func compactPair(_ label: String, _ items: ArraySlice<String>, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .scaledFont(9, weight: .bold, design: .rounded)
                .foregroundStyle(color)
            Text(items.joined(separator: " "))
                .scaledFont(10.5, weight: .medium, design: .rounded)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

// MARK: - 大尺寸

/// 大尺寸（4×4）组件。
///
/// 尺寸设计要点：4×4 的画布（约 364×382pt）比中尺寸大得多，
/// 因此**不能沿用中/小尺寸的字号**，否则内容只占上半屏、看着很空很小。
/// 这里做两件事：
/// 1. 整块文字字号上调（标题 20、农历 17、宜忌 14/15）；
/// 2. 月历交给 `MiniMonthGrid` 的 `fillHeight` **自动撑满剩余高度**——
///    字号由可用高度反推，所以画布被填满，且系统字体放大时网格会自动缩小让位，
///    永远不会溢出被裁（小组件不能滚动，溢出即内容丢失）。
struct LargeWidgetView: View {
    let info: DayInfo
    let grid: MonthGrid

    /// 字号倍率（由小组件顶层注入）。预留高度必须同步放大，否则高度预算会算错。
    @Environment(\.fontScale) private var fontScale

    /// 顶部标题行预留高度（标题 20pt 的行高）。
    private let headerHeight: CGFloat = 25
    /// 底部信息区（农历全称 + 宜忌）预留高度。
    private let footerHeight: CGFloat = 92
    /// 主纵向间距。
    private let vSpacing: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            // 高度预算：总高 − 标题行 − 分隔线 − 底部信息区 − 各段间距（都随倍率放大）。
            // 刻意「少给一点」给月历：宁可底部留几 pt 空白，也不要内容溢出被裁。
            let reserved = (headerHeight + footerHeight + 1 + vSpacing * 3) * fontScale
            let gridHeight = max(60, geo.size.height - reserved)

            VStack(alignment: .leading, spacing: vSpacing * fontScale) {
                header

                MiniMonthGrid(grid: grid, highlight: info.solar,
                              numberSize: 16, rowSpacing: 4,
                              cellPadding: 6, dotSize: 3,
                              fillHeight: gridHeight)

                Divider().overlay(Palette.separator)

                footer

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // grid.title 形如「2026 年 9 月」（纯 String 拼接，无千分位问题）
            Text(verbatim: grid.title)
                .scaledFont(20, weight: .bold, design: .rounded)
            Spacer()
            Text(verbatim: "今天 \(info.solar.day) 日 · \(info.lunar.dayChinese)")
                .scaledFont(13, weight: .medium, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(info.lunar.fullDescription)
                    .scaledFont(17, weight: .semibold, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                if let holiday = info.primaryHoliday {
                    Text(holiday.name)
                        .scaledFont(14, weight: .semibold, design: .rounded)
                        .foregroundStyle(holiday.kind == .statutory ? Palette.accent : Palette.secondaryText)
                }
                Text("\(info.almanac.zhiXing)日 · \(info.almanac.luckText)")
                    .scaledFont(14, weight: .medium, design: .rounded)
                    .foregroundStyle(info.almanac.isAuspiciousDay ? Palette.yi : Palette.secondaryText)
            }

            HStack(alignment: .top, spacing: 12) {
                yiJiBlock("宜", info.almanac.yi.prefix(4), Palette.yi)
                yiJiBlock("忌", info.almanac.ji.prefix(4), Palette.ji)
            }
        }
    }

    private func yiJiBlock(_ label: String, _ items: ArraySlice<String>, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .scaledFont(14, weight: .bold, design: .rounded)
                    .foregroundStyle(color)
            }
            Text(items.joined(separator: " · "))
                .scaledFont(15, weight: .medium, design: .rounded)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 锁屏（配件）尺寸

/// 锁屏矩形组件。
///
/// 说明：锁屏组件只显示**今天**，且可用宽度极小（约 160pt / 3 行），
/// 因此这里刻意**不显示年份**——展示 4 位年份会挤掉更该被看到的农历日与节日名。
/// 需要年份请用主屏的小 / 中 / 大组件。
struct AccessoryRectangularView: View {
    let info: DayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(verbatim: "\(info.solar.month)/\(info.solar.day)")
                    .scaledFont(13, weight: .bold, design: .rounded)
                Text(info.lunar.dayChinese)
                    .scaledFont(12, weight: .medium, design: .rounded)
                if let holiday = info.primaryHoliday {
                    Text(holiday.name)
                        .scaledFont(12, weight: .semibold, design: .rounded)
                }
            }
            Text("宜 \(info.almanac.yi.prefix(3).joined(separator: " "))")
                .scaledFont(11, design: .rounded)
                .lineLimit(1)
            Text("忌 \(info.almanac.ji.prefix(3).joined(separator: " "))")
                .scaledFont(11, design: .rounded)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineView: View {
    let info: DayInfo
    var body: some View {
        // 行内组件只能用系统字体，无法自定义字号。
        Text("\(info.lunar.dayChinese) · 宜\(info.almanac.yi.first ?? "—") 忌\(info.almanac.ji.first ?? "—")")
    }
}
