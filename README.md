# 日历 App（iPhone / iOS 17+）

一款现代化、视觉舒适的 iPhone 日历 App：公历 + 农历 + 节日节气 + 老黄历（宜忌/冲煞/吉神），并提供多尺寸桌面与锁屏小组件。

技术栈：**SwiftUI + WidgetKit**，纯原生，无第三方依赖。

---

## 一、先决条件

本机目前**只装了 Command Line Tools，没有 Xcode**，也没有 iOS 模拟器。要运行本工程，请先：

1. 从 App Store 安装 **Xcode**（当前最新版即可，支持 iOS 17+）。
2. 首次打开 Xcode 后执行：`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
3. 打开 `CalendarApp.xcodeproj`。

代码已在本地用 Swift 编译器做过 **全量类型检查（0 错误 0 警告）**，但尚未在模拟器上运行过（本机无 Xcode），首次运行前请留意这一层。

---

## 二、运行步骤

1. 双击 `CalendarApp.xcodeproj` 打开。
2. 左侧选择 **CalendarApp** target → Signing & Capabilities → 勾选 *Automatically manage signing*，Team 选择你自己的 Apple ID。
3. 顶部设备选择任意 iPhone 模拟器（如 iPhone 16），点击 ▶️ 运行。
4. 添加小组件：在模拟器主屏长按空白 → 左上角「+」→ 搜索「日历」→ 选择尺寸。

> 若报 "CalendarWidget" 签名错误，同样在 CalendarWidget target 里选一次 Team 即可。

---

## 三、功能一览（对应你的 4 点需求）

| 需求 | 实现 |
|---|---|
| 1. 打开自动定位当天 | 启动即定位今天；右下角「今天」悬浮按钮一键回到当天 |
| 2. 公历+农历+节日，默认一个月 | 月历网格：公历大数字 + 农历/节日小字；今天高亮、节假日标红；左右滑动翻月 |
| 3. 下方展示黄历、宜、忌 | 常驻详情面板：农历全称/干支/生肖/星座、**宜/忌**、冲煞/喜神/财神/福神、值日（建除十二神+天神+黄道黑道）、彭祖百忌 |
| 4. 多尺寸桌面小组件 | 小(2×2) / 中(4×4) / 大(4×8) 三档 + 锁屏矩形、锁屏行内 |

---

## 四、目录结构

```
日历 APP/
├── project.yml                 # XcodeGen 工程定义（改文件后重新生成工程用）
├── CalendarApp.xcodeproj       # 已生成的 Xcode 工程（直接打开即可）
├── Sources/
│   ├── Shared/                 # App 与小组件共享
│   │   ├── Lunar/
│   │   │   ├── LunarData.swift      # 自动生成的农历/节气数据表（1900–2100）
│   │   │   ├── LunarCalendar.swift  # 农历核心：公农历互转、干支、生肖、节气
│   │   │   ├── Almanac.swift        # 黄历：建除十二神、冲煞、彭祖百忌、吉神方位
│   │   │   └── HolidayProvider.swift# 节日/节气/星座
│   │   ├── Models/             # SolarDate / DayInfo / MonthGrid
│   │   └── DesignSystem/       # 配色、卡片样式（Palette / card / TagChip）
│   ├── App/                    # 主 App：入口 + 4 个视图
│   └── Widget/                 # WidgetKit 扩展：三档 + 锁屏组件
└── README.md
```

---

## 五、数据与算法说明（重要）

- **农历 / 二十四节气**：采用中文农历界通用的「1900–2100 查表算法」，数据由脚本从权威开源库 `solarlunar`（MIT）自动提取生成，覆盖 1900-01-31 ~ 2100-12-31。
  已验证：春节（2024/2025/2026）、中秋、端午、除夕、立春/春分/夏至/秋分/清明等节气均正确。
- **干支口径**：年柱与生肖统一按「农历年（正月初一换年）」，符合主流消费级日历 App 习惯；月柱按二十四「节」划分（传统规则）。
- **黄历宜忌**：基于传统 **建除十二神** 体系推导；值日天神、彭祖百忌、喜神/财神/福神方位均按传统历法规则计算（数据取自 6tail lunar 库的权威表）。
  > 宜忌数据已做成集中数据层（`Almanac.swift`），后续可无缝替换为商业黄历数据源。
- **法定节假日**：V1 仅标记节日性质（是否法定），不展示调休安排——因调休由国务院逐年公布，避免使用过时数据。

---

## 六、修改后如何重新生成工程

改了文件结构（新增/删除源文件）或 `project.yml` 后，重新执行：

```bash
xcodegen generate --spec project.yml
```

（本机临时安装的 xcodegen 位于 `/tmp/xg/xcodegen/bin/xcodegen`；也可 `brew install xcodegen`。）

---

## 七、后续版本计划（P1 / P2）

- **P1**：年视图、历史上的今天、大字体/无障碍打磨、节假日年度更新机制。
- **P2**：日程增删改、iCloud 云同步、节日/宜忌轻推送、节气物候动效。
