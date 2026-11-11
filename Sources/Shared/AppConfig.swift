import Foundation

/// 应用级全局配置：集中管理服务端地址等常量。
///
/// 设计初衷：隐私政策页、节假日更新接口等服务端资源共用同一个域名，
/// 若域名发生迁移（例如从 blog 换到 pet），只需改这里的 `host` 一个常量即可全局生效，
/// 无需再去 Info.plist 或各处代码里逐个查找替换。
enum AppConfig {
    /// 服务端域名（不含协议与路径）。
    /// 隐私政策与节假日接口都挂在这个域名下，改这一处即可。
    static let host = "pet.zhaojq.top"

    /// 隐私政策页完整地址（设置 → 关于 里的入口点击后打开）。
    static let privacyURL = URL(string: "https://\(host)/calendar/privacy.html")

    /// 节假日远程更新接口地址（用于「检查更新」，失败时回退内置数据）。
    static let holidayPlansURL = URL(string: "https://\(host)/calendar/holiday-plans.json")
}
