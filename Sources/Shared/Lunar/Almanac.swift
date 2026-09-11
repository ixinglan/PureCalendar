import Foundation

/// 某一天的黄历（老黄历）信息。
struct AlmanacInfo: Hashable {
    let zhiXing: String        // 值日·建除十二神：建 / 除 / 满 / 平 / 定 / 执 / 破 / 危 / 成 / 收 / 开 / 闭
    let tianShen: String       // 值日天神：青龙 / 明堂 / 天刑…
    let isAuspiciousDay: Bool  // 是否黄道吉日
    let yi: [String]           // 宜
    let ji: [String]           // 忌
    let chong: String          // 冲，如「冲鼠(戊子)」
    let sha: String            // 煞，如「煞北」
    let pengZu: String         // 彭祖百忌
    let xiShen: String         // 喜神方位
    let caiShen: String        // 财神方位
    let fuShen: String         // 福神方位

    /// 「黄道吉日 / 黑道凶日」
    var luckText: String { isAuspiciousDay ? "黄道吉日" : "黑道凶日" }
}

/// 黄历计算引擎。
///
/// 说明：宜忌采用传统「建除十二神」体系推导；值日天神、彭祖百忌、吉神方位
/// 均按传统历法规则计算。数据层通过本类型集中管理，便于日后替换为权威黄历数据源。
enum Almanac {

    // MARK: - 数据表

    /// 十二建星（值日）。
    private static let jianChu = ["建", "除", "满", "平", "定", "执", "破", "危", "成", "收", "开", "闭"]

    /// 十二天神（含黄道/黑道）。
    private static let tianShenList = ["青龙", "明堂", "天刑", "朱雀", "金匮", "天德",
                                       "白虎", "玉堂", "天牢", "玄武", "司命", "勾陈"]
    /// 黄道吉神。
    private static let huangDao: Set<String> = ["青龙", "明堂", "金匮", "天德", "玉堂", "司命"]

    /// 月支 → 天神偏移。
    private static let tianShenOffset: [String: Int] = [
        "子": 4, "丑": 2, "寅": 0, "卯": 10, "辰": 8, "巳": 6,
        "午": 4, "未": 2, "申": 0, "酉": 10, "戌": 8, "亥": 6,
    ]

    /// 建除十二神 → (宜, 忌)。
    private static let yiJi: [String: (yi: [String], ji: [String])] = [
        "建": (["出行", "上任", "会友", "上书", "见工", "祭祀", "祈福"], ["动土", "开仓", "嫁娶", "乘船", "安葬"]),
        "除": (["除服", "疗病", "出行", "嫁娶", "解除", "扫舍"], ["求官", "上任", "开张", "搬家", "探病"]),
        "满": (["祈福", "祭祀", "结亲", "开市", "交易", "立契"], ["服药", "栽种", "下葬", "求医", "上任"]),
        "平": (["嫁娶", "修路", "涂泥", "安门", "开市", "动土"], ["开渠", "放水", "栽种", "造屋", "安葬"]),
        "定": (["祭祀", "祈福", "嫁娶", "造屋", "装修", "入学"], ["诉讼", "出行", "交涉", "移徙"]),
        "执": (["祈福", "祭祀", "嫁娶", "造屋", "买田", "捕捉"], ["开市", "出财", "搬家", "开仓"]),
        "破": (["破屋", "坏垣", "求医", "治病", "解除"], ["嫁娶", "开市", "动土", "出行", "入宅"]),
        "危": (["祭祀", "祈福", "安床", "嫁娶", "结网"], ["登高", "行船", "出行", "移徙"]),
        "成": (["嫁娶", "开市", "出行", "移徙", "入宅", "安床"], ["诉讼", "争斗", "破土"]),
        "收": (["祭祀", "嫁娶", "纳财", "捕捉", "进人口"], ["开市", "安床", "安葬", "出行"]),
        "开": (["祭祀", "祈福", "开市", "动土", "安床", "入学"], ["安葬", "破土", "词讼"]),
        "闭": (["筑堤", "埋穴", "填坑", "祭祀", "安葬"], ["开市", "出行", "求医", "开渠"]),
    ]

    /// 彭祖百忌·日干。
    private static let pengZuGan = [
        "甲不开仓财物耗散", "乙不栽植千株不长", "丙不修灶必见灾殃", "丁不剃头头必生疮", "戊不受田田主不祥",
        "己不破券二比并亡", "庚不经络织机虚张", "辛不合酱主人不尝", "壬不泱水更难提防", "癸不词讼理弱敌强",
    ]
    /// 彭祖百忌·日支。
    private static let pengZuZhi = [
        "子不问卜自惹祸殃", "丑不冠带主不还乡", "寅不祭祀神鬼不尝", "卯不穿井水泉不香", "辰不哭泣必主重丧", "巳不远行财物伏藏",
        "午不苫盖屋主更张", "未不服药毒气入肠", "申不安床鬼祟入房", "酉不会客醉坐颠狂", "戌不吃犬作怪上床", "亥不嫁娶不利新郎",
    ]

    /// 八卦 → 方位。
    private static let baguaDirection: [String: String] = [
        "坎": "正北", "艮": "东北", "震": "正东", "巽": "东南",
        "离": "正南", "坤": "西南", "兑": "正西", "乾": "西北",
    ]
    /// 吉神方位表（按日干，1-based 甲…癸）。
    private static let positionXi  = ["艮", "乾", "坤", "离", "巽", "艮", "乾", "坤", "离", "巽"]
    private static let positionCai = ["艮", "艮", "坤", "坤", "坎", "坎", "震", "震", "离", "离"]
    private static let positionFu  = ["巽", "巽", "震", "震", "坎", "离", "坤", "坤", "乾", "兑"]

    /// 三合局煞方：地支 index(0=子) → 煞。
    private static func shaDirection(dayZhiIndex d: Int) -> String {
        // 申子辰煞南、巳酉丑煞东、寅午戌煞北、亥卯未煞西
        switch d {
        case 8, 0, 4: return "煞南"
        case 5, 9, 1: return "煞东"
        case 2, 6, 10: return "煞北"
        default: return "煞西" // 11, 3, 7
        }
    }

    // MARK: - 计算

    /// 根据农历信息推导当日黄历。
    static func info(for lunar: LunarDate) -> AlmanacInfo {
        let dayZhi = String(lunar.ganZhiDay.suffix(1))
        let dayGan = String(lunar.ganZhiDay.prefix(1))
        let monthZhi = String(lunar.ganZhiMonth.suffix(1))

        let dayZhiIndex = LunarData.zhi.firstIndex(of: dayZhi) ?? 0        // 0=子 … 11=亥
        let dayGanIndex = LunarData.gan.firstIndex(of: dayGan) ?? 0        // 0=甲 … 9=癸
        let monthZhiIndex = LunarData.zhi.firstIndex(of: monthZhi) ?? 0

        // 值日·建除十二神
        var offset = dayZhiIndex - monthZhiIndex
        if offset < 0 { offset += 12 }
        let zhiXing = jianChu[offset % 12]

        // 值日·十二天神（黄道/黑道）
        let tOff = tianShenOffset[monthZhi] ?? 0
        let tianShen = tianShenList[(dayZhiIndex + tOff) % 12]

        // 宜 / 忌
        let pair = yiJi[zhiXing] ?? ([], [])

        // 冲煞
        let chongZhiIndex = (dayZhiIndex + 6) % 12
        let chongAnimal = LunarData.animals[chongZhiIndex]
        // 冲的干支：以「六冲」推算日支冲，配对应天干（传统写法如 冲鼠(戊子)）
        let chongGanZhi = ganZhiOf(zhiIndex: chongZhiIndex)
        let chong = "冲\(chongAnimal)(\(chongGanZhi))"
        let sha = shaDirection(dayZhiIndex: dayZhiIndex)

        // 彭祖百忌
        let pengZu = "\(pengZuGan[dayGanIndex]) · \(pengZuZhi[dayZhiIndex])"

        // 吉神方位
        let xi = baguaDirection[positionXi[dayGanIndex]] ?? "-"
        let cai = baguaDirection[positionCai[dayGanIndex]] ?? "-"
        let fu = baguaDirection[positionFu[dayGanIndex]] ?? "-"

        return AlmanacInfo(
            zhiXing: zhiXing,
            tianShen: tianShen,
            isAuspiciousDay: huangDao.contains(tianShen),
            yi: pair.yi,
            ji: pair.ji,
            chong: chong,
            sha: sha,
            pengZu: pengZu,
            xiShen: xi,
            caiShen: cai,
            fuShen: fu
        )
    }

    /// 取某地支对应的一个代表性干支（用于「冲」的展示）。
    private static func ganZhiOf(zhiIndex: Int) -> String {
        // 采用「天干与地支同阴阳」的对应关系，取一个常见组合即可满足展示需要。
        let ganIndex = zhiIndex % 10
        return LunarData.gan[ganIndex] + LunarData.zhi[zhiIndex]
    }
}
