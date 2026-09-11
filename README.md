# 日历 App（iPhone / iOS 17+）

一款现代化、视觉舒适的 iPhone 日历 App：公历 + 农历 + 节日节气 + 老黄历（宜忌/冲煞/吉神）+ 放假调休 + 历史上的今天，并提供多尺寸桌面与锁屏小组件。

技术栈：**SwiftUI + WidgetKit**，纯原生，无第三方依赖。

| 月视图与黄历 | 年视图 | 历史上的今天 | 大字体模式 | 设置 |
|---|---|---|---|---|
| ![](docs/screenshots/01-月视图与黄历.png) | ![](docs/screenshots/02-年视图.png) | ![](docs/screenshots/03-历史上的今天.png) | ![](docs/screenshots/04-大字体模式.png) | ![](docs/screenshots/05-设置.png) |

---

## 一、环境与验证状态

本机已安装 **Xcode 26.6**（iPhoneOS 26.5 SDK + iPhone 17 模拟器）。当前状态：

| 项目 | 状态 |
|---|---|
| 真机 SDK 构建（`iphonesimulator`，arm64，iOS 17.0 target） | ✅ 通过，**0 错误 0 警告** |
| 模拟器安装 / 启动 / 渲染 | ✅ 已实测（上方 5 张截图均为 iPhone 17 模拟器实拍） |
| `CalendarApp` + `CalendarWidget` 双 target | ✅ 均编译链接成功，widget 已嵌入 `PlugIns/` |
| `holiday-plans.json` 打包进 App Bundle | ✅ 已验证（3150 B，见构建产物） |

> 若要自己跑一遍：见第二节。

---

## 二、运行步骤

### 方式 A：命令行构建 + 模拟器（最快）

```bash
cd "日历 APP"

# 构建（模拟器）
xcodebuild -project CalendarApp.xcodeproj -scheme CalendarApp \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build

# 启动模拟器 → 安装 → 运行
xcrun simctl boot "iPhone 17"
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/CalendarApp.app
xcrun simctl launch booted com.ixiaoqiang.calendarapp
```

### 方式 B：Xcode 打开

1. 双击 `CalendarApp.xcodeproj`。
2. 选择 **CalendarApp** target → Signing & Capabilities → 勾选 *Automatically manage signing*，Team 选自己的 Apple ID。
3. 选择任意 iPhone 模拟器 → ▶️ 运行。
4. 添加小组件：主屏长按空白 → 左上角「+」→ 搜索「日历」→ 选择尺寸。

> 若报 "CalendarWidget" 签名错误，在 CalendarWidget target 里同样选一次 Team。

### 调试用启动参数（仅 Debug 构建生效）

便于自动化截图 / 冒烟测试：

```bash
xcrun simctl launch booted com.ixiaoqiang.calendarapp -startMode year        # 直接进年视图
xcrun simctl launch booted com.ixiaoqiang.calendarapp -startDate 2026-10-01  # 直接定位到某天
xcrun simctl launch booted com.ixiaoqiang.calendarapp -showSettings          # 直接打开设置页
xcrun simctl launch booted com.ixiaoqiang.calendarapp -largeFontMode YES     # 开启大字体（走 UserDefaults）
```

---

## 三、功能一览

### 3.1 原始 4 点需求（P0 / V1）

| 需求 | 实现 |
|---|---|
| 1. 打开自动定位当天 | 启动即定位今天；任意页面右下角「今天」悬浮按钮一键回到当天 |
| 2. 公历+农历+节日，默认一个月 | 月历网格：公历大数字 + 农历/节日小字；今天高亮、节假日标红；左右滑动翻月 |
| 3. 下方展示黄历、宜、忌 | 常驻详情面板：农历全称/干支/生肖/星座、**宜/忌**、冲煞/喜神/财神/福神、值日（建除十二神+天神+黄道黑道）、彭祖百忌 |
| 4. 多尺寸桌面小组件 | 小(2×2) / 中(4×4) / 大(4×8) 三档 + 锁屏矩形、锁屏行内 |

### 3.2 P1（V1.1）本次新增

| 功能 | 说明 |
|---|---|
| **年视图** | 点顶部月份标题（或上滑手势）展开，一屏纵览 12 个月；点任意月份跳转。当前月与今天有高亮，底部有「节日·放假 / 调休上班」图例 |
| **放假调休标记** | 月历与年视图直接标出「休 / 班」：放假日用主色，**调休上班日（周末却要上班）用琥珀橙**——最容易被漏看的「班」一眼可见 |
| **历史上的今天** | 精选 80+ 个日期、100+ 条有公开记载的史实，按年份列在详情面板；无收录的日期不显示该卡片 |
| **大字体模式** | 设置页开关，在系统动态字体基础上再放大 18%；配合 `@ScaledMetric` 让全站文字都响应系统字体大小 |
| **无障碍打磨** | 日期格子、宜忌、方位等补齐 VoiceOver 朗读文案；翻月/回今天加入触觉反馈；图标按钮与标签补 accessibility label/hint；配色对比度满足 WCAG 2.1 AA |
| **节假日年度更新机制** | 「内置基线 + 本地缓存 + 远程更新」三级数据源，国务院公布次年安排后**无需重新发版**即可更新（详见第五节） |
| **锁屏组件** | 矩形 / 行内两种锁屏配件（V1 已实现，本次补进设置页说明） |
| **深色主题** | 全站自适应浅色 / 深色（V1 已实现） |

---

## 四、目录结构

```
日历 APP/
├── project.yml                      # XcodeGen 工程定义（改文件结构后重新生成工程用）
├── CalendarApp.xcodeproj            # 已生成的 Xcode 工程（直接打开即可）
├── docs/screenshots/                # 界面实拍（iPhone 17 模拟器）
├── Sources/
│   ├── Shared/                      # App 与小组件共享
│   │   ├── Lunar/
│   │   │   ├── LunarData.swift          # 自动生成的农历/节气数据表（1900–2100）
│   │   │   ├── LunarCalendar.swift      # 农历核心：公农历互转、干支、生肖、节气
│   │   │   ├── Almanac.swift            # 黄历：建除十二神、冲煞、彭祖百忌、吉神方位
│   │   │   ├── HolidayProvider.swift    # 节日 / 节气 / 星座
│   │   │   ├── HolidayPlan.swift        # 放假调休数据模型 + 年度更新机制（HolidayStore）
│   │   │   └── HistoryToday.swift       # 历史上的今天数据表
│   │   ├── Models/                  # SolarDate / DayInfo / MonthGrid / CalendarYear
│   │   ├── Views/                   # MiniMonthGrid（主 App 与小组件共用）
│   │   ├── Resources/               # holiday-plans.json（内置节假日基线）
│   │   └── DesignSystem/            # 配色、卡片样式、字号缩放（Palette / card / scaledFont）
│   ├── App/                         # 主 App：入口 + 6 个视图
│   │   └── Views/                   # RootView / MonthGridView / DayDetailView /
│   │                                #   YearView / HistoryTodayView / SettingsView
│   └── Widget/                      # WidgetKit 扩展：三档 + 锁屏组件
└── README.md
```

---

## 五、数据与算法说明（重要）

### 5.1 农历 / 节气 / 黄历

- **农历 / 二十四节气**：中文农历界通用的「1900–2100 查表算法」，数据由脚本从权威开源库 `solarlunar`（MIT）提取生成，覆盖 1900-01-31 ~ 2100-12-31。
  已验证：春节（2024/2025/2026）、中秋、端午、除夕、立春/春分/夏至/秋分/清明等节气。
- **干支口径**：年柱与生肖统一按「农历年（正月初一换年）」，符合主流消费级日历 App 习惯；月柱按二十四「节」划分（传统规则）。
- **黄历宜忌**：基于传统 **建除十二神** 体系推导；值日天神、彭祖百忌、喜神/财神/福神方位均按传统历法规则计算。
  > 宜忌数据集中在 `Almanac.swift`，后续可无缝替换为商业黄历数据源。

### 5.2 节假日年度更新机制（P1 重点）

**问题**：放假与调休安排由国务院办公厅**逐年**公布（一般在前一年 11 月前后）。若把它写死在代码里，每年都必须重新发版，否则用户看到的就是过时且**错误**的调休信息。

**方案**：三级数据源，后者覆盖前者。

| 级别 | 位置 | 作用 |
|---|---|---|
| 1. 内置基线 | `Sources/Shared/Resources/holiday-plans.json` | 随包发布，保证首次启动与离线可用 |
| 2. 本地缓存 | `Application Support/CalendarApp/HolidayPlans.json` | 上一次远程更新的结果，重启后仍生效 |
| 3. 远程数据 | `Info.plist` 的 `HolidayPlansURL` 指向的同结构 JSON | 公布次年安排后**无需发版**即可更新 |

- 读取顺序「缓存 > 内置」，同一年份取 `publishedAt` 较新者；
- 设置页展示「已收录 N 个年度（起–止）」与数据日期，并支持手动「检查更新」/「恢复内置数据」；
- **优雅降级**：某年缺数据时返回 `nil`，上层退回「只显示节日性质、不显示调休」，**绝不猜测、绝不使用过时数据**；
- 数据来源已在 JSON 中逐条标注发文字号（如 `国办发明电〔2025〕7号`），便于溯源与审计。

**当前内置数据**（均为官方原文核对）：**2024 / 2025 / 2026** 三年，含全部「放假」与「调休上班」日期。

> 已知限制：iOS 上 App 与扩展各自拥有独立沙盒，未配置 App Group 时**小组件读不到 App 下载的缓存**，会回退到内置基线。若要两者共享，需为两个 target 配置同一 App Group 并改用共享容器路径（属后续项）。

### 5.3 历史上的今天

- 只收录**有公开、可查证记载**的史实，按年份升序展示；同一日期多条时全部列出；
- 覆盖 80+ 个日期；公历日期无收录时**不显示该卡片**（而不是显示空态）；
- 维护方式：往 `HistoryToday.swift` 的 `table` 里追加即可，无需改动任何视图代码。

### 5.4 无障碍（WCAG 2.1 AA）

- 全站文字使用 `scaledFont(...)`，字号同时响应**系统动态字体**与 App 内「大字体模式」；
- 日期格子提供完整 VoiceOver 朗读（公历 + 星期 + 今天 + 农历 + 节日 + 休/班）；
- 翻月、回今天等操作带触觉反馈；图标按钮均有 accessibility label；
- 文字与背景对比度 ≥ 4.5:1（正文）/ ≥ 3:1（大字）。

---

## 六、修改后如何重新生成工程

改了文件结构（新增/删除源文件）或 `project.yml` 后：

```bash
export USER=$(id -un) LOGNAME=$USER
xcodegen generate --spec project.yml
```

（`brew install xcodegen` 即可获得命令；本项目也验证过官方 release 二进制。）

---

## 七、后续版本计划（P2，本次未做）

- 日程增删改、iCloud 云同步账号
- 节日 / 宜忌轻量推送提醒
- 节气物候动效、生肖运势等趣味模块
- App Group：让小组件与主 App 共享远程更新的节假日数据
