import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store

    /// iOS 15/16 上同一个视图只能有一个 sheet 生效，所以用单一枚举驱动
    private enum Sheet: Identifiable {
        case edit(CreditCard)
        case add
        case owners
        case addOwner

        var id: String {
            switch self {
            case .edit(let card): return card.id.uuidString
            case .add: return "new-card"
            case .owners: return "manage-owners"
            case .addOwner: return "new-owner"
            }
        }
    }

    @State private var sheet: Sheet?
    @State private var drawerOpen = false
    @State private var ownerFilter: String? = nil

    private var shownCards: [CreditCard] { store.sortedForDisplay(store.ownedCards(ownerFilter)) }

    private var shownOutstanding: Double { shownCards.reduce(0) { $0 + $1.outstanding } }
    private var shownBill: Double { shownCards.reduce(0) { $0 + $1.billTotal } }
    private var shownPaid: Double { shownCards.reduce(0) { $0 + $1.paid } }
    private var shownPaidRatio: Double {
        shownBill > 0 ? min(1, shownPaid / shownBill) : 0
    }
    private var shownNearest: CreditCard? {
        shownCards.filter { !$0.isCleared }
            .sorted { DateHelp.daysToDue($0.dueDay) < DateHelp.daysToDue($1.dueDay) }
            .first
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    overview
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    SectionHeader(title: ownerFilter.map { "\($0)的卡片" } ?? "我的卡片",
                                  trailing: "\(shownCards.count) 张 · 左右滑动")
                        .padding(.horizontal, 20)

                    cardStrip

                    SectionHeader(title: "近期提醒", trailing: "\(alerts.count) 条待处理")
                        .padding(.horizontal, 20)

                    alertsCard
                        .padding(.horizontal, 20)

                    SectionHeader(title: "在用权益", trailing: "本月")
                        .padding(.horizontal, 20)

                    rightsCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
            }

            // 从屏幕左边缘右滑打开分类栏（只占 22pt，不影响正常滑动）
            if !drawerOpen {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 22)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 15)
                                .onEnded { value in
                                    if value.translation.width > 40 { openDrawer() }
                                }
                        )
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()
            }

            if drawerOpen {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .onTapGesture { closeDrawer() }

                drawer
            }
        }
        .animation(.easeOut(duration: 0.22), value: drawerOpen)
        .sheet(item: $sheet, onDismiss: { closeDrawer() }) { item in
            switch item {
            case .edit(let card):
                CardEditorView(card: card).environmentObject(store)
            case .add:
                CardEditorView(card: CreditCard.empty, isNew: true, defaultOwner: ownerFilter)
                    .environmentObject(store)
            case .owners:
                OwnerManagerView().environmentObject(store)
            case .addOwner:
                AddOwnerView(onAdded: { name in
                    ownerFilter = name
                })
                .environmentObject(store)
            }
        }
    }

    private func openDrawer() {
        drawerOpen = true
    }

    private func closeDrawer() {
        drawerOpen = false
    }

    // MARK: 侧滑栏

    private var drawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("卡片分类")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                    Text("按归属人查看卡片")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    closeDrawer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    drawerRow(title: "全部卡片",
                              subtitle: "\(store.cards.count) 张",
                              selected: ownerFilter == nil) {
                        ownerFilter = nil
                        closeDrawer()
                    }

                    ForEach(store.owners, id: \.self) { o in
                        drawerRow(title: o,
                                  subtitle: "\(store.ownedCards(o).count) 张",
                                  selected: ownerFilter == o) {
                            ownerFilter = o
                            closeDrawer()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Divider()
                .background(Color.white.opacity(0.10))

            Button {
                sheet = .addOwner
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("新增归属人")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)

            Button {
                sheet = .owners
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                    Text("管理分类")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)

            Text("卡管家 v1.6")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.28))
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 20)
        }
        .frame(width: 268)
        .frame(maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: "242A3F"), Color(hex: "161925")],
                                   startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
        .transition(.move(edge: .leading))
    }

    private func drawerRow(title: String, subtitle: String,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(selected ? Color.white.opacity(0.20) : Color.white.opacity(0.07))
                    Text(String(title.prefix(1)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 30, height: 30)

                Text(title)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(selected ? Color.white.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.todayLine())
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.sub)
                Text("我的卡片")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundColor(Palette.text)
            }

            Spacer()

            Button {
                openDrawer()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .bold))
                    Text(ownerFilter ?? "全部")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Palette.text)
                .padding(.horizontal, 11)
                .frame(height: 32)
                .background(Color(hex: "767680").opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

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

    // MARK: 总览

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ownerFilter.map { "\($0)名下应还合计" } ?? "本月应还合计")
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.58))

            Text(Fmt.money(shownOutstanding))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)

            HStack(spacing: 8) {
                Text("\(shownCards.count) 张卡 · 已还 " + Fmt.money(shownPaid))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let nearest = shownNearest {
                    PillView(text: nearest.short + " " + nearest.dueLabel,
                             fg: Color(hex: "FFCF8A"),
                             bg: Color(hex: "FF9F0A").opacity(0.16))
                } else {
                    PillView(text: "全部已还清",
                             fg: Color(hex: "9BE8B4"),
                             bg: Color(hex: "2CC15D").opacity(0.16))
                }
            }
            .padding(.top, 9)

            BarView(value: shownPaidRatio, height: 5)
                .padding(.top, 14)

            HStack(spacing: 14) {
                legendDot(Color(hex: "6E8BFF"), "已还 \(Int(shownPaidRatio * 100))%")
                legendDot(Color.white.opacity(0.25), "账单合计 " + Fmt.money(shownBill))
                Spacer()
            }
            .padding(.top, 11)
        }
        .padding(20)
        .background(Palette.darkGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: "121628").opacity(0.35), radius: 18, x: 0, y: 12)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: 卡片横滑

    private var cardStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if shownCards.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "B8B8BE"))
                        Text("「\(ownerFilter ?? "")」名下还没有卡片")
                            .font(.system(size: 12.5))
                            .foregroundColor(Color(hex: "A0A0A5"))
                        Text("点右上角 + 添加，编辑卡片时选择归属人")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "A0A0A5").opacity(0.75))
                    }
                    .frame(width: 296, height: 180)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    ForEach(shownCards) { card in
                        CardFace(card: card, supplementaryLabel: store.supplementaryLabel(for: card))
                            .frame(width: 296)
                            .onTapGesture {
                                sheet = .edit(card)
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 3)
        }
    }

    // MARK: 提醒

    private var alerts: [AlertItem] {
        var list: [AlertItem] = []

        let owing = store.cards
            .filter { !$0.isCleared }
            .sorted { DateHelp.daysToDue($0.dueDay) < DateHelp.daysToDue($1.dueDay) }

        for c in owing.prefix(2) {
            list.append(AlertItem(
                icon: "还",
                color: Palette.red,
                title: c.bank + " 还款提醒",
                subtitle: "每月 \(c.dueDay) 日 · " + c.dueLabel,
                trailing: Fmt.money(c.outstanding),
                warning: true))
        }

        // 年费即将扣取
        for c in store.cards where c.feeInfo.amount > 0 && c.feeInfo.remind {
            let left = store.feeDaysLeft(for: c)
            if left <= c.feeInfo.remindDays {
                let waived = store.feeWaived(c)
                list.append(AlertItem(
                    icon: "费",
                    color: waived ? Palette.green : Palette.orange,
                    title: c.short + " 年费 " + Fmt.yuan(c.feeInfo.amount),
                    subtitle: Fmt.monthDay(store.nextFeeDate(for: c)) + " 扣取 · "
                        + store.feeProgressText(c) + (waived ? " · 已达标" : ""),
                    trailing: waived ? "可免" : "剩 \(left) 天",
                    warning: !waived))
            }
        }

        for a in store.activities.filter({ !$0.isDone }).prefix(2) {
            let left = max(0, DateHelp.daysToDeadline(a.deadline))
            list.append(AlertItem(
                icon: "活",
                color: Palette.purple,
                title: a.title,
                subtitle: store.cardName(a.cardID) + " · " + Fmt.monthDay(a.deadline) + " 截止 · 剩 \(left) 天",
                trailing: a.remainText,
                warning: false))
        }

        return list
    }

    private var alertsCard: some View {
        CardShell {
            VStack(spacing: 0) {
                ForEach(Array(alerts.enumerated()), id: \.offset) { index, item in
                    alertRow(item)
                    if index < alerts.count - 1 {
                        RowDivider()
                    }
                }
            }
        }
    }

    private func alertRow(_ item: AlertItem) -> some View {
        HStack(spacing: 12) {
            IconBadge(text: item.icon, color: item.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Palette.text)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(Palette.sub)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(item.trailing)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(item.warning ? Palette.red : Palette.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }

    // MARK: 权益

    private var rightsCard: some View {
        CardShell {
            HStack(spacing: 12) {
                IconBadge(text: "卡", color: Palette.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("可参与活动 \(store.activities.filter { !$0.isDone }.count) 个")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Palette.text)
                    Text("已完成 \(store.activities.filter { $0.isDone }.count) 个 · 全部清晰可见")
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.sub)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "C7C7CC"))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    var icon: String
    var color: Color
    var title: String
    var subtitle: String
    var trailing: String
    var warning: Bool
}

// MARK: - 分类管理

struct OwnerManagerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    @State private var newName = ""
    @State private var tip = ""
    @State private var editingIndex: Int? = nil
    @State private var editingName = ""
    @State private var showRename = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("如 父亲 / 母亲 / 配偶", text: $newName)

                    Button {
                        let n = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !n.isEmpty else { return }
                        store.addOwner(n)
                        newName = ""
                        tip = "已新增「\(n)」"
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加到分类列表")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !tip.isEmpty {
                        Text(tip)
                            .font(.system(size: 12))
                            .foregroundColor(Palette.green)
                    }
                } header: {
                    Text("新增分类")
                }

                Section {
                    ForEach(Array(store.owners.indices), id: \.self) { index in
                        HStack {
                            Text(store.owners[index])
                            Spacer()
                            Text("\(store.ownedCards(store.owners[index]).count) 张")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.sub)

                            Button {
                                editingIndex = index
                                editingName = store.owners[index]
                                showRename = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(Palette.blue)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets.sorted(by: >) {
                            store.deleteOwner(at: i)
                        }
                    }
                } header: {
                    Text("已有分类")
                } footer: {
                    Text("左滑删除分类，点铅笔改名。删除后该分类下的卡片会转移到第一个分类。")
                        .font(.system(size: 11.5))
                }

                Section {
                    Text("卡片的归属人在「编辑卡片 → 归属与分类」里修改；首页左上角的分类按钮和左边缘右滑都能打开分类栏。")
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.sub)
                }
            }
            .navigationTitle("管理分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showRename) {
                renameSheet
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var renameSheet: some View {
        NavigationView {
            Form {
                Section("分类名称") {
                    TextField("名称", text: $editingName)
                }
                Section {
                    Button {
                        if let i = editingIndex {
                            store.renameOwner(at: i, to: editingName)
                        }
                        showRename = false
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Palette.primaryButton)
                }
            }
            .navigationTitle("重命名分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showRename = false }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - 新增归属人

struct AddOwnerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    private let onAdded: (String) -> Void

    @State private var name = ""

    init(onAdded: @escaping (String) -> Void = { _ in }) {
        self.onAdded = onAdded
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("如 父亲 / 母亲 / 配偶", text: $name)
                } header: {
                    Text("新增归属人")
                } footer: {
                    Text("新增后可按归属人筛选卡片，编辑卡片时也能选中它。")
                        .font(.system(size: 11.5))
                }

                Section {
                    Button {
                        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !n.isEmpty else { return }
                        store.addOwner(n)
                        onAdded(n)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Palette.primaryButton)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("新增归属人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
