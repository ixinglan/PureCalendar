import Foundation

// MARK: - 数据模型

/// 某一天在国务院年度节假日安排中的状态。
enum DayOffKind: String, Codable, Hashable {
    /// 放假（休）。
    case holiday
    /// 调休上班（班）——通常是周六/周日却要上班。
    case workday

    /// 角标文字：休 / 班。
    var badge: String { self == .holiday ? "休" : "班" }
}

/// 一个年度的法定节假日（放假 / 调休）安排。
///
/// 数据口径与国务院办公厅《关于 XXXX 年部分节假日安排的通知》一致：
/// `days` 以 `"月-日"`（**不带前导零**，如 `"2-15"`）为键，值为 `.holiday`（放假）或 `.workday`（调休上班）。
///
/// 说明：**普通周末不收录**——「周六周日是否休息」由日历规则直接推断，
/// 只有被国务院通知特别点名（放假或调休上班）的日期才写进 `days`，从而避免数据冗余与不一致。
struct HolidayPlan: Codable, Hashable {
    /// 年份。
    let year: Int
    /// 数据来源（公文标题或发文字号），用于溯源与审计。
    let source: String
    /// 发布日期（`yyyy-MM-dd`），用于判断新旧版本。
    let publishedAt: String
    /// 逐日状态。
    let days: [String: DayOffKind]

    /// 取某一天的安排状态。
    func kind(for solar: SolarDate) -> DayOffKind? {
        days["\(solar.month)-\(solar.day)"]
    }

    /// 该年度放假的自然日数量（含与周末重叠的部分）。
    var holidayCount: Int { days.values.filter { $0 == .holiday }.count }
}

/// 远程 / 缓存使用的数据包（`.json` 顶层结构）。
struct HolidayPayload: Codable {
    let schemaVersion: Int
    let updatedAt: String
    let plans: [HolidayPlan]
}

/// 一次远程更新的结果。
enum HolidayUpdateResult: Equatable {
    /// 更新成功。
    case updated(years: [Int], updatedAt: String)
    /// 本地已是最新，无需更新。
    case unchanged(updatedAt: String)

    /// 用于 UI 展示的文案。
    var message: String {
        switch self {
        case .updated(let years, _):
            return "已更新：\(years.map(String.init).joined(separator: "、")) 年"
        case .unchanged:
            return "已是最新数据"
        }
    }
}

/// 更新过程中的错误。
enum HolidayStoreError: LocalizedError {
    case notConfigured
    case invalidURL(String)
    case badStatus(Int)
    case decodeFailed(String)
    case cacheWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "未配置远程更新地址（Info.plist 的 HolidayPlansURL 为空）"
        case .invalidURL(let raw):
            return "更新地址无效：\(raw)"
        case .badStatus(let code):
            return "服务器返回状态码 \(code)"
        case .decodeFailed(let msg):
            return "数据解析失败：\(msg)"
        case .cacheWriteFailed(let msg):
            return "写入本地缓存失败：\(msg)"
        }
    }
}

// MARK: - 年度更新机制

/// 节假日**年度更新机制**。
///
/// ## 为什么需要它
/// 放假/调休安排由国务院办公厅**逐年**公布（一般在前一年 11 月前后）。如果把它写死在代码里，
/// 每年都必须重新提交一个 App 版本，否则用户看到的就是**过时且错误**的调休信息。
///
/// ## 机制（三级数据源，后者覆盖前者）
/// 1. **内置基线** `holiday-plans.json`（随包发布，保证首启与离线可用）；
/// 2. **本地缓存** `Application Support/CalendarApp/HolidayPlans.json`（上一次远程更新的结果）；
/// 3. **远程数据** 由 `Info.plist` 的 `HolidayPlansURL` 配置，结构同上。
///
/// 读取顺序为「缓存 > 内置」；`refreshFromRemote()` 负责拉取并落盘。
/// 同一年份若同时存在，取 `publishedAt` 较新者。
///
/// ## 优雅降级
/// 任何一年缺失数据时返回 `nil`，由上层退回「仅标注节日性质、不显示调休」的行为，
/// **绝不猜测、绝不使用过时数据**。
enum HolidayStore {

    /// 当前 App 支持的 schema 版本。远程数据版本高于它时拒绝加载，避免新字段导致解析歧义。
    static let currentSchemaVersion = 1

    // MARK: 读取

    /// 并发保护：App 与 Widget 都可能在任意线程首次读取。
    private static let lock = NSLock()
    private static var resolvedPlans: [Int: HolidayPlan]?

    /// 年度 → 安排（已合并内置与缓存）。
    static var plans: [Int: HolidayPlan] {
        lock.lock()
        defer { lock.unlock() }
        if let resolvedPlans { return resolvedPlans }
        let merged = merge(bundled: loadBundled(), cache: loadCache()?.plans ?? [])
        resolvedPlans = merged
        return merged
    }

    /// 全部可用年度安排（按年份升序）。
    static var allPlans: [HolidayPlan] {
        plans.values.sorted { $0.year < $1.year }
    }

    /// 取某一天的放假/调休状态；该年无数据时返回 `nil`。
    static func kind(for solar: SolarDate) -> DayOffKind? {
        plans[solar.year]?.kind(for: solar)
    }

    /// 是否为「调休上班日」（周末却要上班）。
    static func isAdjustedWorkday(_ solar: SolarDate) -> Bool {
        kind(for: solar) == .workday
    }

    /// 设置页展示用的数据概览。
    static var summary: String {
        let years = allPlans.map(\.year)
        guard let first = years.first, let last = years.last else {
            return "暂无年度安排数据"
        }
        let span = first == last ? "\(first)" : "\(first)–\(last)"
        return "已收录 \(years.count) 个年度（\(span)）"
    }

    /// 缓存数据的更新时间戳（无缓存时回退到内置数据时间）。
    static var dataTimestamp: String {
        loadCache()?.updatedAt ?? loadBundledPayload().updatedAt
    }

    /// 是否存在远程下载的缓存（设置页据此决定是否显示「恢复内置数据」）。
    static var hasCachedData: Bool { loadCache() != nil }

    /// Info.plist 中配置的远程 JSON 地址（为空 / 未配置表示不启用远程更新）。
    static var remoteURLString: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "HolidayPlansURL") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: 远程更新

    /// 从远程拉取最新安排并写入本地缓存。
    ///
    /// - Returns: 更新结果（`.updated` / `.unchanged`）。
    /// - Throws: `HolidayStoreError`。
    @discardableResult
    static func refreshFromRemote() async throws -> HolidayUpdateResult {
        guard let raw = remoteURLString else { throw HolidayStoreError.notConfigured }
        guard let url = URL(string: raw) else { throw HolidayStoreError.invalidURL(raw) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HolidayStoreError.badStatus(http.statusCode)
        }

        let payload: HolidayPayload
        do {
            payload = try JSONDecoder().decode(HolidayPayload.self, from: data)
        } catch {
            throw HolidayStoreError.decodeFailed(error.localizedDescription)
        }

        guard payload.schemaVersion <= currentSchemaVersion else {
            throw HolidayStoreError.decodeFailed("远程数据版本 \(payload.schemaVersion) 高于当前 App 支持的 \(currentSchemaVersion)")
        }

        // 版本比较：远程没有比本地缓存更新时，不覆盖。
        if let cached = loadCache(), cached.updatedAt >= payload.updatedAt {
            return .unchanged(updatedAt: cached.updatedAt)
        }

        try writeCache(payload)
        resetResolved()

        return .updated(years: payload.plans.map(\.year).sorted(), updatedAt: payload.updatedAt)
    }

    /// 清空本地缓存（回到纯内置数据），用于调试与「恢复默认」。
    static func clearCache() {
        if let url = cacheFileURL { try? FileManager.default.removeItem(at: url) }
        resetResolved()
    }

    /// 强制重新读取磁盘数据。
    static func invalidate() {
        resetResolved()
    }

    /// 丢弃已解析的合并结果，使下次读取重新计算。
    ///
    /// 单独抽成同步函数：`NSLock.lock()/unlock()` 在 async 上下文中会触发
    /// 「not available from asynchronous contexts」警告（Swift 6 下是错误）。
    private static func resetResolved() {
        lock.lock()
        defer { lock.unlock() }
        resolvedPlans = nil
    }

    // MARK: 私有：加载与合并

    /// 合并规则：以内置为底，缓存中更新（`publishedAt` 更晚）的年度覆盖内置。
    private static func merge(bundled: [HolidayPlan], cache: [HolidayPlan]) -> [Int: HolidayPlan] {
        var result: [Int: HolidayPlan] = [:]
        for plan in bundled { result[plan.year] = plan }
        for plan in cache {
            if let existing = result[plan.year] {
                if plan.publishedAt >= existing.publishedAt { result[plan.year] = plan }
            } else {
                result[plan.year] = plan
            }
        }
        return result
    }

    private static func loadBundledPayload() -> HolidayPayload {
        guard let url = Bundle.main.url(forResource: "holiday-plans", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return HolidayPayload(schemaVersion: currentSchemaVersion, updatedAt: "", plans: [])
        }
        return decode(data)
    }

    private static func loadBundled() -> [HolidayPlan] { loadBundledPayload().plans }

    private static func decode(_ data: Data) -> HolidayPayload {
        (try? JSONDecoder().decode(HolidayPayload.self, from: data))
            ?? HolidayPayload(schemaVersion: currentSchemaVersion, updatedAt: "", plans: [])
    }

    /// 缓存文件所在目录：`Application Support/CalendarApp/HolidayPlans.json`。
    ///
    /// 注意：App 与其扩展（小组件）在 iOS 上各自拥有独立沙盒，除非配置 App Group，
    /// 否则**小组件读不到 App 写入的缓存**，会回退到内置数据。
    /// 若需两者共享，请为两个 target 配置同一个 App Group 并改用共享容器路径。
    private static var cacheFileURL: URL? {
        let fm = FileManager.default
        guard let base = try? fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil,
                                     create: true) else { return nil }
        let dir = base.appendingPathComponent("CalendarApp", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("HolidayPlans.json")
    }

    private static func loadCache() -> HolidayPayload? {
        guard let url = cacheFileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let payload = decode(data)
        return payload.plans.isEmpty ? nil : payload
    }

    private static func writeCache(_ payload: HolidayPayload) throws {
        guard let url = cacheFileURL else {
            throw HolidayStoreError.cacheWriteFailed("无法定位缓存目录")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            throw HolidayStoreError.cacheWriteFailed(error.localizedDescription)
        }
    }
}
