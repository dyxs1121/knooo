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

        var id: String {
            switch self {
            case .detail(let act): return act.id.uuidString
            case .add: return "new-activity"
            }
        }
    }

    @State private var scope: Scope = .all
    @State private var sheet: Sheet?

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

                    segmented
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

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

    private var doingCount: Int { store.activities.filter { !$0.isDone }.count }
    private var doneCount: Int { store.activities.filter { $0.isDone }.count }

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

    /// 活动收益总览
    private var earnStrip: some View {
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var nearestHint: String {        let pending = store.activities.filter { !$0.isDone }
        guard let first = pending.min(by: { $0.deadline < $1.deadline }) else {
            return "暂无待办"
        }
        let left = max(0, DateHelp.daysToDeadline(first.deadline))
        return "最近截止剩 \(left) 天"
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
        case .all: return "全部 \(store.activities.count)"
        case .doing: return "进行中 \(doingCount)"
        case .done: return "已完成 \(doneCount)"
        }
    }

    // MARK: 列表

    private var filtered: [Activity] {
        switch scope {
        case .all: return store.activities
        case .doing: return store.activities.filter { !$0.isDone }
        case .done: return store.activities.filter { $0.isDone }
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
    @State private var earnedText = ""

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
        earnedText = act.earned > 0 ? numText(act.earned) : ""
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
                Text(act.earned > 0 ? "已到账 " + Fmt.yuan(act.earned) : "尚未到账")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(act.earned > 0 ? Palette.green : Palette.sub)
            }

            HStack(spacing: 10) {
                rewardField(title: "预期奖励", text: $rewardText)
                rewardField(title: "已到账", text: $earnedText)
            }
            .padding(.top, 11)

            HStack(spacing: 8) {
                Button {
                    store.setEarned(activityID: activityID, earned: act.reward)
                    syncRewardFields()
                } label: {
                    Text("按预期全部到账")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.blue.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    store.setReward(activityID: activityID, reward: Double(rewardText) ?? 0)
                    store.setEarned(activityID: activityID, earned: Double(earnedText) ?? 0)
                    syncRewardFields()
                } label: {
                    Text("保存收益")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Palette.primaryButton)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 11)
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
    @State private var deadline = Date().addingTimeInterval(86400 * 14)
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
