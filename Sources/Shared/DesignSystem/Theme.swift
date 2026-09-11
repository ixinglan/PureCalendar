import SwiftUI

// MARK: - 自适应颜色工具

extension Color {
    /// 根据浅色/深色模式返回不同颜色（跨 iOS / macOS 编译）。
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}

// MARK: - 设计系统调色板

/// 全局配色。采用「暖白 + 朱红」的东方视觉基调，兼顾现代与传统文化气质。
enum Palette {
    /// 页面背景（暖白 / 近黑）。
    static let background = Color(
        light: Color(red: 0.969, green: 0.965, blue: 0.957),
        dark: Color(red: 0.043, green: 0.043, blue: 0.055)
    )
    /// 卡片背景。
    static let card = Color(
        light: Color.white,
        dark: Color(red: 0.110, green: 0.110, blue: 0.125)
    )
    /// 主色：朱红。
    static let accent = Color(
        light: Color(red: 0.827, green: 0.227, blue: 0.220),
        dark: Color(red: 0.980, green: 0.373, blue: 0.365)
    )
    /// 主色的柔和底（用于今天高亮的浅底、标签底）。
    static let accentSoft = Color(
        light: Color(red: 0.827, green: 0.227, blue: 0.220).opacity(0.10),
        dark: Color(red: 0.980, green: 0.373, blue: 0.365).opacity(0.18)
    )
    /// 宜：青绿。
    static let yi = Color(
        light: Color(red: 0.106, green: 0.545, blue: 0.376),
        dark: Color(red: 0.243, green: 0.812, blue: 0.557)
    )
    /// 忌：绛红。
    static let ji = Color(
        light: Color(red: 0.741, green: 0.235, blue: 0.204),
        dark: Color(red: 0.976, green: 0.443, blue: 0.416)
    )
    /// 调休上班（班）标记色：琥珀橙。
    static let workday = Color(
        light: Color(red: 0.839, green: 0.506, blue: 0.125),
        dark: Color(red: 0.973, green: 0.643, blue: 0.286)
    )
    /// 次要文字。
    static let secondaryText = Color(
        light: Color(red: 0.42, green: 0.42, blue: 0.45),
        dark: Color(red: 0.62, green: 0.62, blue: 0.66)
    )
    /// 分隔线。
    static let separator = Color(
        light: Color(red: 0.90, green: 0.89, blue: 0.88),
        dark: Color(red: 0.22, green: 0.22, blue: 0.24)
    )
    /// 柔和卡片阴影色。
    static let shadow = Color.black.opacity(0.06)
}

// MARK: - 卡片样式

/// 统一的圆角卡片外观。
struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Palette.separator.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: Palette.shadow, radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// 应用统一卡片样式。
    func card(padding: CGFloat = 18, radius: CGFloat = 22) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }
}

// MARK: - 小标签

/// 圆角标签（用于节气、节日、宜忌等）。
struct TagChip: View {
    let text: String
    var color: Color = Palette.accent
    var filled: Bool = false

    var body: some View {
        Text(text)
            .scaledFont(12, weight: .medium)
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? color : color.opacity(0.12))
            )
    }
}

// MARK: - 无障碍字体缩放

/// 全局字号倍率（= 系统「动态字体」倍率 × App 内「大字体模式」附加倍率）。
private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

/// 在视图树**顶层**统一计算字号倍率，并注入环境。
///
/// 为什么这样设计（性能要点）：
/// 如果让每个 `Text` 各自持有一个 `@ScaledMetric`，那么一个月历 42 个格子
/// 就会产生上百个动态属性与上百个修饰器节点，视图图显著变大、布局变慢。
/// 由于本项目所有字号都以 `.body` 为基准缩放，**倍率是全站统一的**，
/// 因此只在一个容器上算一次、往下传同一个数即可，视觉效果完全一致。
struct ProvidesFontScale: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale: CGFloat = 1
    /// App 内附加倍率（「大字体模式」开关）。
    var extra: CGFloat = 1

    func body(content: Content) -> some View {
        content.environment(\.fontScale, dynamicTypeScale * extra)
    }
}

extension View {
    /// 在顶层注入字号倍率。**每个视图树只需要调用一次**（App 的主视图、每个小组件各一次）。
    /// 不要重复调用，否则系统动态字体倍率会被叠加多次。
    func providesFontScale(extra: CGFloat = 1) -> some View {
        modifier(ProvidesFontScale(extra: extra))
    }
}

/// 字体修饰器：按环境里的倍率缩放字号。
///
/// 说明：`Font.system(size:)` 写死的字号不会随系统字体大小变化，不符合无障碍要求。
/// 这里把「系统动态字体」与 App 内「大字体模式」合并成一个倍率（由 `providesFontScale` 注入），
/// 从而在保持视觉设计不变的前提下满足 WCAG 2.1 AA 对可缩放文字的要求。
struct ScaledFontModifier: ViewModifier {
    private let size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design
    @Environment(\.fontScale) private var scale

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        self.size = size
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: design))
    }
}

extension View {
    /// 无障碍字体：字号随系统动态字体与 App 内「大字体模式」一起缩放。
    ///
    /// 提示：在**大量重复的视图**（如月历的 42 个格子）里，优先直接读一次
    /// `EnvironmentValues.fontScale` 再用 `.font(.system(size: base * scale))`，
    /// 可以省掉每格一个修饰器节点。
    func scaledFont(_ size: CGFloat,
                    weight: Font.Weight = .regular,
                    design: Font.Design = .rounded) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}
