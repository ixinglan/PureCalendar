import SwiftUI

/// 主界面的浏览模式。
enum BrowseMode: Equatable {
    /// 月视图（默认）：月历 + 当日黄历详情。
    case month
    /// 年视图：一屏 12 个月。
    case year
}

/// 主界面：顶部导航 + 月历/年历 + 当日详情。
struct RootView: View {
    @AppStorage("showAlmanac") private var showAlmanac = true
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false
    @AppStorage("largeFontMode") private var largeFontMode = false

    @State private var displayedYear: Int
    @State private var displayedMonth: Int
    @State private var selectedDate: SolarDate
    @State private var showSettings = false
    @State private var mode: BrowseMode = .month
    @State private var todayResetToken = 0
    /// 仅调试用：启动后是否自动弹出「组件样式预览」（由启动参数 `-showWidgetPreview` 触发）。
    @State private var autoShowWidgetPreview = false

    private let today = SolarDate.today

    init() {
        // 默认：启动即定位到「今天」（`#if DEBUG` 下允许用启动参数覆盖，便于自动化验证）。
        #if DEBUG
        let options = RootView.debugLaunchOptions()
        #else
        let options = (date: SolarDate.today, mode: BrowseMode.month, showSettings: false, showWidgetPreview: false)
        #endif

        _displayedYear = State(initialValue: options.date.year)
        _displayedMonth = State(initialValue: options.date.month)
        _selectedDate = State(initialValue: options.date)
        _mode = State(initialValue: options.mode)
        _showSettings = State(initialValue: options.showSettings)
        _autoShowWidgetPreview = State(initialValue: options.showWidgetPreview)
    }

    #if DEBUG
    /// 解析调试用启动参数（仅 Debug 构建存在）。
    ///
    /// 用法示例：
    /// ```
    /// xcrun simctl launch booted com.ixiaoqiang.calendarapp -startMode year
    /// xcrun simctl launch booted com.ixiaoqiang.calendarapp -startDate 2026-10-01
    /// xcrun simctl launch booted com.ixiaoqiang.calendarapp -showSettings
    /// xcrun simctl launch booted com.ixiaoqiang.calendarapp -showWidgetPreview
    /// ```
    private static func debugLaunchOptions() -> (date: SolarDate, mode: BrowseMode, showSettings: Bool, showWidgetPreview: Bool) {
        var date = SolarDate.today
        var mode: BrowseMode = .month
        var showSettings = false

        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startMode"), i + 1 < args.count, args[i + 1] == "year" {
            mode = .year
        }
        if let i = args.firstIndex(of: "-startDate"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: "-").compactMap { Int($0) }
            if parts.count == 3 {
                date = SolarDate(year: parts[0], month: parts[1], day: parts[2])
            }
        }
        if args.contains("-showSettings") { showSettings = true }
        // 组件预览内嵌在设置页里，因此触发它时同时把设置页打开。
        let showWidgetPreview = args.contains("-showWidgetPreview")
        if showWidgetPreview { showSettings = true }

        return (date, mode, showSettings, showWidgetPreview)
    }
    #endif

    private var grid: MonthGrid {
        MonthGrid.make(year: displayedYear, month: displayedMonth, weekStartsOnMonday: weekStartsOnMonday)
    }

    private var selectedInfo: DayInfo? { DayInfo.make(solar: selectedDate) }

    /// 「今天」按钮是否应该显示。
    private var isOnToday: Bool {
        if mode == .year { return displayedYear == today.year }
        return selectedDate == today && displayedYear == today.year && displayedMonth == today.month
    }

    var body: some View {
        // `grid` 在这里**只求值一次**再往下传。
        // 它是计算属性（内含 42 天的完整信息），若在 body 里被多次访问会重复计算。
        content(for: grid)
    }

    private func content(for grid: MonthGrid) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Palette.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        header(for: grid)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        switch mode {
                        case .month:
                            MonthGridView(grid: grid, selectedDate: $selectedDate, weekStartsOnMonday: weekStartsOnMonday)
                                .padding(.horizontal, 16)
                                .transition(.opacity)

                            if let info = selectedInfo {
                                DayDetailView(info: info, showAlmanac: showAlmanac)
                                    .padding(.horizontal, 16)
                                    .id("detail")
                            }
                        case .year:
                            YearView(
                                year: displayedYear,
                                today: today,
                                selectedDate: selectedDate,
                                weekStartsOnMonday: weekStartsOnMonday,
                                onSelectMonth: openMonth
                            )
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                        }

                        Spacer(minLength: 90)
                    }
                    .contentShape(Rectangle())
                    .gesture(swipeGesture)
                }
                .onChange(of: selectedDate) { _, _ in
                    // 选中相邻月份的日期时，同步显示月份
                    if selectedDate.year != displayedYear || selectedDate.month != displayedMonth {
                        displayedYear = selectedDate.year
                        displayedMonth = selectedDate.month
                    }
                }
                .onChange(of: todayResetToken) { _, _ in
                    withAnimation { proxy.scrollTo("detail", anchor: .top) }
                }
            }

            if !isOnToday {
                todayButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        // 字号倍率只在这里算一次（系统动态字体 × 「大字体模式」），往下走环境传递。
        .providesFontScale(extra: largeFontMode ? 1.18 : 1)
        .animation(.snappy(duration: 0.25), value: isOnToday)
        .animation(.snappy(duration: 0.28), value: mode)
        // 触觉反馈（无障碍：为非视觉用户提供操作确认）
        .sensoryFeedback(.selection, trigger: selectedDate)
        .sensoryFeedback(.impact(weight: .light), trigger: displayedMonth)
        .sensoryFeedback(.impact(weight: .light), trigger: displayedYear)
        .sensoryFeedback(.success, trigger: todayResetToken)
        .sheet(isPresented: $showSettings) {
            SettingsView(autoShowWidgetPreview: autoShowWidgetPreview)
        }
    }

    // MARK: - 顶部导航

    @ViewBuilder
    private func header(for grid: MonthGrid) -> some View {
        switch mode {
        case .month: monthHeader(grid)
        case .year: yearHeader
        }
    }

    private func monthHeader(_ grid: MonthGrid) -> some View {
        HStack(alignment: .center) {
            // 点标题展开年视图（与 Apple 日历一致的手势心智）。
            Button {
                withAnimation(.snappy(duration: 0.28)) { mode = .year }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        // Text(verbatim:) 避免 LocalizedStringKey 把年份格式化成「2,026」。
                        Text(verbatim: grid.title)
                            .scaledFont(27, weight: .bold, design: .rounded)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Text(subtitleText(of: grid))
                        .scaledFont(13, weight: .medium, design: .rounded)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(grid.title)，\(subtitleText(of: grid))")
            .accessibilityHint("展开年视图")

            Spacer()

            HStack(spacing: 8) {
                navButton(systemName: "chevron.left", label: "上一月") { step(-1) }
                navButton(systemName: "chevron.right", label: "下一月") { step(1) }
                navButton(systemName: "gearshape", label: "设置") { showSettings = true }
            }
        }
    }

    private var yearHeader: some View {
        HStack(alignment: .center) {
            Button {
                withAnimation(.snappy(duration: 0.28)) { mode = .month }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(verbatim: "\(displayedYear) 年")
                            .scaledFont(27, weight: .bold, design: .rounded)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Text(yearSubtitleText)
                        .scaledFont(13, weight: .medium, design: .rounded)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(displayedYear) 年，\(yearSubtitleText)")
            .accessibilityHint("返回月视图")

            Spacer()

            HStack(spacing: 8) {
                navButton(systemName: "chevron.left", label: "上一年") { stepYear(-1) }
                navButton(systemName: "chevron.right", label: "下一年") { stepYear(1) }
                navButton(systemName: "gearshape", label: "设置") { showSettings = true }
            }
        }
    }

    private func subtitleText(of grid: MonthGrid) -> String {
        guard let first = DayInfo.make(solar: grid.firstDay) else { return "" }
        return "\(first.lunar.ganZhiYear)年 · 属\(first.lunar.zodiac)"
    }

    /// 年视图副标题：该年干支 + 生肖（轻量算法，不构建整年网格）。
    private var yearSubtitleText: String {
        CalendarYear.ganZhiZodiac(of: displayedYear) ?? ""
    }

    private func navButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.accentSoft))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var todayButton: some View {
        Button(action: goToday) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                Text("今天")
                    .scaledFont(14, weight: .semibold, design: .rounded)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Capsule().fill(Palette.accent))
            .shadow(color: Palette.accent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("回到今天")
    }

    // MARK: - 交互

    private func step(_ delta: Int) {
        withAnimation(.snappy(duration: 0.28)) {
            var m = displayedMonth + delta
            var y = displayedYear
            if m < 1 { m = 12; y -= 1 }
            if m > 12 { m = 1; y += 1 }
            displayedMonth = m
            displayedYear = y
        }
    }

    private func stepYear(_ delta: Int) {
        withAnimation(.snappy(duration: 0.28)) {
            displayedYear += delta
        }
    }

    /// 从年视图进入某个月。
    private func openMonth(_ month: Int) {
        withAnimation(.snappy(duration: 0.28)) {
            displayedMonth = month
            if displayedYear == today.year && month == today.month {
                selectedDate = today
            } else {
                selectedDate = SolarDate(year: displayedYear, month: month, day: 1)
            }
            mode = .month
        }
    }

    private func goToday() {
        withAnimation(.snappy(duration: 0.28)) {
            mode = .month
            selectedDate = today
            displayedYear = today.year
            displayedMonth = today.month
        }
        todayResetToken += 1
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                if value.translation.width < -50 {
                    advance(1)
                } else if value.translation.width > 50 {
                    advance(-1)
                }
            }
    }

    /// 左右滑动：月视图翻月 / 年视图翻年。
    private func advance(_ delta: Int) {
        switch mode {
        case .month: step(delta)
        case .year: stepYear(delta)
        }
    }
}
