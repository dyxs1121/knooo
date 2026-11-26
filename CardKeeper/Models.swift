import Foundation

// MARK: - 账单流水

struct Transaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var merchant: String
    var category: String
    var amount: Double
    var date: Date
}

// MARK: - 快捷指令传入的支付参数

/// 快捷指令通过 URL Scheme 调起 App：
/// cardkeeper://record?card=尾号或名称&amount=12.5&merchant=星巴克&category=餐饮
struct QuickPayment: Identifiable {
    var id = UUID()
    /// 卡片线索：支持尾号 / 卡名 / 银行名，为空则打开后手动选
    var cardQuery: String = ""
    var amount: Double = 0
    var merchant: String = ""
    var category: String = ""

    static func from(url: URL) -> QuickPayment? {
        guard url.scheme?.lowercased() == "cardkeeper" else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var p = QuickPayment()
        for item in comps.queryItems ?? [] {
            switch item.name {
            case "card": p.cardQuery = item.value ?? ""
            case "amount": p.amount = Double(item.value ?? "") ?? 0
            case "merchant": p.merchant = item.value ?? ""
            case "category", "note": p.category = item.value ?? ""
            default: break
            }
        }
        return p
    }
}

// MARK: - 活动

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case count
    case amount
    case once

    var id: String { rawValue }

    var label: String {
        switch self {
        case .count: return "按次数"
        case .amount: return "按金额"
        case .once: return "单次完成"
        }
    }

    var shortLabel: String {
        switch self {
        case .count: return "次数"
        case .amount: return "金额"
        case .once: return "单次"
        }
    }
}

enum RemindRule: String, Codable, CaseIterable, Identifiable {
    case weeklySunday = "每周日 20:00"
    case weeklyFriday = "每周五 08:00"
    case monthlyFirst = "每月 1 日 09:00"
    case daily = "每天 09:00"
    case dayBefore = "截止前 1 天 09:00"
    case precise = "指定时间（抢购）"
    case none = "不提醒"

    var id: String { rawValue }
}

struct ActivityStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var done: Bool
}

struct Activity: Identifiable, Codable, Hashable {
    var id = UUID()
    var cardID: UUID
    var title: String
    var detail: String
    var kind: ActivityKind
    var target: Double
    var current: Double = 0
    var deadline: Date
    var remind: RemindRule = .weeklySunday
    var steps: [ActivityStep] = []
    /// 预期收益（银行/平台承诺的奖励金额）
    var reward: Double = 0
    /// 已到账收益（实际收到的金额）
    var earned: Double = 0
    /// 指定时间提醒（抢购场景），配合 remind == .precise 使用
    var alertAt: Date? = nil
    /// 抢购提醒提前分钟数
    var leadMinutes: Int = 0
    /// 活动所属月份（yyyy-MM），月份筛选与跨月快捷添加用；为空时按截止日所在月显示
    var periodMonth: String? = nil

    // MARK: 兼容旧数据

    private enum CodingKeys: String, CodingKey {
        case id, cardID, title, detail, kind, target, current, deadline, remind, steps
        case reward, earned, alertAt, leadMinutes, periodMonth
    }

    init(cardID: UUID, title: String, detail: String, kind: ActivityKind, target: Double,
         current: Double = 0, deadline: Date, remind: RemindRule = .weeklySunday,
         reward: Double = 0, earned: Double = 0,
         alertAt: Date? = nil, leadMinutes: Int = 0,
         steps: [ActivityStep] = []) {
        self.cardID = cardID
        self.title = title
        self.detail = detail
        self.kind = kind
        self.target = target
        self.current = current
        self.deadline = deadline
        self.remind = remind
        self.steps = steps
        self.reward = reward
        self.earned = earned
        self.alertAt = alertAt
        self.leadMinutes = leadMinutes
    }

    /// 旧版本保存的活动没有 reward / earned / alertAt 等字段，这里逐项容错，避免整份数据解码失败
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try c.decode(UUID.self, forKey: .cardID)
        title = try c.decode(String.self, forKey: .title)
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        kind = try c.decode(ActivityKind.self, forKey: .kind)
        target = try c.decode(Double.self, forKey: .target)
        current = try c.decodeIfPresent(Double.self, forKey: .current) ?? 0
        deadline = try c.decode(Date.self, forKey: .deadline)
        remind = try c.decodeIfPresent(RemindRule.self, forKey: .remind) ?? .weeklySunday
        steps = try c.decodeIfPresent([ActivityStep].self, forKey: .steps) ?? []
        reward = try c.decodeIfPresent(Double.self, forKey: .reward) ?? 0
        earned = try c.decodeIfPresent(Double.self, forKey: .earned) ?? 0
        alertAt = try c.decodeIfPresent(Date.self, forKey: .alertAt)
        leadMinutes = try c.decodeIfPresent(Int.self, forKey: .leadMinutes) ?? 0
        periodMonth = try c.decodeIfPresent(String.self, forKey: .periodMonth)
    }

    var doneCount: Int { steps.filter { $0.done }.count }

    /// 提醒文案（指定时间时显示到分钟）
    var remindText: String {
        if remind == .precise, let at = alertAt {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M月d日 HH:mm"
            if leadMinutes > 0 {
                return "抢购提醒 " + f.string(from: at) + "（提前 \(leadMinutes) 分钟）"
            }
            return "抢购提醒 " + f.string(from: at)
        }
        return remind.rawValue
    }

    /// 进度值：金额型用累加金额，其余用已打卡次数
    var value: Double {
        kind == .amount ? current : Double(doneCount)
    }

    var isDone: Bool { value >= target - 0.0001 }

    var ratio: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, value / target))
    }

    var percentText: String { "\(Int((ratio * 100).rounded()))%" }

    var remainText: String {
        if kind == .amount {
            return "还差 " + Fmt.yuan(max(0, target - value))
        }
        return "\(Int(value)) / \(Int(target)) 次"
    }
}

// MARK: - 年费

struct CardFee: Codable, Hashable {
    /// 年费金额（0 表示免年费卡）
    var amount: Double = 0
    /// 免年费规则：一年内刷满多少笔（0 表示不按笔数）
    var waiveCount: Int = 0
    /// 免年费规则：一年内刷满多少金额（0 表示不按金额）
    var waiveAmount: Double = 0
    /// 年费扣取月份 / 日期
    var month: Int = 12
    var day: Int = 1
    /// 到期提醒
    var remind: Bool = true
    var remindDays: Int = 30
    /// 达标进度是否手动填写（否则按本期账单自动估算）
    var manualMode: Bool = false
    var manualCount: Int = 0
    var manualAmount: Double = 0

    var isFreeCard: Bool { amount <= 0 }
    /// 是否配置了免年费规则
    var hasRule: Bool { waiveCount > 0 || waiveAmount > 0 }

    /// 规则说明，如「刷 6 笔 或 刷满 ¥20,000」
    var ruleText: String {
        var parts: [String] = []
        if waiveCount > 0 { parts.append("刷 \(waiveCount) 笔") }
        if waiveAmount > 0 { parts.append("刷满 " + Fmt.yuan(waiveAmount)) }
        if parts.isEmpty { return "无免年费规则" }
        return parts.joined(separator: " 或 ")
    }
}

// MARK: - 信用卡

struct CreditCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var bank: String
    var name: String
    var org: String
    var last4: String
    var limit: Double
    var used: Double
    var billDay: Int
    var dueDay: Int
    var paid: Double
    var colorA: String
    var colorB: String
    var remind: Bool
    var remindDays: Int
    var items: [Transaction]
    /// 卡面主题 id（内置主题库）；可选字段保证旧数据解码兼容
    var theme: String? = nil
    /// 自定义卡面照片（压缩后的 JPEG）；优先于主题渐变显示
    var photoData: Data? = nil
    /// 归属人分类（自定义，如 本人 / 父亲 / 母亲）；为空表示未分类
    var owner: String? = nil
    /// 附属卡：指向主卡 id。为 nil 表示这是主卡；非 nil 时额度与主卡共享，且不单独计入总授信
    var supplementaryTo: UUID? = nil
    /// 刷卡金/返现收入记录；可选字段保证旧数据解码兼容
    var cashbacks: [Cashback]? = nil
    /// 年费与免年费规则（可选，旧数据为 nil 视为无年费）
    var fee: CardFee? = nil
    /// 账单日前一天提醒（可选，旧数据默认开启）
    var billRemindBefore: Bool? = nil

    /// 年费信息（未设置时返回默认值）
    var feeInfo: CardFee { fee ?? CardFee() }
    /// 账单日前一天是否提醒（默认开启）
    var billRemindBeforeOn: Bool { billRemindBefore ?? true }

    /// 是否附属卡
    var isSupplementary: Bool { supplementaryTo != nil }

    var short: String {
        let s = bank.replacingOccurrences(of: "银行", with: "")
        return s.isEmpty ? bank : s
    }

    var billTotal: Double { items.reduce(0) { $0 + $1.amount } }

    var cashbackList: [Cashback] { cashbacks ?? [] }

    /// 当前账单周期起点 = 最近一个已过的账单日（本月账单日未到则取上月同日）
    var cycleStart: Date {
        let today = DateHelp.cal.startOfDay(for: Date())
        var c = DateHelp.cal.dateComponents([.year, .month], from: today)
        c.day = min(max(billDay, 1), 28)
        let d = DateHelp.cal.date(from: c) ?? today
        if d <= today { return d }
        return DateHelp.cal.date(byAdding: .month, value: -1, to: d) ?? d
    }

    /// 本账单周期内获得的刷卡金合计（自动抵扣本期应还）
    var cycleCashback: Double {
        let start = DateHelp.cal.startOfDay(for: cycleStart)
        return cashbackList
            .filter { DateHelp.cal.startOfDay(for: $0.date) >= start }
            .reduce(0) { $0 + $1.amount }
    }

    var outstanding: Double { max(0, billTotal - paid - cycleCashback) }

    var isCleared: Bool { outstanding < 0.005 }

    var usedRatio: Double { limit > 0 ? min(1, used / limit) : 0 }

    var dueLabel: String {
        if isCleared { return "本期已结清" }
        let d = DateHelp.daysToDue(dueDay)
        if d <= 0 { return "今天还款" }
        if d == 1 { return "明天还款" }
        return "\(d) 天后还款"
    }

    static var empty: CreditCard {
        CreditCard(bank: "", name: "", org: "银联", last4: "", limit: 30000, used: 0,
                   billDay: 10, dueDay: 28, paid: 0, colorA: "1B1D2B", colorB: "3B4067",
                   remind: true, remindDays: 3, items: [])
    }
}

// MARK: - 收益记录

/// 一笔活动到账记录（一个活动可以多次到账，用于逐笔查看）
struct Earning: Identifiable, Codable, Hashable {
    var id = UUID()
    var activityID: UUID
    var amount: Double
    var date: Date
    var note: String = ""
}

/// 一笔刷卡金/返现收入（自动抵扣该卡本期应还）
struct Cashback: Identifiable, Codable, Hashable {
    var id = UUID()
    var amount: Double
    var date = Date()
    var note: String = ""
}

// MARK: - 设置

struct AppSettings: Codable {
    var billPush: Bool = true
    var actPush: Bool = true
    var quietHours: Bool = true
}

// MARK: - 数据仓库

final class Store: ObservableObject {

    @Published var cards: [CreditCard] = []
    @Published var activities: [Activity] = []
    @Published var settings = AppSettings()
    /// 自定义归属人类别（如 本人 / 父亲），侧滑栏据此筛选卡片
    @Published var owners: [String] = ["本人"]
    /// 活动收益的每一笔到账记录
    @Published var earnings: [Earning] = []

    private let storageKey = "cardkeeper.state.v1"

    struct Snapshot: Codable {
        var cards: [CreditCard]
        var activities: [Activity]
        var settings: AppSettings
        /// 可选：旧版本数据没有这个字段，解码为 nil
        var owners: [String]? = nil
        var earnings: [Earning]? = nil
    }

    init() {
        let loaded = load()
        if !loaded { seed() }
    }

    // MARK: 读写

    @discardableResult
    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return false
        }
        cards = snap.cards
        activities = snap.activities
        settings = snap.settings
        earnings = snap.earnings ?? []
        if let saved = snap.owners, !saved.isEmpty {
            owners = saved
        }
        normalizeOwners()
        normalizeSupplementary()
        migrateEarnings()
        return true
    }

    func save() {
        let snap = Snapshot(cards: cards, activities: activities, settings: settings,
                            owners: owners, earnings: earnings)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// 保证类别列表非空，且每张卡的归属人都落在列表内
    private func normalizeOwners() {
        if owners.isEmpty { owners = ["本人"] }
        for i in cards.indices {
            if let o = cards[i].owner, !o.isEmpty {
                if !owners.contains(o) { owners.append(o) }
            } else {
                cards[i].owner = owners.first
            }
        }
    }

    /// 清理指向已不存在卡片的附属关系（旧数据 / 手动改库后可能残留）
    private func normalizeSupplementary() {
        let ids = Set(cards.map { $0.id })
        for i in cards.indices {
            if let pid = cards[i].supplementaryTo {
                if !ids.contains(pid) || pid == cards[i].id {
                    cards[i].supplementaryTo = nil
                }
            }
        }
    }

    // MARK: 派生

    var totalOutstanding: Double { cards.reduce(0) { $0 + $1.outstanding } }
    var totalBill: Double { cards.reduce(0) { $0 + $1.billTotal } }
    var totalPaid: Double { cards.reduce(0) { $0 + $1.paid } }
    var totalUsed: Double { cards.reduce(0) { $0 + $1.used } }

    /// 总授信：额度按「组」计算 —— 同银行多张主卡共享一条额度（取最高），附属卡并入主卡那一组，不做叠加
    var totalLimit: Double {
        Set(cards.map { limitGroupKey($0) }).reduce(0) { $0 + groupLimit($1) }
    }
    /// 总可用 = 总授信 - 总已用
    var totalAvailable: Double { max(0, totalLimit - totalUsed) }

    var paidRatio: Double {
        totalBill > 0 ? min(1, totalPaid / totalBill) : 0
    }

    var nearestCard: CreditCard? {
        cards.filter { !$0.isCleared }
            .sorted { DateHelp.daysToDue($0.dueDay) < DateHelp.daysToDue($1.dueDay) }
            .first
    }

    func card(_ id: UUID) -> CreditCard? {
        cards.first { $0.id == id }
    }

    // MARK: 共享额度（同银行多卡 + 附属卡共享主卡额度）

    /// 银行归一化：忽略「银行」后缀、全半角空格与首尾空白，"招商" 与 "招商银行" 视为同一家
    func bankKey(_ bank: String) -> String {
        let k = bank
            .replacingOccurrences(of: "银行", with: "")
            .replacingOccurrences(of: "信用卡", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return k.isEmpty ? bank.trimmingCharacters(in: .whitespacesAndNewlines) : k
    }

    /// 追溯主卡链的根（附属卡 → 主卡 → 若主卡本身也是附属卡则继续向上，最多 8 层防脏数据成环）
    func limitAnchor(for card: CreditCard) -> CreditCard {
        var cur = card
        var hops = 0
        while let pid = cur.supplementaryTo, hops < 8 {
            guard let parent = self.card(pid) else { break }
            cur = parent
            hops += 1
        }
        return cur
    }

    /// 额度组 key：附属卡一律并入主卡所在银行的那一组
    func limitGroupKey(_ card: CreditCard) -> String {
        bankKey(limitAnchor(for: card).bank)
    }

    /// 某个额度组的共享总额度 = 组内「主卡」中填写的最高额度（附属卡不参与决定）
    func groupLimit(_ key: String) -> Double {
        let members = cards.filter { limitGroupKey($0) == key }
        let primaries = members.filter { $0.supplementaryTo == nil }
        if !primaries.isEmpty {
            return primaries.map { $0.limit }.max() ?? 0
        }
        return members.map { $0.limit }.max() ?? 0
    }

    /// 某银行的共享总额度（含附属卡所在组）
    func sharedLimit(forBank bank: String) -> Double {
        groupLimit(bankKey(bank))
    }

    /// 某额度组全部卡的合计已用（主卡与附属卡的消费都占用同一条额度）
    func bankUsed(forBank bank: String) -> Double {
        let key = bankKey(bank)
        return cards.filter { limitGroupKey($0) == key }.reduce(0) { $0 + $1.used }
    }

    /// 某张卡所在组的剩余可用额度
    func bankAvailable(for card: CreditCard) -> Double {
        let key = limitGroupKey(card)
        return max(0, groupLimit(key) - bankUsed(forBank: key))
    }

    /// 某张卡所在组占共享额度的比例
    func sharedUsedRatio(for card: CreditCard) -> Double {
        let key = limitGroupKey(card)
        let l = groupLimit(key)
        return l > 0 ? min(1, bankUsed(forBank: key) / l) : 0
    }

    /// 可被选为主卡的卡片（排除附属卡本身，避免链式附属）
    func primaryCandidates(excluding id: UUID?) -> [CreditCard] {
        cards.filter { $0.supplementaryTo == nil && $0.id != id }
    }

    /// 某张主卡名下的附属卡
    func supplements(of primaryID: UUID) -> [CreditCard] {
        cards.filter { $0.supplementaryTo == primaryID }
    }

    struct BankLimit: Identifiable {
        var id: String
        var name: String
        var count: Int
        var limit: Double
        var used: Double
        /// 组内附属卡数量
        var supplementary: Int = 0
        var ratio: Double { limit > 0 ? min(1, used / limit) : 0 }
        var available: Double { max(0, limit - used) }
    }

    /// 按额度组汇总（同银行多卡、主附卡都只算一次，用于统计页展示）
    var bankLimits: [BankLimit] {
        var order: [String] = []
        var names: [String: String] = [:]
        for c in cards {
            let k = limitGroupKey(c)
            if !order.contains(k) {
                order.append(k)
                names[k] = limitAnchor(for: c).bank
            }
        }
        return order.map { k in
            let same = cards.filter { limitGroupKey($0) == k }
            return BankLimit(id: k,
                             name: names[k] ?? k,
                             count: same.count,
                             limit: groupLimit(k),
                             used: bankUsed(forBank: k),
                             supplementary: same.filter { $0.supplementaryTo != nil }.count)
        }
    }

    func cardName(_ id: UUID) -> String {
        guard let c = card(id) else { return "未知卡片" }
        return c.short + " ••" + c.last4
    }

    /// 附属卡的角标文案，如「附属 · 招商 ••4832」；主卡返回 nil
    func supplementaryLabel(for card: CreditCard) -> String? {
        guard let pid = card.supplementaryTo, let p = self.card(pid) else { return nil }
        return "附属 · " + p.short + " ••" + p.last4
    }

    // MARK: 归属人分类

    /// 卡片归属人（未设置时归到第一个类别）
    func ownerName(of card: CreditCard) -> String {
        if let o = card.owner, !o.isEmpty { return o }
        return owners.first ?? "本人"
    }

    /// 按归属人筛选（nil = 全部）
    func ownedCards(_ owner: String?) -> [CreditCard] {
        guard let owner = owner else { return cards }
        return cards.filter { ownerName(of: $0) == owner }
    }

    /// 展示顺序：主卡在前，其附属卡紧跟其后
    func sortedForDisplay(_ list: [CreditCard]) -> [CreditCard] {
        var result: [CreditCard] = []
        var placed = Set<UUID>()

        for c in list where c.supplementaryTo == nil && !placed.contains(c.id) {
            result.append(c)
            placed.insert(c.id)
            for s in list where s.supplementaryTo == c.id && !placed.contains(s.id) {
                result.append(s)
                placed.insert(s.id)
            }
        }
        // 兜底：主卡不在当前筛选结果里的附属卡，仍要显示
        for c in list where !placed.contains(c.id) {
            result.append(c)
            placed.insert(c.id)
        }
        return result
    }

    func addOwner(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !owners.contains(n) else { return }
        owners.append(n)
        save()
    }

    /// 重命名类别：为空或重复时自动合并到已有类别
    func renameOwner(at index: Int, to newName: String) {
        guard owners.indices.contains(index) else { return }
        let n = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        let old = owners[index]
        guard old != n else { return }
        if owners.contains(n) {
            // 合并到已有类别
            for i in cards.indices where ownerName(of: cards[i]) == old {
                cards[i].owner = n
            }
            owners.remove(at: index)
        } else {
            owners[index] = n
            for i in cards.indices where ownerName(of: cards[i]) == old {
                cards[i].owner = n
            }
        }
        save()
    }

    /// 删除类别：其下卡片转移到剩余的第一个类别
    func deleteOwner(at index: Int) {
        guard owners.indices.contains(index), owners.count > 1 else { return }
        let old = owners[index]
        owners.remove(at: index)
        let fallback = owners.first ?? "本人"
        for i in cards.indices where ownerName(of: cards[i]) == old {
            cards[i].owner = fallback
        }
        save()
    }

    // MARK: 活动分组与收益

    struct ActivityGroup: Identifiable {
        var id: UUID
        var card: CreditCard?
        var acts: [Activity]
        var earned: Double { acts.reduce(0) { $0 + $1.earned } }
        var reward: Double { acts.reduce(0) { $0 + $1.reward } }
    }

    /// 按卡片分组：同一张卡的活动归到一组，卡片顺序与卡包一致
    func activityGroups(_ list: [Activity]) -> [ActivityGroup] {
        var groups: [ActivityGroup] = []
        for card in cards {
            let acts = list.filter { $0.cardID == card.id }
            if !acts.isEmpty {
                groups.append(ActivityGroup(id: card.id, card: card, acts: acts))
            }
        }
        let known = Set(cards.map { $0.id })
        let orphans = list.filter { !known.contains($0.cardID) }
        if !orphans.isEmpty {
            groups.append(ActivityGroup(id: UUID(), card: nil, acts: orphans))
        }
        return groups
    }

    var totalEarned: Double { activities.reduce(0) { $0 + $1.earned } }
    var totalReward: Double { activities.reduce(0) { $0 + $1.reward } }

    func setReward(activityID: UUID, reward: Double) {
        guard let i = activities.firstIndex(where: { $0.id == activityID }) else { return }
        activities[i].reward = max(0, reward)
        save()
    }

    /// 直接把「已到账」改成一个总数：清空逐笔记录，按新总额补一条，保证两边一致
    func setEarned(activityID: UUID, earned: Double) {
        guard activities.contains(where: { $0.id == activityID }) else { return }
        earnings.removeAll { $0.activityID == activityID }
        let v = max(0, earned)
        if v > 0 {
            earnings.append(Earning(activityID: activityID, amount: v, date: Date(), note: "手动补录"))
        }
        syncEarned()
        save()
    }

    // MARK: 收益明细（逐笔）

    /// 某个活动的到账记录，按时间倒序
    func earnings(for activityID: UUID) -> [Earning] {
        earnings.filter { $0.activityID == activityID }
            .sorted { $0.date > $1.date }
    }

    /// 某个活动的累计到账
    func earnedTotal(for activityID: UUID) -> Double {
        earnings.filter { $0.activityID == activityID }.reduce(0) { $0 + $1.amount }
    }

    /// 全部到账记录，按时间倒序
    var allEarnings: [Earning] {
        earnings.sorted { $0.date > $1.date }
    }

    func addEarning(activityID: UUID, amount: Double, date: Date = Date(), note: String = "") {
        guard amount > 0 else { return }
        earnings.append(Earning(activityID: activityID, amount: amount, date: date, note: note))
        syncEarned()
        save()
    }

    func deleteEarning(_ id: UUID) {
        earnings.removeAll { $0.id == id }
        syncEarned()
        save()
    }

    /// 把每个活动的 earned 与他名下逐笔记录之和对齐
    private func syncEarned() {
        for i in activities.indices {
            let sum = earnings.filter { $0.activityID == activities[i].id }
                .reduce(0) { $0 + $1.amount }
            activities[i].earned = sum
        }
    }

    /// 旧数据只有 earned 总数、没有逐笔记录：补一条「历史到账」
    private func migrateEarnings() {
        for act in activities where act.earned > 0 {
            let sum = earnings.filter { $0.activityID == act.id }.reduce(0) { $0 + $1.amount }
            if sum <= 0.001 {
                earnings.append(Earning(activityID: act.id, amount: act.earned,
                                        date: Date(), note: "历史到账"))
            }
        }
        syncEarned()
    }

    // MARK: 年费

    /// 免年费达标进度（笔数）
    func feeCount(for card: CreditCard) -> Int {
        let f = card.feeInfo
        return f.manualMode ? f.manualCount : card.items.count
    }

    /// 免年费达标进度（金额）
    func feeSpent(for card: CreditCard) -> Double {
        let f = card.feeInfo
        return f.manualMode ? f.manualAmount : card.billTotal
    }

    /// 是否已满足免年费条件（任一规则满足即可）
    func feeWaived(_ card: CreditCard) -> Bool {
        let f = card.feeInfo
        if f.amount <= 0 { return true }
        let countOK = f.waiveCount > 0 && feeCount(for: card) >= f.waiveCount
        let amountOK = f.waiveAmount > 0 && feeSpent(for: card) >= f.waiveAmount
        return countOK || amountOK
    }

    /// 达标描述，如「已刷 3/6 笔」
    func feeProgressText(_ card: CreditCard) -> String {
        let f = card.feeInfo
        if f.amount <= 0 { return "免年费卡" }
        var parts: [String] = []
        if f.waiveCount > 0 {
            parts.append("已刷 \(feeCount(for: card))/\(f.waiveCount) 笔")
        }
        if f.waiveAmount > 0 {
            parts.append("已刷 " + Fmt.yuan(feeSpent(for: card)) + "/" + Fmt.yuan(f.waiveAmount))
        }
        if parts.isEmpty { return "无免年费规则" }
        return parts.joined(separator: " · ")
    }

    /// 下一次年费扣取日
    func nextFeeDate(for card: CreditCard) -> Date {
        let f = card.feeInfo
        return DateHelp.nextAnnual(month: f.month, day: f.day)
    }

    /// 距离下次扣年费还有多少天
    func feeDaysLeft(for card: CreditCard) -> Int {
        DateHelp.daysUntil(nextFeeDate(for: card))
    }

    func categoryTotals() -> [(name: String, value: Double, color: String)] {
        var map: [String: Double] = [:]
        for c in cards {
            for t in c.items {
                map[t.category, default: 0] += t.amount
            }
        }
        let list = map.map { (name: $0.key, value: $0.value, color: $0.key) }
        return list.sorted { $0.value > $1.value }
    }

    // MARK: 记账

    /// 手动记一笔消费，插入到该卡流水的最前面
    func addTransaction(cardID: UUID, tx: Transaction) {
        guard let i = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cards[i].items.insert(tx, at: 0)
        save()
    }

    // MARK: 刷卡金（返现收入）

    /// 记一笔刷卡金：写入该卡记录并自动抵扣本期应还，返回抵扣后的应还金额
    @discardableResult
    func addCashback(cardID: UUID, amount: Double, note: String) -> Double? {
        guard amount > 0,
              let i = cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        let rec = Cashback(amount: amount, date: Date(), note: note)
        cards[i].cashbacks = cards[i].cashbackList + [rec]
        save()
        return cards[i].outstanding
    }

    /// 删除一笔刷卡金，应还金额随之恢复
    func deleteCashback(cardID: UUID, id: UUID) {
        guard let i = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cards[i].cashbacks = cards[i].cashbackList.filter { $0.id != id }
        save()
    }

    /// 全部刷卡金累计
    var totalCashback: Double {
        cards.reduce(0) { $0 + $1.cashbackList.reduce(0) { $0 + $1.amount } }
    }

    /// 本账单周期内刷卡金合计
    var totalCycleCashback: Double {
        cards.reduce(0) { $0 + $1.cycleCashback }
    }

    /// 按快捷指令给的线索找卡：先精确匹配尾号，再按卡名/银行/组织模糊匹配；只有一张卡时直接命中
    func matchCard(_ query: String) -> CreditCard? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        if cards.count == 1, q.count < 3 { return cards.first }
        if let c = cards.first(where: { $0.last4 == q }) { return c }
        let l = q.lowercased()
        if let c = cards.first(where: {
            $0.name.lowercased().contains(l)
                || $0.bank.lowercased().contains(l)
                || $0.org.lowercased().contains(l)
                || ($0.bank + $0.name).lowercased().replacingOccurrences(of: " ", with: "").contains(l)
        }) { return c }
        return nil
    }

    /// 快捷指令记账：写流水 + 自动推进该卡未完成活动进度，返回进度提示文案
    func recordFromShortcut(cardID: UUID, amount: Double, merchant: String, category: String) -> [String] {
        var messages: [String] = []
        guard amount > 0,
              let i = cards.firstIndex(where: { $0.id == cardID }) else { return messages }

        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let tx = Transaction(merchant: name.isEmpty ? "快捷记账" : name,
                             category: cat.isEmpty ? guessCategory(name) : cat,
                             amount: amount,
                             date: Date())
        cards[i].items.insert(tx, at: 0)

        for j in activities.indices where activities[j].cardID == cardID && !activities[j].isDone {
            let before = activities[j].value
            if activities[j].kind == .amount {
                activities[j].current += amount
            } else if let k = activities[j].steps.firstIndex(where: { !$0.done }) {
                activities[j].steps[k].done = true
            }
            guard activities[j].value > before + 0.0001 else { continue }
            if activities[j].isDone {
                messages.append("🎉 「" + activities[j].title + "」已达标")
            } else {
                messages.append("「" + activities[j].title + "」进度 " + activities[j].percentText
                                + " · " + activities[j].remainText)
            }
        }
        save()
        return messages
    }

    /// 简单的商家关键词归类
    func guessCategory(_ merchant: String) -> String {
        let m = merchant.lowercased()
        let table: [(keywords: [String], category: String)] = [
            (["星巴克", "瑞幸", "咖啡", "奶茶", "喜茶", "茶百道", "luckin", "starbucks"], "餐饮"),
            (["美团", "饿了么", "肯德基", "麦当劳", "必胜客", "外卖", "kfc", "mcdonald"], "餐饮"),
            (["中石化", "中石油", "加油站", "加油", "壳牌"], "加油"),
            (["京东", "淘宝", "天猫", "拼多多", "唯品会", "优衣库", "优衣库"], "购物"),
            (["滴滴", "地铁", "公交", "12306", "铁路", "航空", "机票", "出租车", "高德"], "交通"),
            (["万达", "影城", "影院", "猫眼", "淘票票", "电影", "cgv", "imi"], "娱乐"),
            (["超市", "永辉", "盒马", "山姆", "沃尔玛", "costco", "华润万家"], "日用"),
            (["医院", "药店", "药房", "挂号"], "医疗"),
            (["话费", "移动", "联通", "电信", "水费", "电费", "燃气", "宽带"], "缴费"),
        ]
        for t in table where t.keywords.contains(where: { m.contains($0) }) {
            return t.category
        }
        return "其他"
    }

    // MARK: 活动月份

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static func currentMonthKey() -> String { monthFormatter.string(from: Date()) }

    func monthKey(_ date: Date) -> String { Store.monthFormatter.string(from: date) }

    /// 活动归属月份：优先取 periodMonth，旧数据回退到截止日所在月
    func displayMonthKey(_ act: Activity) -> String {
        act.periodMonth ?? monthKey(act.deadline)
    }

    /// 某月 yyyy-MM 的活动列表
    func activities(inMonth key: String) -> [Activity] {
        activities.filter { displayMonthKey($0) == key }
    }

    /// 月份中文标签：2026-11 → 2026年11月
    static func monthLabel(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return key }
        return "\(y)年\(m)月"
    }

    /// 月份选项文案：2026年11月（当月）
    static func monthOptionLabel(_ key: String) -> String {
        let base = monthLabel(key)
        if key == currentMonthKey() { return base + "（当月）" }
        return base
    }

    /// 相邻月份 key（offset ±1）
    static func monthKey(_ key: String, offsetBy offset: Int) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return key }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = 1
        guard let d = Calendar.current.date(from: c),
              let shifted = Calendar.current.date(byAdding: .month, value: offset, to: d) else { return key }
        return monthFormatter.string(from: shifted)
    }

    /// 可选月份列表：所有活动出现过的月份 + 当月 + 下月，倒序
    func visibleMonthKeys() -> [String] {
        var set = Set(activities.map { displayMonthKey($0) })
        set.insert(Store.currentMonthKey())
        set.insert(Store.monthKey(Store.currentMonthKey(), offsetBy: 1))
        return set.sorted(by: >)
    }

    /// 把历史活动复制到目标月份：进度清零、到账清零、抢购提醒改为不提醒；
    /// 原截止日已过的自动顺延到目标月份最后一天
    @discardableResult
    func duplicateActivities(ids: [UUID], toMonth key: String) -> Int {
        var created = 0
        for id in ids {
            guard let src = activities.first(where: { $0.id == id }) else { continue }
            var copy = src
            copy.id = UUID()
            copy.periodMonth = key
            copy.current = 0
            copy.steps = src.steps.map { step in
                var s = step
                s.id = UUID()
                s.done = false
                return s
            }
            copy.earned = 0
            copy.alertAt = nil
            if copy.remind == .precise { copy.remind = .none }

            if copy.deadline < Date() {
                let parts = key.split(separator: "-").compactMap { Int($0) }
                if parts.count == 2 {
                    var c = DateComponents()
                    c.year = parts[0]; c.month = parts[1] + 1; c.day = 1; c.hour = 23; c.minute = 59
                    if let firstNext = Calendar.current.date(from: c) {
                        copy.deadline = Calendar.current.date(byAdding: .day, value: -1, to: firstNext) ?? copy.deadline
                    }
                }
            }
            activities.append(copy)
            created += 1
        }
        if created > 0 { save() }
        return created
    }

    // MARK: 活动操作

    func toggleStep(activityID: UUID, index: Int) {
        guard let i = activities.firstIndex(where: { $0.id == activityID }),
              activities[i].steps.indices.contains(index) else { return }
        activities[i].steps[index].done.toggle()
        save()
    }

    func checkNextStep(activityID: UUID) {
        guard let i = activities.firstIndex(where: { $0.id == activityID }) else { return }
        guard let j = activities[i].steps.firstIndex(where: { !$0.done }) else { return }
        activities[i].steps[j].done = true
        save()
    }

    func undoLastStep(activityID: UUID) {
        guard let i = activities.firstIndex(where: { $0.id == activityID }) else { return }
        for j in stride(from: activities[i].steps.count - 1, through: 0, by: -1) {
            if activities[i].steps[j].done {
                activities[i].steps[j].done = false
                save()
                return
            }
        }
    }

    func addAmount(activityID: UUID, amount: Double) {
        guard let i = activities.firstIndex(where: { $0.id == activityID }) else { return }
        activities[i].current += amount
        save()
    }

    func setDone(activityID: UUID, done: Bool) {
        guard let i = activities.firstIndex(where: { $0.id == activityID }) else { return }
        if done {
            if activities[i].kind == .amount {
                activities[i].current = activities[i].target
            } else {
                for j in activities[i].steps.indices {
                    activities[i].steps[j].done = true
                }
            }
        } else {
            activities[i].current = 0
            for j in activities[i].steps.indices {
                activities[i].steps[j].done = false
            }
        }
        save()
    }

    func deleteActivity(_ id: UUID) {
        activities.removeAll { $0.id == id }
        earnings.removeAll { $0.activityID == id }
        save()
    }

    func deleteCard(_ id: UUID) {
        let actIDs = Set(activities.filter { $0.cardID == id }.map { $0.id })
        cards.removeAll { $0.id == id }
        activities.removeAll { $0.cardID == id }
        earnings.removeAll { actIDs.contains($0.activityID) }
        // 主卡被删后，其附属卡自动转为独立卡，避免留下指向空 id 的孤儿
        for i in cards.indices where cards[i].supplementaryTo == id {
            cards[i].supplementaryTo = nil
        }
        save()
    }

    // MARK: 演示数据

    private func seed() {
        let c1 = CreditCard(
            bank: "招商银行", name: "经典白金卡", org: "VISA", last4: "4832",
            limit: 80000, used: 32800, billDay: 5, dueDay: 23, paid: 1000,
            colorA: "1B1D2B", colorB: "3B4067", remind: true, remindDays: 3,
            items: [
                Transaction(merchant: "京东商城", category: "购物", amount: 899.00, date: DateHelp.thisMonth(day: 16)),
                Transaction(merchant: "中石化 · 建国路站", category: "加油", amount: 400.00, date: DateHelp.thisMonth(day: 14)),
                Transaction(merchant: "盒马鲜生 朝阳店", category: "超市", amount: 268.50, date: DateHelp.thisMonth(day: 12)),
                Transaction(merchant: "星巴克 国贸店", category: "餐饮", amount: 38.00, date: DateHelp.thisMonth(day: 11)),
                Transaction(merchant: "美团外卖", category: "餐饮", amount: 145.60, date: DateHelp.thisMonth(day: 9)),
                Transaction(merchant: "Apple Music", category: "订阅", amount: 68.00, date: DateHelp.thisMonth(day: 8)),
                Transaction(merchant: "地铁出行", category: "交通", amount: 24.00, date: DateHelp.thisMonth(day: 7)),
                Transaction(merchant: "优衣库 三里屯", category: "购物", amount: 329.90, date: DateHelp.thisMonth(day: 5))
            ],
            fee: CardFee(amount: 3600, waiveCount: 6, month: 12, day: 1,
                         remind: true, remindDays: 30))

        let c2 = CreditCard(
            bank: "交通银行", name: "太平洋信用卡", org: "Mastercard", last4: "7719",
            limit: 50000, used: 11200, billDay: 8, dueDay: 27, paid: 0,
            colorA: "15303C", colorB: "1F5E70", remind: true, remindDays: 3,
            items: [
                Transaction(merchant: "小米之家", category: "购物", amount: 599.00, date: DateHelp.thisMonth(day: 15)),
                Transaction(merchant: "瑞幸咖啡", category: "餐饮", amount: 32.00, date: DateHelp.thisMonth(day: 13)),
                Transaction(merchant: "滴滴出行", category: "交通", amount: 28.50, date: DateHelp.thisMonth(day: 10)),
                Transaction(merchant: "中石化 · 望京站", category: "加油", amount: 300.00, date: DateHelp.thisMonth(day: 6))
            ],
            fee: CardFee(amount: 500, waiveCount: 6, waiveAmount: 0, month: 3, day: 15,
                         remind: true, remindDays: 30))

        let c3 = CreditCard(
            bank: "中信银行", name: "魔力白金卡", org: "银联", last4: "2065",
            limit: 30000, used: 6800, billDay: 12, dueDay: 28, paid: 0,
            colorA: "3A1F2E", colorB: "6B2E44", remind: true, remindDays: 5,
            items: [
                Transaction(merchant: "美团买菜", category: "超市", amount: 156.80, date: DateHelp.thisMonth(day: 16)),
                Transaction(merchant: "中石油 · 亦庄站", category: "加油", amount: 300.00, date: DateHelp.thisMonth(day: 12)),
                Transaction(merchant: "万达影城", category: "娱乐", amount: 88.00, date: DateHelp.thisMonth(day: 8))
            ],
            fee: CardFee(amount: 480, waiveCount: 0, waiveAmount: 30000, month: 9, day: 10,
                         remind: true, remindDays: 15))

        let c4 = CreditCard(
            bank: "浦发银行", name: "AE 白金卡", org: "AE", last4: "9014",
            limit: 100000, used: 9000, billDay: 18, dueDay: 6, paid: 682,
            colorA: "20242B", colorB: "3F4650", remind: false, remindDays: 7,
            items: [
                Transaction(merchant: "日上免税行", category: "购物", amount: 682.00, date: DateHelp.thisMonth(day: 4))
            ],
            fee: CardFee(amount: 3600, waiveCount: 12, waiveAmount: 300000, month: 6, day: 1,
                         remind: true, remindDays: 30))

        // 招行附属卡：额度与主卡共享，不单独计入总授信
        let c5 = CreditCard(
            bank: "招商银行", name: "全币种国际卡（附属）", org: "VISA", last4: "6627",
            limit: 80000, used: 4260, billDay: 5, dueDay: 23, paid: 0,
            colorA: "2C3550", colorB: "55638C", remind: true, remindDays: 3,
            items: [
                Transaction(merchant: "山姆会员店", category: "超市", amount: 1280.00, date: DateHelp.thisMonth(day: 15)),
                Transaction(merchant: "全家便利店", category: "超市", amount: 46.50, date: DateHelp.thisMonth(day: 13))
            ],
            supplementaryTo: c1.id)

        cards = [c1, c2, c3, c4, c5]

        activities = [
            Activity(cardID: c1.id, title: "月月刷 · 满 3000 返 100",
                     detail: "当月累计消费满 3,000 元，次月返 100 元刷卡金",
                     kind: .amount, target: 3000, current: 2173,
                     deadline: DateHelp.thisMonth(day: 30), remind: .weeklySunday, reward: 100),

            Activity(cardID: c2.id, title: "最红星期五 · 5 折",
                     detail: "每周五单笔满 100 元享 5 折，每月最多 4 次",
                     kind: .count, target: 4, deadline: DateHelp.thisMonth(day: 30), remind: .weeklyFriday, reward: 80,
                     steps: [
                        ActivityStep(label: "第 1 周 · 已完成", done: true),
                        ActivityStep(label: "第 2 周 · 已完成", done: true),
                        ActivityStep(label: "第 3 周", done: false),
                        ActivityStep(label: "第 4 周", done: false)
                     ]),

            Activity(cardID: c3.id, title: "加油返现 8%",
                     detail: "每月在中石油 / 中石化消费 2 笔，返现 8%",
                     kind: .count, target: 2, deadline: DateHelp.thisMonth(day: 30), remind: .monthlyFirst, reward: 60, earned: 60,
                     steps: [
                        ActivityStep(label: "第 1 笔加油", done: true),
                        ActivityStep(label: "第 2 笔加油", done: true)
                     ]),

            Activity(cardID: c4.id, title: "超市满 200 减 30",
                     detail: "指定超市单笔满 200 元立减 30 元，每月 1 次",
                     kind: .once, target: 1, deadline: DateHelp.thisMonth(day: 25), remind: .dayBefore, reward: 30,
                     steps: [ActivityStep(label: "完成一笔满 200 元消费", done: false)])
        ]

        migrateEarnings()
        save()
    }

    func reset() {
        cards = []
        activities = []
        earnings = []
        settings = AppSettings()
        seed()
    }
}

// MARK: - 日期工具

enum DateHelp {
    static let cal = Calendar.current

    static func thisMonth(day: Int, hour: Int = 12) -> Date {
        var c = cal.dateComponents([.year, .month], from: Date())
        c.day = min(max(day, 1), 28)
        c.hour = hour
        return cal.date(from: c) ?? Date()
    }

    static func nextOccurrence(day: Int) -> Date {
        let today = cal.startOfDay(for: Date())
        var c = cal.dateComponents([.year, .month], from: today)
        c.day = min(max(day, 1), 28)
        var d = cal.date(from: c) ?? today
        if d < today {
            d = cal.date(byAdding: .month, value: 1, to: d) ?? d
        }
        return d
    }

    static func daysUntil(_ date: Date) -> Int {
        let a = cal.startOfDay(for: Date())
        let b = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func daysToDue(_ day: Int) -> Int {
        daysUntil(nextOccurrence(day: day))
    }

    /// 下一次「每年某月某日」，用于年费扣取日
    static func nextAnnual(month: Int, day: Int) -> Date {
        let today = cal.startOfDay(for: Date())
        var c = cal.dateComponents([.year], from: today)
        c.month = min(max(month, 1), 12)
        c.day = min(max(day, 1), 28)
        c.hour = 9
        var d = cal.date(from: c) ?? today
        if d < today {
            d = cal.date(byAdding: .year, value: 1, to: d) ?? d
        }
        return d
    }

    static func daysToDeadline(_ date: Date) -> Int {
        daysUntil(date)
    }
}
