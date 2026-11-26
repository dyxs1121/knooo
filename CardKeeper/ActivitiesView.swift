import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject var store: Store

    enum Scope: String, CaseIterable {
        case all, doing, done
    }

    /// 同一视图只能挂一个 sheet，用枚举统一驱动
    private enum Sheet: Identifiable {
        case detail(Activity)
        case add
        case earnings
        case cashback
        case quickAdd

        var id: String {
            switch self {
            case .detail(let act): return act.id.uuidString
            case .add: return "new-activity"
            case .earnings: return "earnings-list"
            case .cashback: return "record-cashback"
            case .quickAdd: return "quick-add"
            }
        }
    }

    @State private var scope: Scope = .all
    @State private var sheet: Sheet?
    /// 月份筛选：nil = 全部月份；默认当月，新的一月打开 App 自动跟随
    @State private var monthFilter: String? = Store.currentMonthKey()

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    statsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    earnStrip
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    monthBar
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    segmented
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    list
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                }
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .detail(let act):
                ActivityDetailView(activityID: act.id).environmentObject(store)
            case .add:
                ActivityEditorView().environmentObject(store)
            case .earnings:
                EarningsListView().environmentObject(store)
            case .cashback:
                CashbackRecordView().environmentObject(store)
            case .quickAdd:
                QuickAddActivitiesView().environmentObject(store)
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.todayLine())
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.sub)
                Text("活动与权益")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundColor(Palette.text)
            }

            Spacer()

            Button {
                sheet = .add
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Palette.text)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: "767680").opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 概览

    /// 当前月份筛选下的活动
    private var monthActivities: [Activity] {
        guard let key = monthFilter else { return store.activities }
        return store.activities(inMonth: key)
    }

    private var doingCount: Int { monthActivities.filter { !$0.isDone }.count }
    private var doneCount: Int { monthActivities.filter { $0.isDone }.count }

    private var statsRow: some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                Text("进行中")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.sub)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(doingCount)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Palette.text)
                    Text("个")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.sub)
                }
                Text(nearestHint)
                    .font(.system(size: 10.5))
                    .foregroundColor(Palette.orange)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("已完成")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.sub)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(doneCount)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Palette.green)
                    Text("个")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.sub)
                }
                Text("本月累计打卡")
                    .font(.system(size: 10.5))
                    .foregroundColor(Palette.sub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// 活动收益总览（点开看每一笔到账）+ 记收入入口
    private var earnStrip: some View {
        HStack(spacing: 8) {
            Button {
                sheet = .earnings
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.orange)

                    Text("活动收益")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Palette.text)

                    Spacer()

                    Text("已到账 " + Fmt.yuan(store.totalEarned))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.green)

                    Text("预期 " + Fmt.yuan(store.totalReward))
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.sub)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Palette.sub)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                sheet = .cashback
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.orange)
                    Text("记收入")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Palette.text)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var nearestHint: String {        let pending = monthActivities.filter { !$0.isDone }
        guard let first = pending.min(by: { $0.deadline < $1.deadline }) else {
            return "暂无待办"
        }
        let left = max(0, DateHelp.daysToDeadline(first.deadline))
        return "最近截止剩 \(left) 天"
    }

    // MARK: 月份筛选

    private var currentMonthLabel: String {
        guard let key = monthFilter else { return "全部月份" }
        return Store.monthLabel(key)
    }

    private var monthBar: some View {
        HStack(spacing: 8) {
            Button {
                monthFilter = Store.monthKey(monthFilter ?? Store.currentMonthKey(), offsetBy: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.text)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "767680").opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("全部月份") { monthFilter = nil }
                ForEach(store.visibleMonthKeys(), id: \.self) { key in
                    Button(Store.monthOptionLabel(key)) {
                        monthFilter = key
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(currentMonthLabel)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Palette.text)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Palette.sub)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color(hex: "767680").opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button {
                monthFilter = Store.monthKey(monthFilter ?? Store.currentMonthKey(), offsetBy: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.text)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "767680").opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                sheet = .quickAdd
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(Palette.orange)
                    Text("快捷添加")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.text)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Palette.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 分段

    private var segmented: some View {
        HStack(spacing: 2) {
            ForEach(Scope.allCases, id: \.self) { item in
                Button {
                    scope = item
                } label: {
                    Text(scopeLabel(item))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(scope == item ? Palette.text : Color(hex: "6C6C70"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(scope == item ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color(hex: "767680").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func scopeLabel(_ item: Scope) -> String {
        switch item {
        case .all: return "全部 \(monthActivities.count)"
        case .doing: return "进行中 \(doingCount)"
        case .done: return "已完成 \(doneCount)"
        }
    }

    // MARK: 列表

    private var filtered: [Activity] {
        switch scope {
        case .all: return monthActivities
        case .doing: return monthActivities.filter { !$0.isDone }
        case .done: return monthActivities.filter { $0.isDone }
        }
    }

    private var groups: [Store.ActivityGroup] {
        store.activityGroups(filtered)
    }

    private var list: some View {
        VStack(spacing: 18) {
            if groups.isEmpty {
                VStack(spacing: 6) {
                    Text("这里还没有活动")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "A0A0A5"))
                    Text("点右上角 + 添加一个")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "A0A0A5").opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 46)
            } else {
                ForEach(groups) { g in
                    VStack(alignment: .leading, spacing: 8) {
                        groupHeader(g)
                        VStack(spacing: 8) {
                            ForEach(g.acts) { act in
                                activityCard(act)
                            }
                        }
                        .padding(.leading, 12)
                    }
                }
            }
        }
    }

    /// 同一张卡的活动归为一组，组头显示该卡与收益合计
    private func groupHeader(_ g: Store.ActivityGroup) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Palette.purple, Color(hex: "6E8BFF")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(g.card.map { $0.bank + " ••" + $0.last4 } ?? "未关联卡片")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.text)
                    .lineLimit(1)
                Text(groupSubtitle(g))
                    .font(.system(size: 11))
                    .foregroundColor(Palette.sub)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func groupSubtitle(_ g: Store.ActivityGroup) -> String {
        var parts = ["\(g.acts.count) 个活动"]
        if g.reward > 0 { parts.append("预期 " + Fmt.yuan(g.reward)) }
        parts.append("已到账 " + Fmt.yuan(g.earned))
        return parts.joined(separator: " · ")
    }

    private func activityCard(_ act: Activity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                PillView(text: act.kind.shortLabel, fg: Palette.blue, bg: Palette.blue.opacity(0.09))
                if act.isDone {
                    PillView(text: "已完成", fg: Palette.green, bg: Palette.green.opacity(0.12))
                }
                if act.reward > 0 {
                    PillView(text: "收益 " + Fmt.yuan(act.earned) + "/" + Fmt.yuan(act.reward),
                             fg: Palette.orange, bg: Palette.orange.opacity(0.12))
                }
                Spacer()
            }
            .padding(.bottom, 6)

            Text(act.title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundColor(Palette.text)

            Text(act.detail)
                .font(.system(size: 11.5))
                .foregroundColor(Palette.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)

            HStack {
                Text(progressLabel(act))
                    .font(.system(size: 11))
                    .foregroundColor(Palette.sub)
                Spacer()
                Text(act.percentText)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.sub)
            }
            .padding(.top, 11)
            .padding(.bottom, 5)

            BarView(value: act.ratio, height: 6,
                    tint: act.isDone
                    ? LinearGradient(colors: [Palette.green, Color(hex: "5BD98A")], startPoint: .leading, endPoint: .trailing)
                    : Palette.accentGradient)

            HStack(spacing: 5) {
                Image(systemName: "bell")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Palette.sub)

                Text(act.remindText + " · 剩 \(max(0, DateHelp.daysToDeadline(act.deadline))) 天")
                    .font(.system(size: 11))
                    .foregroundColor(daysColor(act))
                    .lineLimit(1)

                Spacer()

                checkButton(act)
            }
            .padding(.top, 12)
        }
        .padding(15)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 1.5, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { sheet = .detail(act) }
    }

    private func daysColor(_ act: Activity) -> Color {
        let left = DateHelp.daysToDeadline(act.deadline)
        return (!act.isDone && left <= 3) ? Palette.red : Palette.sub
    }

    private func progressLabel(_ act: Activity) -> String {
        if act.kind == .amount {
            return "进度 " + Fmt.yuan(act.value) + " / " + Fmt.yuan(act.target)
        }
        return "进度 \(Int(act.value)) / \(Int(act.target)) 次"
    }

    private func checkButton(_ act: Activity) -> some View {
        Button {
            if act.isDone {
                store.undoLastStep(activityID: act.id)
                Notifier.shared.refresh(store: store)
            } else if act.kind == .amount {
                sheet = .detail(act)
            } else {
                store.checkNextStep(activityID: act.id)
                Notifier.shared.refresh(store: store)
            }
        } label: {
            Text(buttonTitle(act))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(act.isDone ? Color(hex: "1E9E4C") : Palette.blue)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(act.isDone ? Palette.green.opacity(0.12) : Palette.blue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func buttonTitle(_ act: Activity) -> String {
        if act.isDone { return "已完成" }
        switch act.kind {
        case .amount: return "记一笔"
        case .count: return "打卡 +1"
        case .once: return "确认完成"
        }
    }
}

// MARK: - 活动详情

struct ActivityDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    let activityID: UUID

    @State private var amountText = ""
    @State private var confirmDelete = false
    @State private var rewardText = ""
    @State private var earnAmountText = ""

    private var activity: Activity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.bg.ignoresSafeArea()

                if let act = activity {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            tagRow(act)
                            Text(act.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Palette.text)
                                .padding(.top, 9)
                            Text(act.detail)
                                .font(.system(size: 12.5))
                                .foregroundColor(Palette.sub)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 7)

                            progressPanel(act)
                                .padding(.top, 16)

                            rewardPanel(act)
                                .padding(.top, 12)

                            if act.kind == .amount {
                                amountInput(act)
                            } else {
                                stepList(act)
                            }

                            actionRow(act)
                                .padding(.top, 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("活动详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Palette.text)
                            .frame(width: 30, height: 30)
                            .background(Color(hex: "767680").opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .alert("删除这个活动？", isPresented: $confirmDelete) {
                Button("删除", role: .destructive) {
                    store.deleteActivity(activityID)
                    Notifier.shared.refresh(store: store)
                    dismiss()
                }
                Button("取消", role: .cancel) { }
            }
            .onAppear { syncRewardFields() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func tagRow(_ act: Activity) -> some View {
        HStack(spacing: 6) {
            PillView(text: store.cardName(act.cardID), fg: Color(hex: "5A48E0"), bg: Palette.purple.opacity(0.10))
            PillView(text: act.kind.label, fg: Palette.blue, bg: Palette.blue.opacity(0.09))
            if act.isDone {
                PillView(text: "已完成", fg: Palette.green, bg: Palette.green.opacity(0.12))
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: 收益记录

    private func syncRewardFields() {
        guard let act = activity else { return }
        rewardText = act.reward > 0 ? numText(act.reward) : ""
    }

    /// 当前活动名下的到账记录
    private var earningRecords: [Earning] {
        store.earnings(for: activityID)
    }

    private func numText(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v)
    }

    private func rewardPanel(_ act: Activity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("活动收益")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.sub)
                Spacer()
                Text(act.earned > 0 ? "累计到账 " + Fmt.yuan(act.earned) : "尚未到账")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(act.earned > 0 ? Palette.green : Palette.sub)
            }

            HStack(spacing: 10) {
                rewardField(title: "预期奖励", text: $rewardText)

                VStack(alignment: .leading, spacing: 4) {
                    Text("已到账合计")
                        .font(.system(size: 10.5))
                        .foregroundColor(Palette.sub)
                    HStack(spacing: 3) {
                        Text("¥")
                            .font(.system(size: 12))
                            .foregroundColor(Palette.sub)
                        Text(Fmt.raw(act.earned))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Palette.green)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(hex: "767680").opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.top, 11)

            if !earningRecords.isEmpty {
                VStack(spacing: 0) {
                    ForEach(earningRecords) { e in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.note.isEmpty ? "到账" : e.note)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Palette.text)
                                Text(Fmt.monthDay(e.date))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Palette.sub)
                            }
                            Spacer()
                            Text("+" + Fmt.money(e.amount))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Palette.green)
                            Button {
                                store.deleteEarning(e.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(Palette.red.opacity(0.85))
                                    .padding(.leading, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .padding(.top, 6)
            }

            HStack(spacing: 8) {
                TextField("到账金额", text: $earnAmountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 13))
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button {
                    let v = Double(earnAmountText) ?? 0
                    guard v > 0 else { return }
                    store.addEarning(activityID: activityID, amount: v, note: "手动记录")
                    earnAmountText = ""
                } label: {
                    Text("记一笔到账")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.blue.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)

            HStack(spacing: 8) {
                Button {
                    let gap = act.reward - store.earnedTotal(for: activityID)
                    if gap > 0 {
                        store.addEarning(activityID: activityID, amount: gap, note: "按预期补足")
                    }
                } label: {
                    Text("按预期补足")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.green.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    store.setReward(activityID: activityID, reward: Double(rewardText) ?? 0)
                    syncRewardFields()
                } label: {
                    Text("保存预期")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Palette.primaryButton)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func rewardField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundColor(Palette.sub)
            HStack(spacing: 3) {
                Text("¥")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.sub)
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: "767680").opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func progressPanel(_ act: Activity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(act.kind == .amount ? "累计消费" : "完成进度")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.sub)
                Spacer()
                Text(valueText(act))
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(Palette.text)
            }

            BarView(value: act.ratio, height: 8,
                    tint: act.isDone
                    ? LinearGradient(colors: [Palette.green, Color(hex: "5BD98A")], startPoint: .leading, endPoint: .trailing)
                    : Palette.accentGradient)
                .padding(.top, 11)

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bell")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.sub)
                    Text(act.remindText)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.sub)
                }
                Spacer()
                Text("截止 " + Fmt.monthDay(act.deadline) + " · 剩 \(max(0, DateHelp.daysToDeadline(act.deadline))) 天")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.sub)
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func valueText(_ act: Activity) -> String {
        if act.kind == .amount {
            return Fmt.yuan(act.value) + " / " + Fmt.yuan(act.target)
        }
        return "\(Int(act.value)) / \(Int(act.target)) 次"
    }

    private func amountInput(_ act: Activity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("记录一笔消费")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Palette.sub)
                .padding(.leading, 3)
                .padding(.top, 18)
                .padding(.bottom, 7)

            HStack(spacing: 10) {
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    let v = Double(amountText) ?? 0
                    guard v > 0 else { return }
                    store.addAmount(activityID: activityID, amount: v)
                    Notifier.shared.refresh(store: store)
                    amountText = ""
                } label: {
                    Text("记录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .background(Palette.blue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text("已累计 " + Fmt.money(act.current) + "，还差 " + Fmt.money(max(0, act.target - act.current)) + " 达标")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "A0A0A5"))
                .padding(.top, 7)
                .padding(.leading, 3)
        }
    }

    private func stepList(_ act: Activity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("完成情况（点击勾选）")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Palette.sub)
                .padding(.leading, 3)
                .padding(.top, 18)
                .padding(.bottom, 7)

            CardShell {
                VStack(spacing: 0) {
                    ForEach(Array(act.steps.enumerated()), id: \.offset) { index, step in
                        Button {
                            store.toggleStep(activityID: activityID, index: index)
                            Notifier.shared.refresh(store: store)
                        } label: {
                            HStack(spacing: 11) {
                                ZStack {
                                    Circle()
                                        .stroke(step.done ? Palette.green : Color(hex: "D6D6DA"), lineWidth: 1.8)
                                        .frame(width: 22, height: 22)
                                    if step.done {
                                        Circle()
                                            .fill(Palette.green)
                                            .frame(width: 22, height: 22)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }

                                Text(step.label)
                                    .font(.system(size: 13.5))
                                    .foregroundColor(step.done ? Color(hex: "A0A0A5") : Palette.text)
                                    .strikethrough(step.done, color: Color(hex: "A0A0A5"))

                                Spacer()
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < act.steps.count - 1 {
                            RowDivider(inset: 48)
                        }
                    }
                }
            }
        }
    }

    private func actionRow(_ act: Activity) -> some View {
        HStack(spacing: 10) {
            Button {
                confirmDelete = true
            } label: {
                Text("删除")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Palette.red)
                    .frame(width: 88)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if act.isDone {
                Button {
                    store.setDone(activityID: activityID, done: false)
                    Notifier.shared.refresh(store: store)
                } label: {
                    Text("撤销完成")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(Palette.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "E8E8ED"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                PrimaryButton(title: "标记为已完成") {
                    store.setDone(activityID: activityID, done: true)
                    Notifier.shared.refresh(store: store)
                }
            }
        }
    }
}

// MARK: - 添加活动（同一张卡可一次添加多个活动）

struct ActivityEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    struct Draft: Identifiable {
        var id = UUID()
        var title = ""
        var detail = ""
        var kind: ActivityKind = .count
        var targetText = "3"
        var rewardText = ""
    }

    @State private var drafts: [Draft] = [Draft()]
    @State private var cardID: UUID?
    /// 默认截止：当月最后一天 23:59，需要更久可以手动改
    @State private var deadline = ActivityEditorView.endOfCurrentMonth()

    static func endOfCurrentMonth() -> Date {
        let cal = Calendar.current
        guard let firstNext = cal.date(byAdding: .month, value: 1,
                                       to: cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()) else {
            return Date()
        }
        let end = cal.date(byAdding: .day, value: -1, to: firstNext) ?? Date()
        return cal.date(bySettingHour: 23, minute: 59, second: 0, of: end) ?? end
    }
    @State private var remind: RemindRule = .weeklySunday
    @State private var alertAt = Date().addingTimeInterval(86400 * 2)
    @State private var leadMinutes = 10
    @State private var showError = false
    /// Picker 的 selection 必须是稳定值
    @State private var fallbackCardID = UUID()

    private let leadOptions = [0, 5, 10, 30, 60]

    var body: some View {
        NavigationView {
            Form {
                Section("关联卡片") {
                    Picker("卡片", selection: Binding(
                        get: { cardID ?? store.cards.first?.id ?? fallbackCardID },
                        set: { cardID = $0 }
                    )) {
                        ForEach(store.cards) { c in
                            Text(c.bank + " ••" + c.last4).tag(c.id)
                        }
                    }
                }

                ForEach(drafts.indices, id: \.self) { i in
                    Section {
                        TextField("活动名称，如 周五满 100 减 50", text: $drafts[i].title)
                        TextField("规则 / 名额 / 注意事项", text: $drafts[i].detail)

                        Picker("目标类型", selection: $drafts[i].kind) {
                            ForEach(ActivityKind.allCases) { k in
                                Text(k.label).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text(drafts[i].kind == .amount ? "目标金额" : "目标次数")
                            Spacer()
                            TextField("0", text: $drafts[i].targetText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        HStack {
                            Text("预期收益")
                            Spacer()
                            Text("¥")
                                .foregroundColor(Palette.sub)
                            TextField("0", text: $drafts[i].rewardText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        if drafts.count > 1 {
                            Button(role: .destructive) {
                                drafts.remove(at: i)
                            } label: {
                                Text("删除这条活动")
                                    .font(.system(size: 14))
                            }
                        }
                    } header: {
                        Text("活动 \(i + 1)")
                    }
                }

                Section {
                    Button {
                        drafts.append(Draft())
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "plus.circle.fill")
                            Text("再加一条活动（同一张卡）")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Palette.blue)
                    }
                } footer: {
                    Text("一次可以为同一张卡添加多个活动，列表里会按卡片归类显示。")
                        .font(.system(size: 11.5))
                }

                Section("截止与提醒") {
                    DatePicker("截止日期", selection: $deadline, displayedComponents: .date)

                    Picker("提醒方式", selection: $remind) {
                        ForEach(RemindRule.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }

                    if remind == .precise {
                        DatePicker("提醒时间", selection: $alertAt,
                                   displayedComponents: [.date, .hourAndMinute])

                        Picker("提前量", selection: $leadMinutes) {
                            ForEach(leadOptions, id: \.self) { m in
                                Text(m == 0 ? "准时提醒" : "提前 \(m) 分钟").tag(m)
                            }
                        }

                        Text("适合抢购、限量名额：到点会推送通知，提醒你立刻去参与。")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.sub)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Text(drafts.count > 1 ? "添加 \(drafts.count) 个活动" : "添加活动")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .listRowBackground(Palette.primaryButton)
                }
            }
            .navigationTitle("添加活动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if cardID == nil { cardID = store.cards.first?.id }
            }
            .alert("请至少填写一条活动的名称和目标值", isPresented: $showError) {
                Button("好", role: .cancel) { }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func save() {
        guard let cid = cardID else {
            showError = true
            return
        }

        var created = 0

        for d in drafts {
            let name = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let raw = Double(d.targetText) ?? 0
            guard !name.isEmpty, raw > 0 else { continue }

            let target = d.kind == .amount ? raw : max(1, raw.rounded())
            var steps: [ActivityStep] = []
            if d.kind != .amount {
                for i in 0..<Int(target) {
                    steps.append(ActivityStep(label: "第 \(i + 1) 次", done: false))
                }
            }

            var act = Activity(cardID: cid,
                               title: name,
                               detail: d.detail.isEmpty ? (d.kind == .amount ? "累计消费达标即完成" : "按次打卡完成") : d.detail,
                               kind: d.kind,
                               target: target,
                               deadline: deadline,
                               remind: remind,
                               steps: steps)
            act.reward = Double(d.rewardText) ?? 0
            act.alertAt = (remind == .precise) ? alertAt : nil
            act.leadMinutes = (remind == .precise) ? leadMinutes : 0
            act.periodMonth = store.monthKey(Date())

            store.activities.append(act)
            created += 1
        }

        guard created > 0 else {
            showError = true
            return
        }

        store.save()
        Notifier.shared.refresh(store: store)
        dismiss()
    }
}

// MARK: - 收益明细（全部到账记录）

struct EarningGroup: Identifiable {
    var id: UUID
    var title: String
    var cardName: String
    var records: [Earning]
    var expected: Double

    var total: Double { records.reduce(0) { $0 + $1.amount } }
}

struct EarningsListView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    private var groups: [EarningGroup] {
        var out: [EarningGroup] = []
        for act in store.activities {
            let recs = store.earnings(for: act.id)
            if recs.isEmpty { continue }
            out.append(EarningGroup(id: act.id,
                                    title: act.title,
                                    cardName: store.cardName(act.cardID),
                                    records: recs,
                                    expected: act.reward))
        }
        return out.sorted { $0.total > $1.total }
    }

    private var total: Double { store.earnings.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("累计到账")
                                .font(.system(size: 11.5))
                                .foregroundColor(Palette.sub)
                            Text(Fmt.money(total))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Palette.text)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("共 \(store.earnings.count) 笔")
                                .font(.system(size: 11.5))
                                .foregroundColor(Palette.sub)
                            Text("预期合计 " + Fmt.yuan(store.totalReward))
                                .font(.system(size: 11.5))
                                .foregroundColor(Palette.sub)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if store.totalCycleCashback > 0 {
                    Section {
                        HStack(alignment: .firstTextBaseline) {
                            Text("本账单周期刷卡金")
                                .font(.system(size: 13))
                                .foregroundColor(Palette.text)
                            Spacer()
                            Text("+" + Fmt.money(store.totalCycleCashback))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Palette.green)
                        }
                        ForEach(store.cards.filter { $0.cycleCashback > 0 }) { c in
                            HStack {
                                Text(c.bank + " " + c.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(Palette.sub)
                                Spacer()
                                Text("抵扣后应还 " + Fmt.money(c.outstanding))
                                    .font(.system(size: 11))
                                    .foregroundColor(Palette.sub)
                                Text("+" + Fmt.money(c.cycleCashback))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Palette.green)
                            }
                        }
                    }
                }

                if groups.isEmpty {
                    Section {
                        Text("还没有到账记录。在活动详情页点「记一笔到账」即可累积。")
                            .font(.system(size: 12.5))
                            .foregroundColor(Palette.sub)
                    }
                } else {
                    ForEach(groups) { g in
                        Section {
                            ForEach(g.records) { e in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.note.isEmpty ? "到账" : e.note)
                                            .font(.system(size: 13.5))
                                            .foregroundColor(Palette.text)
                                        Text(Fmt.monthDay(e.date) + " · " + g.cardName)
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Palette.sub)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("+" + Fmt.money(e.amount))
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(Palette.green)
                                }
                                .padding(.vertical, 2)
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { g.records[$0].id }
                                for id in ids {
                                    store.deleteEarning(id)
                                }
                            }
                        } header: {
                            Text(g.title)
                        } footer: {
                            Text("已到账 " + Fmt.yuan(g.total) + " · 预期 " + Fmt.yuan(g.expected))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("收益明细")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - 记收入（刷卡金 / 返现）

/// 记一笔刷卡金：保存后自动抵扣该卡本期应还
struct CashbackRecordView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    @State private var cardID: UUID? = nil
    @State private var amountText = ""
    @State private var note = ""
    @State private var savedOutstanding: Double? = nil
    /// 记录前的应还（用于展示抵扣效果）
    @State private var beforeOutstanding: Double = 0

    private var amount: Double { Double(amountText) ?? 0 }

    private var selectedCard: CreditCard? {
        store.cards.first(where: { $0.id == cardID })
    }

    private var amountBinding: Binding<String> {
        Binding(get: { amountText }, set: {
            amountText = $0.filter { "0123456789.".contains($0) }
        })
    }

    var body: some View {
        NavigationView {
            Form {
                if store.cards.isEmpty {
                    Section {
                        Text("还没有卡片，先去「卡片」页添加一张。")
                            .font(.system(size: 13))
                            .foregroundColor(Palette.sub)
                    }
                } else {
                    Section("哪张卡的返现") {
                        Picker("卡片", selection: $cardID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(store.cards) { c in
                                Text(c.bank + " " + c.name + " 尾号" + c.last4).tag(UUID?.some(c.id))
                            }
                        }
                    }

                    if let card = selectedCard {
                        Section {
                            HStack(alignment: .firstTextBaseline) {
                                Text("本账单周期已获得")
                                    .font(.system(size: 13))
                                    .foregroundColor(Palette.text)
                                Spacer()
                                Text("+" + Fmt.money(card.cycleCashback))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Palette.green)
                            }
                            Text(Fmt.monthDay(card.cycleStart) + " 起 · 至下次账单日（每月 \(card.billDay) 日）")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.sub)
                        } header: {
                            Text("刷卡金进度")
                        }
                    }

                    Section("这笔收入") {
                        HStack {
                            Text("金额")
                            Spacer()
                            Text("¥").foregroundColor(Palette.sub)
                            TextField("0.00", text: amountBinding)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        TextField("备注，如 10 月刷卡金 / 消费返现", text: $note)
                    }

                    if let card = selectedCard, amount > 0, savedOutstanding == nil {
                        Section {
                            HStack {
                                Text("保存后自动抵扣该卡本期应还")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Palette.sub)
                                Spacer()
                                Text(Fmt.money(card.outstanding) + " → " + Fmt.money(max(0, card.outstanding - amount)))
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Palette.green)
                            }
                        } header: {
                            Text("自动扣减账单")
                        }
                    }

                    Section {
                        if let after = savedOutstanding {
                            Text("已记入，抵扣后该卡本期应还 " + Fmt.money(after))
                                .font(.system(size: 12.5))
                                .foregroundColor(Palette.green)

                            Button {
                                dismiss()
                            } label: {
                                Text("完成")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .listRowBackground(Palette.primaryButton)
                        } else {
                            Button {
                                save()
                            } label: {
                                Text("保存并抵扣账单")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .listRowBackground(Palette.primaryButton)
                            .disabled(cardID == nil || amount <= 0)
                        }
                    }

                    if let card = selectedCard, !card.cashbackList.isEmpty {
                        Section {
                            ForEach(card.cashbackList) { cb in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cb.note.isEmpty ? "刷卡金" : cb.note)
                                            .font(.system(size: 13))
                                            .foregroundColor(Palette.text)
                                        Text(Fmt.monthDay(cb.date))
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Palette.sub)
                                    }
                                    Spacer()
                                    Text("+" + Fmt.money(cb.amount))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Palette.green)
                                }
                            }
                            .onDelete { offsets in
                                guard let card = selectedCard else { return }
                                let ids = offsets.map { card.cashbackList[$0].id }
                                for id in ids {
                                    store.deleteCashback(cardID: card.id, id: id)
                                }
                            }
                        } header: {
                            Text("该卡刷卡金记录（左滑删除）")
                        } footer: {
                            Text("删除记录后，对应的抵扣金额会从应还里恢复。")
                                .font(.system(size: 11.5))
                        }
                    }
                }
            }
            .navigationTitle("记收入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if cardID == nil { cardID = store.cards.first?.id }
        }
    }

    private func save() {
        guard let card = selectedCard, amount > 0 else { return }
        beforeOutstanding = card.outstanding
        savedOutstanding = store.addCashback(cardID: card.id, amount: amount, note: note)
    }
}

// MARK: - 快捷添加（从历史活动复制到指定月份）

struct QuickAddActivitiesView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    @State private var targetMonth: String = Store.currentMonthKey()
    @State private var selected: Set<UUID> = []
    @State private var justAdded = 0

    /// 单行：勾选圈 + 标题 + 卡片与进度
    private func quickAddRow(_ act: Activity) -> some View {
        let exists = alreadyInMonth(act)
        let picked = selected.contains(act.id)
        let titleColor = exists ? Palette.sub : Palette.text
        let iconName = picked ? "checkmark.circle.fill" : "circle"
        let iconColor = picked ? Palette.green : Color(hex: "C2C2C8")
        let subtitle = rowSubtitle(act)

        return Button {
            if picked {
                selected.remove(act.id)
            } else {
                selected.insert(act.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 17))
                    .foregroundColor(iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(act.title)
                        .font(.system(size: 13.5))
                        .foregroundColor(titleColor)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(Palette.sub)
                        .lineLimit(1)
                }

                Spacer()

                if exists {
                    Text("本月已有")
                        .font(.system(size: 10.5))
                        .foregroundColor(Palette.sub)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(exists)
    }

    /// 卡片名 + 进度文案（拆开写，避免长表达式拖慢类型检查）
    private func rowSubtitle(_ act: Activity) -> String {
        let cardName = store.cardName(act.cardID)
        let status = act.isDone ? "已完成" : act.remainText
        return cardName + " · " + status
    }

    private var addedTip: String {
        let month = Store.monthLabel(targetMonth)
        return "已添加 \(justAdded) 条到" + month + "，去活动列表查看。"
    }

    private var canAdd: Bool { !selected.isEmpty || justAdded > 0 }

    private var addButtonTitle: String {
        if justAdded > 0 { return "完成" }
        let month = Store.monthLabel(targetMonth)
        return "添加 \(selected.count) 条到" + month
    }

    private func addSelected() {
        let ids = Array(selected)
        justAdded = store.duplicateActivities(ids: ids, toMonth: targetMonth)
        selected = []
        Notifier.shared.refresh(store: store)
    }

    /// 历史活动按月份倒序分组
    private var monthSections: [(key: String, acts: [Activity])] {
        var order: [String] = []
        var map: [String: [Activity]] = [:]
        for act in store.activities {
            let key = store.displayMonthKey(act)
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(act)
        }
        return order.sorted(by: >).map { ($0, map[$0]!.sorted { $0.deadline > $1.deadline }) }
    }

    /// 目标月份里已存在的「同卡同名」活动 key，避免重复添加
    private var existingKeys: Set<String> {
        Set(store.activities(inMonth: targetMonth).map { $0.cardID.uuidString + "|" + $0.title })
    }

    private func alreadyInMonth(_ act: Activity) -> Bool {
        existingKeys.contains(act.cardID.uuidString + "|" + act.title)
    }

    private var selectableCount: Int {
        store.activities.filter { !alreadyInMonth($0) }.count
    }

    var body: some View {
        NavigationView {
            Group {
                if store.activities.isEmpty {
                    Text("还没有历史活动。先手动添加一条，下个月就能一键复制。")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.sub)
                } else {
                    List {
                        Section {
                            Picker("目标月份", selection: $targetMonth) {
                                ForEach(store.visibleMonthKeys(), id: \.self) { key in
                                    Text(Store.monthOptionLabel(key)).tag(key)
                                }
                            }
                        } footer: {
                            Text("勾选以前添加过的活动，复制到目标月份：进度清零、到账清零、提醒规则保留；截止日已过的自动顺延到目标月末。同名活动本月已有则不可重复加。")
                                .font(.system(size: 11.5))
                        }

                        if justAdded > 0 {
                            Section {
                                Text(addedTip)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Palette.green)
                            }
                        }

                        ForEach(monthSections, id: \.key) { section in
                            Section {
                                ForEach(section.acts) { act in
                                    quickAddRow(act)
                                }
                            } header: {
                                Text(Store.monthLabel(section.key))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("快捷添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("全选可选") {
                        selected = Set(store.activities.filter { !alreadyInMonth($0) }.map { $0.id })
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.activities.isEmpty {
                    Button {
                        addSelected()
                    } label: {
                        Text(addButtonTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(Palette.primaryButton.opacity(canAdd ? 1 : 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(!canAdd)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Palette.bg.opacity(0.9))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
