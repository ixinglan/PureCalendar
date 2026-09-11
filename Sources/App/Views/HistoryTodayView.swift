import SwiftUI

/// 「历史上的今天」卡片：列出所选日期在历史上发生过的、有公开记载的事件。
///
/// 数据缺失时**不显示本卡片**（而不是显示空态），避免在浏览普通日期时占据版面。
struct HistoryTodayView: View {
    let solar: SolarDate
    let events: [HistoryEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("历史上的今天")
                    .scaledFont(13, weight: .bold, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
                Spacer()
                Text("\(solar.month) 月 \(solar.day) 日 · \(events.count) 条")
                    .scaledFont(11, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.secondaryText.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Text(event.yearText)
                            .scaledFont(11.5, weight: .bold, design: .rounded)
                            .foregroundStyle(Palette.accent)
                            .monospacedDigit()
                            .frame(width: 56, alignment: .leading)
                            .padding(.top, 1)

                        Text(event.text)
                            .scaledFont(13, weight: .regular, design: .rounded)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(event.year) 年，\(event.text)")
                }
            }
        }
        .card()
    }
}
