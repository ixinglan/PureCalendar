import SwiftUI

/// 主界面：顶部月份导航 + 月历网格 + 当日详情。
struct RootView: View {
    @AppStorage("showAlmanac") private var showAlmanac = true
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false

    @State private var displayedYear: Int
    @State private var displayedMonth: Int
    @State private var selectedDate: SolarDate
    @State private var showSettings = false

    private let today = SolarDate.today

    init() {
        let t = SolarDate.today
        _displayedYear = State(initialValue: t.year)
        _displayedMonth = State(initialValue: t.month)
        _selectedDate = State(initialValue: t)
    }

    private var grid: MonthGrid {
        MonthGrid.make(year: displayedYear, month: displayedMonth, weekStartsOnMonday: weekStartsOnMonday)
    }

    private var selectedInfo: DayInfo? { DayInfo.make(solar: selectedDate) }

    private var isOnToday: Bool {
        selectedDate == today && displayedYear == today.year && displayedMonth == today.month
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Palette.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        MonthGridView(grid: grid, selectedDate: $selectedDate, weekStartsOnMonday: weekStartsOnMonday)
                            .padding(.horizontal, 16)
                            .gesture(swipeGesture)

                        if let info = selectedInfo {
                            DayDetailView(info: info, showAlmanac: showAlmanac)
                                .padding(.horizontal, 16)
                                .id("detail")
                        }

                        Spacer(minLength: 90)
                    }
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
        .animation(.snappy(duration: 0.25), value: isOnToday)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - 顶部导航

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(displayedYear) 年 \(displayedMonth) 月")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitleText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()
            HStack(spacing: 8) {
                navButton(systemName: "chevron.left") { step(-1) }
                navButton(systemName: "chevron.right") { step(1) }
                navButton(systemName: "gearshape") { showSettings = true }
            }
        }
    }

    private var subtitleText: String {
        guard let first = DayInfo.make(solar: grid.firstDay) else { return "" }
        return "\(first.lunar.ganZhiYear)年 · 属\(first.lunar.zodiac)"
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.accentSoft))
        }
        .buttonStyle(.plain)
    }

    private var todayButton: some View {
        Button(action: goToday) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                Text("今天")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Capsule().fill(Palette.accent))
            .shadow(color: Palette.accent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 交互

    @State private var todayResetToken = 0

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

    private func goToday() {
        withAnimation(.snappy(duration: 0.28)) {
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
                    step(1)
                } else if value.translation.width > 50 {
                    step(-1)
                }
            }
    }
}
