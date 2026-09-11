import SwiftUI

/// 自动换行的流式布局（用于宜忌标签）。
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && currentWidth > 0 {
                currentHeight += rowHeight + spacing
                currentWidth = 0
                rowHeight = 0
            }
            currentWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        currentHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? currentWidth : maxWidth, height: currentHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// 当日详情面板：农历黄历、宜忌、冲煞、值日、彭祖百忌、历史上的今天。
struct DayDetailView: View {
    let info: DayInfo
    var showAlmanac: Bool = true

    /// 该日的史料条目（无收录时为空）。
    private var historyEvents: [HistoryEvent] { HistoryToday.events(on: info.solar) }

    var body: some View {
        VStack(spacing: 14) {
            heroCard
            if showAlmanac {
                yiJiCard
                directionsCard
                dutyCard
            }
            if !historyEvents.isEmpty {
                HistoryTodayView(solar: info.solar, events: historyEvents)
            }
        }
    }

    // MARK: - 头部信息卡

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: "\(info.solar.day)")
                    .scaledFont(46, weight: .bold, design: .rounded)
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(info.solar.month) 月")
                        .scaledFont(15, weight: .semibold, design: .rounded)
                        .foregroundStyle(Palette.secondaryText)
                    Text(info.solar.weekdayChinese)
                        .scaledFont(15, weight: .semibold, design: .rounded)
                        .foregroundStyle(.primary)
                }
                Spacer()
                if let badge = info.dayOffBadge {
                    dayOffChip(badge)
                }
                Text(info.constellation)
                    .scaledFont(12, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Palette.separator.opacity(0.5)))
            }

            Text(info.lunar.fullDescription)
                .scaledFont(17, weight: .semibold, design: .rounded)
                .foregroundStyle(.primary)

            FlowLayout(spacing: 6) {
                infoChip("\(info.lunar.ganZhiYear)年")
                infoChip("\(info.lunar.ganZhiMonth)月")
                infoChip("\(info.lunar.ganZhiDay)日")
                infoChip("属\(info.lunar.zodiac)")
            }

            if !info.holidays.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(info.holidays, id: \.name) { holiday in
                        TagChip(text: holiday.name,
                                color: holiday.kind == .statutory ? Palette.accent : Palette.secondaryText,
                                filled: holiday.kind == .statutory)
                    }
                }
            }
        }
        .card()
        .accessibilityElement(children: .contain)
    }

    /// 「休 / 班」角标：放假用主色，调休上班用琥珀橙。
    private func dayOffChip(_ badge: String) -> some View {
        let isHoliday = info.dayOff == .holiday
        let color = isHoliday ? Palette.accent : Palette.workday
        return Text(badge)
            .scaledFont(12, weight: .bold, design: .rounded)
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
            .accessibilityLabel(isHoliday ? "放假" : "调休上班")
    }

    private func infoChip(_ text: String) -> some View {
        Text(text)
            .scaledFont(12, weight: .medium, design: .rounded)
            .foregroundStyle(Palette.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.separator.opacity(0.45)))
    }

    // MARK: - 宜 / 忌

    private var yiJiCard: some View {
        HStack(alignment: .top, spacing: 16) {
            yiJiColumn(title: "宜", items: info.almanac.yi, color: Palette.yi)
            Rectangle()
                .fill(Palette.separator)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
            yiJiColumn(title: "忌", items: info.almanac.ji, color: Palette.ji)
        }
        .card()
    }

    private func yiJiColumn(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .scaledFont(15, weight: .bold, design: .rounded)
                    .foregroundStyle(color)
            }
            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .scaledFont(13, weight: .medium, design: .rounded)
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.12)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 冲煞 / 方位

    private var directionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("冲煞 · 方位")
            HStack(spacing: 0) {
                directionItem("冲", info.almanac.chong)
                directionItem("煞", info.almanac.sha)
                directionItem("喜神", info.almanac.xiShen)
                directionItem("财神", info.almanac.caiShen)
                directionItem("福神", info.almanac.fuShen)
            }
        }
        .card()
    }

    private func directionItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .scaledFont(11, weight: .medium, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
            Text(value)
                .scaledFont(12.5, weight: .semibold, design: .rounded)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(value)")
    }

    // MARK: - 值日

    private var dutyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("值日")
            HStack(spacing: 10) {
                dutyBadge("\(info.almanac.zhiXing)日", color: Palette.accent)
                dutyBadge(info.almanac.tianShen, color: Palette.secondaryText)
                Text(info.almanac.luckText)
                    .scaledFont(12.5, weight: .semibold, design: .rounded)
                    .foregroundStyle(info.almanac.isAuspiciousDay ? Palette.yi : Palette.secondaryText)
                Spacer(minLength: 0)
            }
            Text("彭祖百忌：\(info.almanac.pengZu)")
                .scaledFont(12.5, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func dutyBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .scaledFont(13, weight: .semibold, design: .rounded)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.12)))
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .scaledFont(13, weight: .bold, design: .rounded)
            .foregroundStyle(Palette.secondaryText)
    }
}
