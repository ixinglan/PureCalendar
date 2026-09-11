import SwiftUI
import UIKit

/// 组件样式预览：在 App 内按**真实尺寸**渲染桌面小组件，免去「先加到主屏才能看效果」的来回折腾。
///
/// 尺寸说明：小组件的点值随设备逻辑宽度分档。iPhone 17 / 16 Pro 这类 **402pt 宽**机型是
/// 170 / 364 / 364×382；393pt 宽机型（iPhone 15/16 标准版）是 158 / 338 / 338×354。
/// 这里按 `UIScreen` 宽度自动选择，避免用错档位把溢出问题放大或掩盖。
struct WidgetPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    private let info: DayInfo?
    private let grid: MonthGrid
    private let metrics: Metrics

    /// 各档小组件的真实点值。
    struct Metrics {
        let small: CGSize
        let medium: CGSize
        let large: CGSize

        /// 依设备逻辑宽度选取对应档位。
        static func current() -> Metrics {
            let w = UIScreen.main.bounds.width
            if w >= 400 {
                // 402pt 档（iPhone 17 / 16 Pro / 17 Pro）
                return Metrics(small: CGSize(width: 170, height: 170),
                               medium: CGSize(width: 364, height: 170),
                               large: CGSize(width: 364, height: 382))
            } else {
                // 393pt 档（iPhone 15 / 16 标准版）
                return Metrics(small: CGSize(width: 158, height: 158),
                               medium: CGSize(width: 338, height: 158),
                               large: CGSize(width: 338, height: 354))
            }
        }
    }

    init() {
        let today = SolarDate.today
        self.info = DayInfo.make(solar: today)
        self.grid = MonthGrid.make(year: today.year, month: today.month, weekStartsOnMonday: false)
        self.metrics = Metrics.current()
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        header

                    if let info {
                        // 注意：每张卡片都要**单独**注入小组件自己的字号倍率。
                        // 预览是 App 里的一层视图，默认会继承 App 的字号倍率（含「大字体模式」的
                        // 附加倍率），而真实小组件并不叠加它——不注入就会看到一个比真机更大、
                        // 且会随 App 开关变化的假象。
                        previewCard("小尺寸 · 2×2", size: metrics.small) {
                            SmallWidgetView(info: info).emulatingWidgetFontScale(extra: textScale)
                        }
                        previewCard("中尺寸 · 4×2", size: metrics.medium) {
                            MediumWidgetView(info: info, grid: grid).emulatingWidgetFontScale(extra: textScale)
                        }
                        previewCard("大尺寸 · 4×4", size: metrics.large) {
                            LargeWidgetView(info: info, grid: grid).emulatingWidgetFontScale(extra: textScale)
                        }
                        // 大尺寸组件在手机屏上会被截断，给个 id 方便直接滚过去核对。
                        .id(Self.largeAnchor)
                    } else {
                            Text("无法生成今日数据")
                                .scaledFont(14, design: .rounded)
                                .foregroundStyle(Palette.secondaryText)
                        }

                        note
                    }
                    .padding(16)
                }
                #if DEBUG
                .onAppear {
                    // 调试用：`-widgetPreviewFocusLarge` 直接滚到大尺寸组件，便于逐块核对不留死角。
                    guard ProcessInfo.processInfo.arguments.contains("-widgetPreviewFocusLarge") else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        proxy.scrollTo(Self.largeAnchor, anchor: .top)
                    }
                }
                #endif
            }
        }
    }

    /// 大尺寸预览卡片的滚动锚点 id。
    private static let largeAnchor = "widget.preview.large"

    /// 与真实小组件一致的字号倍率上限（见 `TodayWidgetEntryView`）。
    /// 小组件画布固定且不可滚动，倍率超过这个值内容就会被裁。
    static let widgetMaxScale: CGFloat = 1.3

    /// 预览时模拟的字号倍率。
    ///
    /// 默认 1（等同系统标准字号）。Debug 下可用启动参数压测：
    /// `-widgetTextScale 1.3` 直接看「系统字体放到最大」时组件会不会溢出。
    private var textScale: CGFloat {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-widgetTextScale"), i + 1 < args.count,
           let value = Double(args[i + 1]) {
            return CGFloat(value)
        }
        #endif
        return 1
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("组件样式预览")
                    .scaledFont(22, weight: .bold, design: .rounded)
                Text("以下为今日数据的真实渲染效果")
                    .scaledFont(12, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("完成")
                    .scaledFont(15, weight: .semibold, design: .rounded)
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 2)
    }

    private func previewCard<Content: View>(
        _ title: String,
        size: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .scaledFont(12, weight: .bold, design: .rounded)
                .foregroundStyle(Palette.secondaryText)

            // 先给内容加 16pt 内边距（等价于系统小组件的默认边距），再固定成组件真实尺寸；
            // 最后 clipShape 裁掉溢出部分——这样「内容放不下」会像真机一样被看见，而不是画到卡片外面。
            content()
                .padding(16)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.background)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.separator.opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: Palette.shadow, radius: 10, x: 0, y: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关于锁屏组件")
                .scaledFont(13, weight: .bold, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
            Text("锁屏矩形 / 行内组件只显示**今天**，且可用宽度极小，因此刻意不显示年份——4 位年份会挤掉更该被看到的农历日与节日名。需要年 / 月请用小、中、大三种主屏组件。")
                .scaledFont(12, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}

private extension View {
    /// 让预览中的组件使用**与真实小组件完全一致**的字号倍率规则：
    /// 不叠加 App 内「大字体模式」的附加倍率，并受 `widgetMaxScale` 上限约束。
    func emulatingWidgetFontScale(extra: CGFloat) -> some View {
        providesFontScale(extra: extra, maxScale: WidgetPreviewView.widgetMaxScale)
    }
}
