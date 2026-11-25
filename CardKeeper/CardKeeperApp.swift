import SwiftUI
import UIKit

@main
struct CardKeeperApp: App {
    @StateObject private var store = Store()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.976, green: 0.976, blue: 0.988, alpha: 1)
        appearance.shadowColor = UIColor(white: 0, alpha: 0.08)

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    /// 快捷指令调起时的待记账参数
    @State private var quickPayment: QuickPayment? = nil

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tag(0)
                .tabItem { Label("卡片", systemImage: "creditcard") }

            BillsView()
                .tag(1)
                .tabItem { Label("账单", systemImage: "list.bullet.rectangle") }

            ActivitiesView()
                .tag(2)
                .tabItem { Label("活动", systemImage: "sparkles") }

            StatsView()
                .tag(3)
                .tabItem { Label("统计", systemImage: "chart.bar") }

            ProfileView()
                .tag(4)
                .tabItem { Label("我的", systemImage: "person") }
        }
        .tint(Palette.blue)
        .onAppear {
            Notifier.shared.requestPermission()
            Notifier.shared.refresh(store: store)
        }
        .onOpenURL { url in
            if let p = QuickPayment.from(url: url) {
                quickPayment = p
            }
        }
        .sheet(item: $quickPayment) { payment in
            QuickRecordView(payment: payment)
                .environmentObject(store)
        }
    }
}

// MARK: - 快捷指令快捷记账

/// 由 cardkeeper://record?... 调起，预填参数，确认后写流水并推进活动进度
struct QuickRecordView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    let payment: QuickPayment

    @State private var cardID: UUID? = nil
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var category = ""
    @State private var messages: [String] = []
    @State private var saved = false

    private var amount: Double { Double(amountText) ?? 0 }

    private var selectedCard: CreditCard? {
        store.cards.first(where: { $0.id == cardID })
    }

    /// 保存后将被推进进度的活动
    private var plannedActivities: [Activity] {
        guard let card = selectedCard, amount > 0 else { return [] }
        return store.activities.filter { $0.cardID == card.id && !$0.isDone }
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
                    Section("用哪张卡支付") {
                        Picker("卡片", selection: $cardID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(store.cards) { c in
                                Text(c.bank + " " + c.name + " 尾号" + c.last4).tag(UUID?.some(c.id))
                            }
                        }
                        if cardID == nil, !payment.cardQuery.isEmpty {
                            Text("没找到与「" + payment.cardQuery + "」匹配的卡片，请手动选择。")
                                .font(.system(size: 11.5))
                                .foregroundColor(Palette.orange)
                        }
                    }

                    Section("这笔消费") {
                        HStack {
                            Text("金额")
                            Spacer()
                            Text("¥").foregroundColor(Palette.sub)
                            TextField("0.00", text: amountBinding)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        TextField("商家 / 对象（如 星巴克）", text: $merchant)
                        TextField("分类，留空自动识别", text: $category)
                    }

                    if let card = selectedCard, amount > 0, !plannedActivities.isEmpty {
                        Section {
                            ForEach(plannedActivities) { act in
                                HStack(spacing: 10) {
                                    Image(systemName: act.kind == .amount ? "yensign.circle" : "checkmark.circle")
                                        .font(.system(size: 13))
                                        .foregroundColor(Palette.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(act.title)
                                            .font(.system(size: 13))
                                            .foregroundColor(Palette.text)
                                        Text(act.kind == .amount
                                             ? "将累加 ¥" + Fmt.raw(amount) + " · 当前 " + act.percentText
                                             : "将完成 1 步 · 当前 " + act.percentText)
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Palette.sub)
                                    }
                                    Spacer()
                                    if act.isDone {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(Palette.green)
                                    }
                                }
                            }
                        } header: {
                            Text("将同步推进的活动进度")
                        } footer: {
                            Text("保存后按上面自动推进；按金额活动累加消费额，按次数活动完成一步。")
                                .font(.system(size: 11.5))
                        }
                    }

                    Section {
                        if saved {
                            ForEach(messages, id: \.self) { msg in
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                        .foregroundColor(Palette.green)
                                    Text(msg)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(Palette.green)
                                }
                            }
                            if messages.isEmpty {
                                Text("已记入流水。")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Palette.green)
                            }

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
                                Text("保存并同步活动")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .listRowBackground(Palette.primaryButton)
                            .disabled(cardID == nil || amount <= 0)
                        }
                    }
                }
            }
            .navigationTitle("快捷记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            let matched = store.matchCard(payment.cardQuery)
            cardID = matched?.id ?? store.cards.first?.id
            amountText = payment.amount > 0 ? Fmt.raw(payment.amount) : ""
            merchant = payment.merchant
            category = payment.category
        }
    }

    private func save() {
        guard let card = selectedCard, amount > 0 else { return }
        messages = store.recordFromShortcut(cardID: card.id,
                                            amount: amount,
                                            merchant: merchant,
                                            category: category)
        saved = true
    }
}
