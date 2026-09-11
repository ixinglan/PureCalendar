import Foundation

/// 一条「历史上的今天」史料。
struct HistoryEvent: Hashable, Identifiable {
    /// 事件年份（公元纪年）。
    let year: Int
    /// 事件内容，一句话概括。
    let text: String

    var id: String { "\(year)-\(text)" }

    /// 「1949 年」，用于列表左侧年份列。
    var yearText: String { "\(year) 年" }
}

/// 「历史上的今天」数据源。
///
/// ## 选材原则
/// - 只收录**有公开、可查证记载**的史实（成文于权威史书、官方文献、主流百科）；
/// - 同一日期多条时按年份升序排列；
/// - 不收录政治敏感、争议未定或无法核实的内容。
///
/// ## 维护方式
/// 数据以「公历月-日」为键（**不带前导零**，如 `"10-1"`），与 `HolidayPlan` 的口径保持一致。
/// 新增条目只需往 `table` 里追加，无需改动任何视图代码。
enum HistoryToday {

    /// 取某一天的史料（按年份升序）。无收录时返回空数组。
    static func events(on solar: SolarDate) -> [HistoryEvent] {
        let key = "\(solar.month)-\(solar.day)"
        return (table[key] ?? []).sorted { $0.year < $1.year }
    }

    /// 某一天是否有收录。
    static func hasEvents(on solar: SolarDate) -> Bool {
        !(table["\(solar.month)-\(solar.day)"] ?? []).isEmpty
    }

    /// 已收录的日期数量（用于设置页展示数据规模）。
    static var coveredDayCount: Int { table.count }

    // MARK: - 数据表

    private static let table: [String: [HistoryEvent]] = [
        // 一月
        "1-1": [
            HistoryEvent(year: 1863, text: "美国总统林肯签署的《解放奴隶宣言》正式生效"),
            HistoryEvent(year: 1912, text: "中华民国临时政府在南京成立，孙中山就任临时大总统"),
            HistoryEvent(year: 1999, text: "欧元正式启用，进入记账与电子支付阶段"),
        ],
        "1-3": [
            HistoryEvent(year: 2019, text: "嫦娥四号成功着陆月球背面，人类探测器首次实现月背软着陆"),
        ],
        "1-8": [
            HistoryEvent(year: 1976, text: "周恩来总理在北京逝世"),
        ],
        "1-9": [
            HistoryEvent(year: 2007, text: "苹果公司发布第一代 iPhone，智能手机时代开启"),
        ],
        "1-15": [
            HistoryEvent(year: 2001, text: "维基百科正式上线"),
        ],
        "1-27": [
            HistoryEvent(year: 1945, text: "苏联红军解放奥斯维辛集中营"),
        ],
        "1-28": [
            HistoryEvent(year: 1986, text: "美国「挑战者号」航天飞机升空 73 秒后爆炸"),
        ],
        "1-30": [
            HistoryEvent(year: 1948, text: "圣雄甘地在新德里遇刺身亡"),
        ],
        // 二月
        "2-4": [
            HistoryEvent(year: 2004, text: "Facebook 上线"),
        ],
        "2-11": [
            HistoryEvent(year: 1847, text: "发明家爱迪生出生"),
        ],
        "2-12": [
            HistoryEvent(year: 1809, text: "生物学家达尔文出生"),
        ],
        "2-19": [
            HistoryEvent(year: 1997, text: "邓小平在北京逝世"),
        ],
        "2-21": [
            HistoryEvent(year: 1972, text: "美国总统尼克松抵达北京，中美关系开始走向正常化"),
        ],
        "2-24": [
            HistoryEvent(year: 1955, text: "苹果公司创始人史蒂夫·乔布斯出生"),
        ],
        "2-28": [
            HistoryEvent(year: 1953, text: "沃森与克里克宣布发现 DNA 双螺旋结构"),
        ],
        // 三月
        "3-5": [
            HistoryEvent(year: 1898, text: "周恩来出生"),
        ],
        "3-8": [
            HistoryEvent(year: 1909, text: "美国芝加哥女工为争取权益举行大规模罢工与游行"),
            HistoryEvent(year: 1975, text: "联合国开始纪念「国际妇女节」"),
        ],
        "3-12": [
            HistoryEvent(year: 1925, text: "中国民主革命先行者孙中山在北京逝世"),
        ],
        "3-14": [
            HistoryEvent(year: 1879, text: "物理学家爱因斯坦出生"),
        ],
        "3-22": [
            HistoryEvent(year: 1993, text: "联合国大会确定每年 3 月 22 日为「世界水日」"),
        ],
        "3-28": [
            HistoryEvent(year: 1979, text: "美国三里岛核电站发生严重事故"),
        ],
        // 四月
        "4-1": [
            HistoryEvent(year: 1976, text: "史蒂夫·乔布斯与合伙人创立苹果公司"),
        ],
        "4-12": [
            HistoryEvent(year: 1961, text: "苏联宇航员加加林乘「东方一号」进入太空，成为首位进入太空的人"),
        ],
        "4-15": [
            HistoryEvent(year: 1912, text: "豪华邮轮「泰坦尼克号」撞冰山后沉没"),
        ],
        "4-23": [
            HistoryEvent(year: 1995, text: "联合国教科文组织确定每年 4 月 23 日为「世界读书日」"),
        ],
        "4-24": [
            HistoryEvent(year: 1970, text: "中国第一颗人造地球卫星「东方红一号」发射成功"),
        ],
        "4-26": [
            HistoryEvent(year: 1986, text: "苏联切尔诺贝利核电站发生严重事故"),
        ],
        // 五月
        "5-1": [
            HistoryEvent(year: 1886, text: "美国芝加哥工人举行大罢工，争取八小时工作制"),
            HistoryEvent(year: 1889, text: "第二国际决定以每年 5 月 1 日为国际劳动节"),
        ],
        "5-4": [
            HistoryEvent(year: 1919, text: "五四运动爆发"),
        ],
        "5-8": [
            HistoryEvent(year: 1945, text: "纳粹德国无条件投降，欧洲战场战事结束"),
        ],
        "5-12": [
            HistoryEvent(year: 1820, text: "现代护理学奠基人南丁格尔出生（后为国际护士节）"),
            HistoryEvent(year: 2008, text: "四川汶川发生特大地震"),
        ],
        "5-18": [
            HistoryEvent(year: 1980, text: "中国向南太平洋预定海域成功发射第一枚远程运载火箭"),
        ],
        "5-29": [
            HistoryEvent(year: 1953, text: "登山家希拉里与丹增·诺尔盖首次登上珠穆朗玛峰峰顶"),
        ],
        "5-30": [
            HistoryEvent(year: 1925, text: "五卅运动爆发"),
        ],
        // 六月
        "6-1": [
            HistoryEvent(year: 1950, text: "新中国迎来第一个国际儿童节"),
        ],
        "6-5": [
            HistoryEvent(year: 1972, text: "联合国人类环境会议在斯德哥尔摩开幕，后定 6 月 5 日为「世界环境日」"),
        ],
        "6-6": [
            HistoryEvent(year: 1944, text: "盟军在法国诺曼底实施登陆作战"),
        ],
        "6-17": [
            HistoryEvent(year: 1967, text: "中国第一颗氢弹爆炸成功"),
        ],
        "6-25": [
            HistoryEvent(year: 1950, text: "朝鲜战争爆发"),
        ],
        "6-26": [
            HistoryEvent(year: 1945, text: "《联合国宪章》在旧金山签署"),
        ],
        "6-30": [
            HistoryEvent(year: 1908, text: "俄罗斯西伯利亚发生通古斯大爆炸"),
        ],
        // 七月
        "7-1": [
            HistoryEvent(year: 1997, text: "中国政府对香港恢复行使主权"),
        ],
        "7-4": [
            HistoryEvent(year: 1776, text: "美国《独立宣言》在费城通过"),
        ],
        "7-7": [
            HistoryEvent(year: 1937, text: "卢沟桥事变爆发，中国全民族抗战开始"),
        ],
        "7-14": [
            HistoryEvent(year: 1789, text: "巴黎人民攻占巴士底狱，法国大革命爆发"),
        ],
        "7-16": [
            HistoryEvent(year: 1969, text: "美国「阿波罗 11 号」载人飞船发射升空"),
        ],
        "7-20": [
            HistoryEvent(year: 1969, text: "阿波罗 11 号登月舱在月球着陆，阿姆斯特朗成为首位踏上月球的人"),
        ],
        "7-23": [
            HistoryEvent(year: 1921, text: "中国共产党第一次全国代表大会在上海召开"),
        ],
        "7-28": [
            HistoryEvent(year: 1976, text: "河北唐山发生 7.8 级大地震"),
        ],
        // 八月
        "8-1": [
            HistoryEvent(year: 1927, text: "南昌起义爆发（后成为中国人民解放军建军节）"),
        ],
        "8-6": [
            HistoryEvent(year: 1945, text: "美国在日本广岛投下原子弹"),
        ],
        "8-8": [
            HistoryEvent(year: 2008, text: "第 29 届夏季奥林匹克运动会在北京开幕"),
        ],
        "8-15": [
            HistoryEvent(year: 1945, text: "日本宣布无条件投降"),
        ],
        "8-21": [
            HistoryEvent(year: 1911, text: "《蒙娜丽莎》在卢浮宫被盗，两年后失而复得"),
        ],
        "8-22": [
            HistoryEvent(year: 1904, text: "邓小平出生"),
        ],
        // 九月
        "9-1": [
            HistoryEvent(year: 1939, text: "德国入侵波兰，第二次世界大战全面爆发"),
        ],
        "9-2": [
            HistoryEvent(year: 1945, text: "日本签署投降书，第二次世界大战结束"),
        ],
        "9-3": [
            HistoryEvent(year: 1945, text: "中国人民抗日战争胜利纪念日"),
        ],
        "9-9": [
            HistoryEvent(year: 1976, text: "毛泽东在北京逝世"),
        ],
        "9-10": [
            HistoryEvent(year: 1985, text: "中国迎来第一个教师节"),
        ],
        "9-18": [
            HistoryEvent(year: 1931, text: "九一八事变爆发"),
        ],
        "9-25": [
            HistoryEvent(year: 2008, text: "神舟七号发射成功，翟志刚完成中国首次太空行走"),
        ],
        "9-27": [
            HistoryEvent(year: 1979, text: "世界旅游组织确定每年 9 月 27 日为「世界旅游日」"),
        ],
        // 十月
        "10-1": [
            HistoryEvent(year: 1949, text: "中华人民共和国成立"),
        ],
        "10-5": [
            HistoryEvent(year: 2011, text: "苹果公司联合创始人史蒂夫·乔布斯逝世"),
        ],
        "10-15": [
            HistoryEvent(year: 2003, text: "神舟五号发射成功，杨利伟成为首位进入太空的中国航天员"),
        ],
        "10-16": [
            HistoryEvent(year: 1964, text: "中国第一颗原子弹爆炸成功"),
        ],
        "10-21": [
            HistoryEvent(year: 1879, text: "爱迪生试制出第一盏有实用价值的白炽灯"),
        ],
        "10-24": [
            HistoryEvent(year: 1945, text: "《联合国宪章》生效，联合国正式成立（联合国日）"),
        ],
        // 十一月
        "11-9": [
            HistoryEvent(year: 1989, text: "柏林墙倒塌"),
        ],
        "11-11": [
            HistoryEvent(year: 1918, text: "第一次世界大战停战协定生效"),
        ],
        "11-12": [
            HistoryEvent(year: 1866, text: "中国民主革命先行者孙中山出生"),
        ],
        "11-22": [
            HistoryEvent(year: 1963, text: "美国总统肯尼迪在达拉斯遇刺身亡"),
        ],
        "11-24": [
            HistoryEvent(year: 1859, text: "达尔文《物种起源》正式出版"),
        ],
        "11-26": [
            HistoryEvent(year: 1789, text: "美国庆祝第一个感恩节"),
        ],
        // 十二月
        "12-1": [
            HistoryEvent(year: 1988, text: "首个「世界艾滋病日」"),
        ],
        "12-7": [
            HistoryEvent(year: 1941, text: "日本偷袭珍珠港，太平洋战争爆发"),
        ],
        "12-10": [
            HistoryEvent(year: 1901, text: "首届诺贝尔奖颁发"),
        ],
        "12-11": [
            HistoryEvent(year: 2001, text: "中国正式加入世界贸易组织"),
        ],
        "12-13": [
            HistoryEvent(year: 1937, text: "侵华日军攻陷南京并开始大屠杀（后为国家公祭日）"),
        ],
        "12-17": [
            HistoryEvent(year: 1903, text: "莱特兄弟完成人类首次有动力、可操控的飞机试飞"),
        ],
        "12-20": [
            HistoryEvent(year: 1999, text: "中国政府对澳门恢复行使主权"),
        ],
        "12-22": [
            HistoryEvent(year: 1808, text: "贝多芬《第五交响曲》在维也纳首演"),
        ],
        "12-25": [
            HistoryEvent(year: 1991, text: "苏联宣告解体"),
        ],
        "12-26": [
            HistoryEvent(year: 1893, text: "毛泽东出生"),
        ],
    ]
}
