//
//  ScrollDiagnostics.swift
//  仅 Debug 生效的滚动流畅度诊断工具。
//
//  为什么要它：
//  「滚动卡不卡」是主观感受，靠肉眼看不出是哪一帧掉、掉了多少。
//  这里用 CADisplayLink 记录**每一帧的真实间隔**，滚动结束后打印统计，
//  把「卡卡的」变成「p99 帧间隔 XX ms、卡顿率 X%」这种可比对的数字。
//
//  用法：以 `-scrollProbe` 启动参数开启（见 `ScrollDiagnostics.isEnabled`）。
//

import SwiftUI
import QuartzCore

/// 滚动锚点 id 常量，避免各处手写字符串拼错。
///
/// 注意：它**必须存在于 Release 构建**——`RootView` 的 `body` 里会给滚动内容挂
/// `.id(ScrollAnchor.top)`，而 `body` 在 Release 下同样要编译。
/// 给滚动内容挂稳定 id 本身没有副作用，不影响正式包行为。
enum ScrollAnchor {
    static let top = "scroll.top"
    static let bottom = "scroll.bottom"
}

#if DEBUG

// MARK: - 重建计数器

/// 统计「视图 body 被求值了多少次」。
///
/// 为什么需要它：滚动掉帧最隐蔽的根因是**滚动过程中视图树被反复重建**
/// （body 重新求值 → 文本重排 → 图层重画）。如果一次滚动里 body 只跑了几次，
/// 说明渲染是稳态的、瓶颈在别处；如果跑了几百次，那就是找到了真凶。
///
/// 计数写入是普通静态变量自增，开销可忽略；只在 Debug 下存在。
enum RenderCounter {
    static var rootBody = 0
    static var dayCellBody = 0
    static var monthGridMake = 0
    static var dayDetailBody = 0

    static func snapshot() -> (root: Int, cell: Int, grid: Int, detail: Int) {
        (rootBody, dayCellBody, monthGridMake, dayDetailBody)
    }

    static func reset() {
        rootBody = 0
        dayCellBody = 0
        monthGridMake = 0
        dayDetailBody = 0
    }
}

// MARK: - 帧间隔探针

/// 采集滚动过程中的帧间隔并输出统计报告。
///
/// 关键指标：
/// - **中位帧间隔**：实际达成的帧率（1 / 中位数）
/// - **p95 / p99 / max**：长尾有多差，肉眼感知的「卡一下」通常来自这里
/// - **卡顿帧比例**：间隔超过 1.5× 中位数的帧占比，直接对应「跟不跟手」
final class ScrollFrameProbe {
    static let shared = ScrollFrameProbe()

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var intervals: [Double] = []
    private var startedAt: CFTimeInterval = 0
    private var finishTimer: Timer?
    private var renderAtStart: (root: Int, cell: Int, grid: Int, detail: Int) = (0, 0, 0, 0)

    private init() {}

    /// 开始采集。
    /// - Parameter duration: 采集时长（秒），到点自动出报告。
    func start(duration: TimeInterval) {
        stop()
        intervals.removeAll(keepingCapacity: true)
        lastTimestamp = 0
        startedAt = CACurrentMediaTime()
        renderAtStart = RenderCounter.snapshot()

        let l = CADisplayLink(target: self, selector: #selector(onFrame))
        // 不限制帧率，让显示器以原生刷新率回调（iPhone 17 最高 120Hz）。
        l.add(to: .main, forMode: .common)
        link = l

        finishTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.report()
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
        finishTimer?.invalidate()
        finishTimer = nil
    }

    @objc private func onFrame(_ l: CADisplayLink) {
        let now = CACurrentMediaTime()
        if lastTimestamp > 0 {
            intervals.append(now - lastTimestamp)
        }
        lastTimestamp = now
    }

    private func report() {
        stop()

        let collected = intervals
        guard collected.count > 10 else {
            log("[ScrollProbe] 样本不足（\(collected.count) 帧），跳过报告")
            return
        }

        let sorted = collected.sorted()
        let count = sorted.count
        let avg = collected.reduce(0, +) / Double(count)
        let median = sorted[count / 2]

        func percentile(_ p: Double) -> Double {
            sorted[min(count - 1, Int(Double(count) * p))]
        }

        // 以**实测中位帧间隔**为基准，而不是硬假设 60fps：
        // 若设备实际跑 120Hz，基准就是 8.3ms，这样算出的卡顿比例才有意义。
        let jankFrames = collected.filter { $0 > median * 1.5 }.count
        let severeFrames = collected.filter { $0 > median * 2 }.count

        log("────────── 滚动流畅度报告 ──────────")
        log(String(format: "采集 %.2fs，共 %d 帧", CACurrentMediaTime() - startedAt, count))
        log(String(format: "平均帧间隔 %.2f ms（≈ %.1f fps）", avg * 1000, 1 / avg))
        log(String(format: "中位 %.2f ms（≈ %.1f fps）  ← 实际帧率", median * 1000, 1 / median))
        log(String(format: "p95 %.2f ms | p99 %.2f ms | 最大 %.2f ms",
                   percentile(0.95) * 1000, percentile(0.99) * 1000, sorted[count - 1] * 1000))
        log(String(format: "卡顿帧(>1.5×中位) %d 帧，占 %.1f%%",
                   jankFrames, Double(jankFrames) / Double(count) * 100))
        log(String(format: "严重卡顿(>2×中位) %d 帧，占 %.1f%%",
                   severeFrames, Double(severeFrames) / Double(count) * 100))
        log("──────────── 期间视图重建次数 ────────────")
        let now = RenderCounter.snapshot()
        log("RootView.body            \(now.root - renderAtStart.root) 次")
        log("MonthGrid.make           \(now.grid - renderAtStart.grid) 次")
        log("DayCell.body             \(now.cell - renderAtStart.cell) 次")
        log("DayDetailView.body       \(now.detail - renderAtStart.detail) 次")
        log("───────────────────────────────────")
    }

    /// 写 stderr：无缓冲，`simctl launch --console-pty` 能立刻拿到。
    private func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

// MARK: - 自动滚动驱动

/// 用「连续的隐式动画」驱动 ScrollView 来回滚动，从而在**无需人工操作**的前提下
/// 复现真实滚动，供帧探针采样。
///
/// 为什么不用手指：`simctl` 没有点击/滑动注入能力（见 ios-simulator-verify 技能）。
/// 程序化滚动虽然输入来源不同，但走的是**同一条渲染/合成路径**，
/// 帧间隔数据因此具备可比性。
struct AutoScroller {
    /// 从顶部滚到底部的时长；越短越快，越快越容易暴露渲染瓶颈。
    var duration: TimeInterval = 1.6
    /// 到达端点后停留多久再折返。
    var pause: TimeInterval = 0.15

    func run(proxy: ScrollViewProxy) {
        cycle(proxy: proxy, toBottom: true)
    }

    private func cycle(proxy: ScrollViewProxy, toBottom: Bool) {
        withAnimation(.linear(duration: duration)) {
            proxy.scrollTo(toBottom ? ScrollAnchor.bottom : ScrollAnchor.top,
                           anchor: toBottom ? .bottom : .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + pause) {
            cycle(proxy: proxy, toBottom: !toBottom)
        }
    }
}

// MARK: - 实时帧率 HUD

/// 实时帧率表盘的模型。
///
/// 设计要点：**测量每帧、但每 0.25 秒才刷新一次 UI**。
/// 如果每帧都推 `@Published`，HUD 自己就会每秒触发 60 次 SwiftUI 重绘，
/// 反而把被测对象拖慢——测量工具不能污染被测对象。
@MainActor
final class FPSHudModel: ObservableObject {
    /// 最近一个统计窗口内的平均帧率。
    @Published private(set) var fps: Double = 0
    /// 本次会话观测到的最差单帧耗时（毫秒）。
    @Published private(set) var worstFrameMs: Double = 0
    /// 本次会话累计的卡顿帧数（单帧耗时 > 1.5× 标称帧间隔）。
    @Published private(set) var hitchCount: Int = 0
    /// 标称帧间隔（毫秒），由显示器刷新率决定。
    @Published private(set) var nominalMs: Double = 16.67

    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0
    private var framesInWindow = 0
    private var lastUIUpdate: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(onFrame))
        l.add(to: .main, forMode: .common)
        link = l
        lastFrame = 0
        windowStart = CACurrentMediaTime()
        framesInWindow = 0
        lastUIUpdate = 0
        worstFrameMs = 0
        hitchCount = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    func reset() {
        worstFrameMs = 0
        hitchCount = 0
        windowStart = CACurrentMediaTime()
        framesInWindow = 0
        fps = 0
    }

    @objc private func onFrame(_ l: CADisplayLink) {
        let now = CACurrentMediaTime()
        defer { lastFrame = now }

        guard lastFrame > 0 else { return }
        let delta = now - lastFrame
        framesInWindow += 1

        let nominal = l.targetTimestamp - l.timestamp
        let ms = delta * 1000

        // 折算成「标称帧间隔」的倍数判断是否掉帧；首次回调时拿不到标称值，跳过。
        if nominal > 0, nominal < 0.1 {
            let ratio = delta / nominal
            if ratio > 1.5 { hitchCount += 1 }
            if ms > worstFrameMs { worstFrameMs = ms }
            // 只在刷新 UI 时才写，避免高频 @Published 触发无谓重绘。
            if now - lastUIUpdate >= 0.25 {
                lastUIUpdate = now
                nominalMs = nominal * 1000
            }
        }

        if now - windowStart >= 0.25 {
            let elapsed = now - windowStart
            let newFPS = Double(framesInWindow) / elapsed
            if abs(newFPS - fps) > 0.5 { fps = newFPS }
            windowStart = now
            framesInWindow = 0
        }
    }
}

/// 悬浮在首页右上角的实时帧率表（仅 Debug 构建存在）。
///
/// 用途：在你**自己的设备上用真实手指**滚动时，直接看到「到底掉没掉帧」，
/// 把「感觉卡」变成可读的数字，而不必依赖任何外部工具。
struct FPSHudView: View {
    @StateObject private var model = FPSHudModel()

    /// 颜色阈值：≥55fps 绿、≥40fps 橙、否则红。
    private var tint: Color {
        if model.fps >= 55 { return .green }
        if model.fps >= 40 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(String(format: "%.0f fps", model.fps))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            Text(String(format: "最差 %.1f ms", model.worstFrameMs))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
            Text("卡顿 \(model.hitchCount) 帧")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(model.hitchCount == 0 ? Color.green.opacity(0.9) : Color.orange)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onTapGesture { model.reset() }
        .accessibilityHidden(true)
    }
}

// MARK: - 启动参数

/// 诊断开关集中在这里，方便一眼看清有哪些调试入口。
enum ScrollDiagnostics {
    /// `-scrollProbe`：开启自动滚动 + 帧探针（默认采样 10 秒）。
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-scrollProbe")
    }

    /// `-scrollProbeStatic`：只挂探针、不自动滚动，用于测量「静止时」的基线，
    /// 以区分「稳态渲染开销」与「滚动新增开销」。
    static var isStaticProbe: Bool {
        ProcessInfo.processInfo.arguments.contains("-scrollProbeStatic")
    }
}

#endif
