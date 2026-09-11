import SwiftUI

/// 设置页（以 sheet 呈现）。
struct SettingsView: View {
    /// 仅调试用：为 true 时进入设置页后自动弹出组件预览（由启动参数 `-showWidgetPreview` 触发）。
    var autoShowWidgetPreview: Bool = false

    @AppStorage("showAlmanac") private var showAlmanac = true
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false
    @AppStorage("largeFontMode") private var largeFontMode = false
    @Environment(\.dismiss) private var dismiss

    #if DEBUG
    /// 仅 Debug：首页右上角的实时帧率 HUD 开关。
    @AppStorage("showFPSHud") private var showFPSHud = false
    #endif

    // 节假日数据状态（本地缓存 + 远程更新）
    @State private var holidaySummary = HolidayStore.summary
    @State private var holidayStamp = HolidayStore.dataTimestamp
    @State private var holidayStatus: String?
    @State private var isUpdating = false
    @State private var hasCache = HolidayStore.hasCachedData
    @State private var showWidgetPreview = false

    private var remoteConfigured: Bool { HolidayStore.remoteURLString != nil }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    displaySection
                    accessibilitySection
                    holidaySection
                    widgetSection
                    aboutSection
                    #if DEBUG
                    developerSection
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .sensoryFeedback(.selection, trigger: largeFontMode)
        .onAppear {
            // 调试用：带 `-showWidgetPreview` 启动时直接展开预览，便于自动化截图。
            if autoShowWidgetPreview { showWidgetPreview = true }
            #if DEBUG
            // 调试用：`-autoCheckHolidayUpdate` 进入设置页后自动点一次「检查更新」。
            // 模拟器无法脚本化点击，靠它才能用截图核对「数据未发布时」的友好提示。
            if ProcessInfo.processInfo.arguments.contains("-autoCheckHolidayUpdate") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { checkHolidayUpdate() }
            }
            #endif
        }
        .sheet(isPresented: $showWidgetPreview) {
            WidgetPreviewView()
        }
    }

    private var header: some View {
        HStack {
            Text("设置")
                .scaledFont(26, weight: .bold, design: .rounded)
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

    // MARK: - 显示

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("显示")

            Toggle(isOn: $showAlmanac) {
                settingLabel(title: "显示黄历宜忌", detail: "关闭后仅显示公历、农历与节日")
            }
            .tint(Palette.accent)
            .accessibilityHint("开关黄历宜忌面板")

            Divider().overlay(Palette.separator)

            VStack(alignment: .leading, spacing: 8) {
                Text("每周起始")
                    .scaledFont(15, weight: .medium, design: .rounded)
                Picker("每周起始", selection: $weekStartsOnMonday) {
                    Text("周日").tag(false)
                    Text("周一").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
        .card()
    }

    // MARK: - 无障碍

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("无障碍")

            Toggle(isOn: $largeFontMode) {
                settingLabel(title: "大字体模式", detail: "在系统字体大小基础上再放大 18%")
            }
            .tint(Palette.accent)
            .accessibilityHint("开启后界面文字整体放大，适合视力不佳的用户")

            Text("本 App 的文字同时响应系统「设置 → 显示与亮度 → 文字大小」。若仍偏小，可再开启上方开关叠加放大。")
                .scaledFont(12, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - 节假日数据

    private var holidaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("节假日数据")

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(holidaySummary)
                        .scaledFont(15, weight: .medium, design: .rounded)
                    Text(holidayStamp.isEmpty ? "内置数据" : "数据日期 \(holidayStamp)")
                        .scaledFont(12, weight: .regular, design: .rounded)
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 8)
                updateButton
            }

            if let status = holidayStatus {
                Text(status)
                    .scaledFont(12, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // App Group 共享状态：用户据此判断桌面小组件能否同步到远程更新的安排。
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: HolidayStore.sharedContainerEnabled
                      ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .scaledFont(11, weight: .semibold)
                    .foregroundStyle(HolidayStore.sharedContainerEnabled ? Palette.yi : Palette.workday)
                Text(HolidayStore.sharedContainerEnabled
                     ? "已启用 App Group：桌面小组件可同步这里更新到的安排"
                     : "未启用 App Group：桌面小组件只使用内置数据（需配置开发者账号的 App Groups 能力）")
                    .scaledFont(11, weight: .regular, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasCache {
                Button {
                    HolidayStore.clearCache()
                    hasCache = HolidayStore.hasCachedData
                    holidaySummary = HolidayStore.summary
                    holidayStamp = HolidayStore.dataTimestamp
                    holidayStatus = "已恢复为 App 内置数据"
                } label: {
                    Text("恢复内置数据")
                        .scaledFont(13, weight: .semibold, design: .rounded)
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
            }

            Text("放假与调休安排由国务院办公厅逐年公布。App 采用「内置基线 + 远程更新」机制：数据地址已预置，官方公布次年安排、服务器发布数据后点「检查更新」即可获取，无需重新安装 App。若尚未发布或暂时连不上，会继续使用内置数据并给出提示，不会影响正常使用。")
                .scaledFont(12, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var updateButton: some View {
        Button(action: checkHolidayUpdate) {
            HStack(spacing: 5) {
                if isUpdating {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(isUpdating ? "检查中" : "检查更新")
                    .scaledFont(13, weight: .semibold, design: .rounded)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(remoteConfigured ? Palette.accent : Palette.secondaryText.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
        .accessibilityHint(remoteConfigured
                           ? "从服务器获取最新放假安排；若尚未发布会继续使用内置数据"
                           : "尚未配置远程数据地址")
    }

    private func checkHolidayUpdate() {
        guard !isUpdating else { return }
        isUpdating = true
        holidayStatus = nil
        Task { @MainActor in
            do {
                let result = try await HolidayStore.refreshFromRemote()
                holidayStatus = result.message
                holidaySummary = HolidayStore.summary
                holidayStamp = HolidayStore.dataTimestamp
                hasCache = HolidayStore.hasCachedData
            } catch {
                // 友好提示，不暴露错误码与技术细节：
                // 远程更新只是「锦上添花」，拿不到新数据时内置数据仍然正确可用，
                // 因此这里不把 404 / 超时这类信息甩给用户（技术细节见 HolidayStoreError.errorDescription）。
                holidayStatus = (error as? HolidayStoreError)?.friendlyMessage
                    ?? "暂时没能获取到最新安排，已继续使用 App 内置数据"
            }
            isUpdating = false
        }
    }

    // MARK: - 小组件

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("桌面小组件")
            widgetRow(size: "小尺寸", desc: "今日公历 · 农历 · 宜忌摘要", icon: "square")
            widgetRow(size: "中尺寸", desc: "当月月历缩略 + 今日宜忌", icon: "square.grid.2x2")
            widgetRow(size: "大尺寸", desc: "完整月历 + 今日黄历卡片", icon: "square.grid.3x3")
            widgetRow(size: "锁屏", desc: "矩形 / 行内组件：今日农历与宜忌", icon: "lock.rectangle")

            Button {
                showWidgetPreview = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 13, weight: .semibold))
                    Text("预览组件样式")
                        .scaledFont(14, weight: .semibold, design: .rounded)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Palette.accent)
                .padding(.top, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("按真实尺寸查看三档小组件的渲染效果")

            Text("添加方法：长按主屏幕空白处 → 点左上角「+」→ 搜索本 App → 选择尺寸与样式 → 添加。")
                .scaledFont(12, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func widgetRow(size: String, desc: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.accentSoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(size)
                    .scaledFont(15, weight: .semibold, design: .rounded)
                Text(desc)
                    .scaledFont(12, weight: .regular, design: .rounded)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("关于数据")
            Text("• 农历与二十四节气覆盖 1900–2100 年，采用中文农历界通用的查表算法。\n• 黄历宜忌基于传统「建除十二神」体系推算，并给出冲煞、彭祖百忌与吉神方位。\n• 历史上的今天只收录有公开记载的史实，共覆盖 \(HistoryToday.coveredDayCount) 个日期。\n• 法定节假日调休以国务院办公厅公布为准。")
                .scaledFont(12.5, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - 开发者选项（仅 Debug 构建）

    #if DEBUG
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("开发者选项 · 仅 Debug")

            Toggle(isOn: $showFPSHud) {
                settingLabel(title: "显示帧率 HUD",
                             detail: "在首页左下角实时显示 fps、最差单帧耗时与卡顿帧数")
            }
            .tint(Palette.accent)
            .accessibilityHint("打开后返回首页上下滑动，即可看到实时帧率")

            Text("用法：打开此开关 → 返回首页 → 用手指上下滑动。若「卡顿」一栏始终为 0、fps 稳定在 55 以上，说明渲染没有掉帧，此时若仍觉得不跟手，问题多半在手势/交互而不在渲染。点击 HUD 可清零重新计数。")
                .scaledFont(12, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Palette.separator)

            Text("命令行自检：以 `-scrollProbe` 启动会自动来回滚动 10 秒并在控制台打印帧统计；`-scrollProbeStatic` 则只统计、不自动滚动，供你手动滑动时采样。")
                .scaledFont(12, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
    #endif

    // MARK: - 组件

    private func settingLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .scaledFont(15, weight: .medium, design: .rounded)
            Text(detail)
                .scaledFont(12, weight: .regular, design: .rounded)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .scaledFont(13, weight: .bold, design: .rounded)
            .foregroundStyle(Palette.secondaryText)
    }
}
