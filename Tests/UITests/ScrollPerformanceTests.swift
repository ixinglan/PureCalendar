import XCTest

/// 首页滚动的性能测试。
///
/// 为什么必须用 UI 测试而不是程序化滚动：
/// 本项目在滚动内容上挂了自定义 `DragGesture`（左右滑动翻月）。这个手势只有在
/// **真实触摸**时才会与 ScrollView 的 pan 手势发生仲裁；`ScrollViewReader.scrollTo`
/// 这类程序化滚动完全不经过手势系统，因此测不出这类问题。
/// `XCUIElement.swipeUp()` 走的是真实触摸事件链路，是唯一能复现的途径。
///
/// 使用的指标：
/// - `XCTHitchMetric`：直接统计滚动过程中产生的**卡顿（hitch）**——苹果 Xcode 26 新增，
///   这是最贴近「卡不卡」的主观感受的官方指标。
/// - `XCTOSSignpostMetric.scrollingAndDecelerationMetric`：覆盖「拖动 + 惯性减速」
///   两个阶段的时长（旧 API `scrollDecelerationMetric` 只覆盖减速段，且已废弃）。
///
/// 指标全部遵循「越小越好」，因此可以在改动前后直接比较平均值。
final class ScrollPerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 首页（月视图）用快速滑动来回滚动，测量滚动卡顿。
    ///
    /// 用 `velocity: .fast` 是为了触发**惯性减速**——慢速拖动几乎不产生减速段，
    /// 滚动时长指标会没有样本。
    func testHomeScrollHitchRatio() throws {
        let app = XCUIApplication()
        // 固定从月视图、今天开始，保证每次测量起点一致、结果可比。
        app.launchArguments = ["-startMode", "month"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20),
                      "App 未能在 20 秒内进入前台")

        // 先停一下，等首帧与首屏布局稳定，避免把冷启动开销算进滚动数据。
        Thread.sleep(forTimeInterval: 2.0)

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        var metrics: [XCTMetric] = [
            XCTOSSignpostMetric.scrollingAndDecelerationMetric,
            // 滚动时顺带看一眼 CPU，用于区分「渲染贵」还是「计算贵」。
            XCTCPUMetric(application: app),
        ]
        if #available(iOS 26.0, *) {
            metrics.insert(XCTHitchMetric(application: app), at: 0)
        }

        measure(metrics: metrics, options: options) {
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }

    /// 点击日期格子后，详情卡片应切换到该日。
    ///
    /// 这条用例守的是一个**很容易在性能优化中被改坏**的细节：
    /// 为了减少 42 个 `Button` 带来的手势仲裁开销，`DayCell` 被改成了
    /// `.onTapGesture` + `.accessibilityAddTraits(.isButton)`。
    /// 功能必须完全等价——点击要生效，VoiceOver 也要仍能把它当按钮读出来。
    func testTappingDayUpdatesDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-startMode", "month", "-startDate", "2026-09-11"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20),
                      "App 未能在 20 秒内进入前台")

        // 初始详情应是 9 月 11 日（农历丙午年八月初一）。
        XCTAssertTrue(app.staticTexts["农历丙午年八月初一"].waitForExistence(timeout: 5),
                      "初始详情卡片不是 9 月 11 日")

        // 点 9 月 25 日（农历八月十五 · 中秋节 · 放假）。
        // 日期格子被暴露成 button，用无障碍文案里的日期做定位。
        let cell = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "9 月 25 日"))
            .firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "找不到 9 月 25 日的日期格子（无障碍语义可能丢失）")
        cell.tap()

        XCTAssertTrue(app.staticTexts["农历丙午年八月十五"].waitForExistence(timeout: 5),
                      "点击日期后详情卡片没有切换过去")
    }
}
