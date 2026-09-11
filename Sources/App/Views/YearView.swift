import SwiftUI

/// 年视图：一屏纵览 12 个月，点任意月份即可跳转。
///
/// 设计参考 Apple 日历与中华万年历的年视图：不追求「可读每一天」，而是提供
/// **一眼看清全年节奏**的能力（哪个月假期多、哪个周末被调休占用）。
struct YearView: View {
    let year: Int
    /// 今天（用于高亮）。
    let today: SolarDate
    /// 当前选中的日期（用于标出所属月份）。
    let selectedDate: SolarDate
    var weekStartsOnMonday: Bool = false
    /// 点击某个月份的回调（参数为月份 1…12）。
    var onSelectMonth: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var yearModel: CalendarYear {
        CalendarYear.make(year: year, weekStartsOnMonday: weekStartsOnMonday)
    }

    /// 今天是哪一年——只有在同一年才画高亮圈。
    private var highlightDate: SolarDate? {
        today.year == year ? today : nil
    }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(yearModel.months) { month in
                    monthCard(month)
                }
            }
            legend
        }
    }

    // MARK: - 单个月份卡片

    private func monthCard(_ month: MonthGrid) -> some View {
        let isSelectedMonth = month.month == selectedDate.month && year == selectedDate.year
        let isCurrentMonth = today.year == year && today.month == month.month

        return Button {
            onSelectMonth(month.month)
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("\(month.month) 月")
                        .scaledFont(12, weight: .bold, design: .rounded)
                        .foregroundStyle(isCurrentMonth ? Palette.accent : Color.primary)
                    Spacer(minLength: 0)
                }
                MiniMonthGrid(
                    grid: month,
                    highlight: highlightDate,
                    numberSize: 9,
                    rowSpacing: 2,
                    weekStartsOnMonday: weekStartsOnMonday
                )
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelectedMonth ? Palette.accentSoft : Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelectedMonth ? Palette.accent.opacity(0.7) : Palette.separator.opacity(0.5),
                            lineWidth: isSelectedMonth ? 1.4 : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(month.month) 月")
        .accessibilityHint("跳转到 \(year) 年 \(month.month) 月")
    }

    // MARK: - 图例

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Palette.accent, text: "节日 / 放假")
            legendItem(color: Palette.workday, text: "调休上班")
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .scaledFont(11, weight: .medium, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
        }
    }
}
