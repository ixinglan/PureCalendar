import SwiftUI

/// 设置页（以 sheet 呈现）。
struct SettingsView: View {
    @AppStorage("showAlmanac") private var showAlmanac = true
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    displaySection
                    widgetSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("设置")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 2)
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("显示")

            Toggle(isOn: $showAlmanac) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("显示黄历宜忌")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    Text("关闭后仅显示公历、农历与节日")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            .tint(Palette.accent)

            Divider().overlay(Palette.separator)

            VStack(alignment: .leading, spacing: 8) {
                Text("每周起始")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                Picker("每周起始", selection: $weekStartsOnMonday) {
                    Text("周日").tag(false)
                    Text("周一").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
        .card()
    }

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("桌面小组件")
            widgetRow(size: "小尺寸", desc: "今日公历 · 农历 · 宜忌摘要", icon: "square")
            widgetRow(size: "中尺寸", desc: "当月月历缩略 + 今日宜忌", icon: "square.grid.2x2")
            widgetRow(size: "大尺寸", desc: "完整月历 + 今日黄历卡片", icon: "square.grid.3x3")

            Text("添加方法：长按主屏幕空白处 → 点左上角「+」→ 搜索本 App → 选择尺寸与样式 → 添加。")
                .font(.system(size: 12, design: .rounded))
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
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(desc)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("关于数据")
            Text("农历与二十四节气覆盖 1900–2100 年；黄历宜忌基于传统「建除十二神」体系推算；法定节假日仅标注节日性质，调休安排请以国务院公布为准。")
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Palette.secondaryText)
    }
}
