import SwiftUI
import UIKit
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var store: Store

    @State private var editing: CreditCard?
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    profileCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    SectionHeader(title: "提醒设置", trailing: "到点自动通知")
                        .padding(.horizontal, 20)

                    remindCard
                        .padding(.horizontal, 20)

                    SectionHeader(title: "卡片管理", trailing: "\(store.cards.count) 张")
                        .padding(.horizontal, 20)

                    cardManageList
                        .padding(.horizontal, 20)

                    SectionHeader(title: "其他", trailing: "")
                        .padding(.horizontal, 20)

                    otherCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
            }
        }
        .sheet(item: $editing) { card in
            CardEditorView(card: card).environmentObject(store)
        }
        .alert("恢复初始演示数据？", isPresented: $confirmReset) {
            Button("重置", role: .destructive) {
                store.reset()
                Notifier.shared.refresh(store: store)
            }
            Button("取消", role: .cancel) { }
        }
    }

    // MARK: 头部

    private var supplementaryCount: Int {
        store.cards.filter { $0.supplementaryTo != nil }.count
    }

    private var bankGroupCount: Int {
        Set(store.cards.map { store.bankKey($0.bank) }).count
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Fmt.todayLine())
                .font(.system(size: 12.5))
                .foregroundColor(Palette.sub)
            Text("我的")
                .font(.system(size: 29, weight: .bold))
                .foregroundColor(Palette.text)
        }
    }

    // MARK: 个人卡片

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "8FA9FF"), Color(hex: "6C5BFF")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text("卡")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("我的卡包")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(store.cards.count) 张卡"
                         + (supplementaryCount > 0 ? "（含 \(supplementaryCount) 张附属）" : "")
                         + " / \(bankGroupCount) 家银行 · 总授信 " + Fmt.yuan(store.totalLimit))
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()
            }

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)
                .padding(.top, 14)

            HStack(spacing: 0) {
                profileCell("已用额度", Fmt.yuan(store.totalUsed), .white)
                profileCell("可用额度", Fmt.yuan(store.totalAvailable), .white)
                profileCell("待还", Fmt.yuan(store.totalOutstanding), Color(hex: "FFCF8A"))
            }
            .padding(.top, 13)
        }
        .padding(19)
        .background(LinearGradient(colors: [Color(hex: "242A3F"), Color(hex: "3A4260"), Color(hex: "4A4570")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: "1B2038").opacity(0.3), radius: 16, x: 0, y: 10)
    }

    private func profileCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 提醒设置

    private var remindCard: some View {
        CardShell {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconBadge(text: "账", color: Palette.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("出账提醒")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Palette.text)
                        Text("账单日当天 09:00 推送本期账单")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.sub)
                    }
                    Spacer()
                    Toggle("", isOn: $store.settings.billPush)
                        .labelsHidden()
                        .tint(Palette.green)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)

                RowDivider(inset: 48)

                HStack(spacing: 12) {
                    IconBadge(text: "活", color: Palette.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("活动提醒")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Palette.text)
                        Text("按活动设置的周期提前提醒")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.sub)
                    }
                    Spacer()
                    Toggle("", isOn: $store.settings.actPush)
                        .labelsHidden()
                        .tint(Palette.green)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)

                RowDivider(inset: 48)

                HStack(spacing: 12) {
                    IconBadge(text: "静", color: Palette.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("免打扰时段")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Palette.text)
                        Text("23:00 – 08:00 不推送")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.sub)
                    }
                    Spacer()
                    Toggle("", isOn: $store.settings.quietHours)
                        .labelsHidden()
                        .tint(Palette.green)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
            }
        }
        .onChange(of: store.settings.billPush) { _ in
            store.save()
            Notifier.shared.refresh(store: store)
        }
        .onChange(of: store.settings.actPush) { _ in
            store.save()
            Notifier.shared.refresh(store: store)
        }
        .onChange(of: store.settings.quietHours) { _ in
            store.save()
        }
    }

    // MARK: 卡片管理

    private var cardManageList: some View {
        CardShell {
            VStack(spacing: 0) {
                ForEach(Array(store.cards.enumerated()), id: \.offset) { index, card in
                    Button {
                        editing = card
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: [Color(hex: card.colorA), Color(hex: card.colorB)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(card.short.prefix(1)))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(card.bank + " ••" + card.last4)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Palette.text)
                                    Text(store.ownerName(of: card))
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundColor(Palette.purple)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Palette.purple.opacity(0.10))
                                        .clipShape(Capsule())

                                    if card.isSupplementary {
                                        Text("附属卡")
                                            .font(.system(size: 9.5, weight: .medium))
                                            .foregroundColor(Palette.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Palette.orange.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("账单日 \(card.billDay) 日 · 还款日 \(card.dueDay) 日 · " +
                                     (card.remind ? "提前 \(card.remindDays) 天提醒" : "未开启提醒"))
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Palette.sub)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "C7C7CC"))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < store.cards.count - 1 {
                        RowDivider(inset: 59)
                    }
                }
            }
        }
    }

    // MARK: 其他

    private var otherCard: some View {
        CardShell {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconBadge(text: "重", color: Palette.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("重置演示数据")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Palette.text)
                        Text("恢复为初始示例，谨慎操作")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.sub)
                    }
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
                .onTapGesture { confirmReset = true }

                RowDivider(inset: 48)

                HStack(spacing: 12) {
                    IconBadge(text: "版", color: Color(hex: "8E8E93"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("版本")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Palette.text)
                        Text("1.0 · 本地存储，数据不上传")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.sub)
                    }
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
            }
        }
    }
}

// MARK: - 卡片编辑

struct CardEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    @State private var card: CreditCard
    private let isNew: Bool
    /// 新增卡片时默认归入的类别（跟随首页当前筛选）
    private let defaultOwner: String?

    @State private var confirmDelete = false
    @State private var showError = false
    /// 卡面图片来源：拍照 / 相册（iOS 15 上同视图只能挂一个 sheet，用枚举统一驱动）
    @State private var pickSource: PickSource?
    /// 是否设为附属卡（保存时写回 card.supplementaryTo）
    @State private var isSupplementary = false
    /// 选中的主卡 id
    @State private var primaryID: UUID?

    private enum PickSource: String, Identifiable {
        case camera, library
        var id: String { rawValue }
    }

    init(card: CreditCard, isNew: Bool = false, defaultOwner: String? = nil) {
        _card = State(initialValue: card)
        self.isNew = isNew
        self.defaultOwner = defaultOwner
    }

    private var organizations: [String] { ["银联", "VISA", "Mastercard", "AE", "JCB"] }

    /// 可作为主卡的卡片（排除自身与已是附属卡的卡，避免链式附属）
    private var primaryCandidates: [CreditCard] {
        store.primaryCandidates(excluding: card.id)
    }

    private var selectedPrimary: CreditCard? {
        guard let pid = primaryID else { return primaryCandidates.first }
        return store.card(pid) ?? primaryCandidates.first
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationView {
            Form {
                // 与下面的删除确认不能共用多个 .alert（iOS 15 上会互相覆盖），改用内联提示
                if showError {
                    Section {
                        Text("请先填写银行名称")
                            .font(.system(size: 12.5))
                            .foregroundColor(Palette.red)
                    }
                }

                Section("卡片信息") {
                    TextField("银行名称，如 招商银行", text: $card.bank)
                    TextField("卡片名称，如 经典白金卡", text: $card.name)
                    Picker("卡组织", selection: $card.org) {
                        ForEach(organizations, id: \.self) { org in
                            Text(org).tag(org)
                        }
                    }
                    HStack {
                        Text("卡号后四位")
                        Spacer()
                        TextField("0000", text: $card.last4)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }

                Section("卡面") {
                    themeSelector

                    HStack(spacing: 18) {
                        if cameraAvailable {
                            Button {
                                pickSource = .camera
                            } label: {
                                Label("拍照", systemImage: "camera")
                            }
                        }
                        Button {
                            pickSource = .library
                        } label: {
                            Label("从相册选择", systemImage: "photo.on.rectangle")
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 15))

                    if let data = card.photoData, let ui = UIImage(data: data) {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 110)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Palette.line, lineWidth: 0.5)
                                )

                            Button(role: .destructive) {
                                card.photoData = nil
                            } label: {
                                Text("移除自定义卡面，恢复主题配色")
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("归属与分类") {
                    Picker("归属人", selection: Binding(
                        get: { card.owner ?? store.owners.first ?? "本人" },
                        set: { card.owner = $0 }
                    )) {
                        ForEach(store.owners, id: \.self) { o in
                            Text(o).tag(o)
                        }
                    }
                }

                Section {
                    Toggle("这是附属卡", isOn: Binding(
                        get: { isSupplementary },
                        set: { on in
                            isSupplementary = on
                            if on {
                                if primaryID == nil { primaryID = primaryCandidates.first?.id }
                                // 银行还没填时，自动带出主卡的银行，避免附属卡被算进另一家
                                if card.bank.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                   let p = store.card(primaryID ?? primaryCandidates.first?.id ?? card.id) {
                                    card.bank = p.bank
                                }
                            } else {
                                primaryID = nil
                            }
                        }
                    ))
                    .tint(Palette.green)

                    if isSupplementary {
                        if primaryCandidates.isEmpty {
                            Text("还没有可选的主卡。请先添加一张主卡，再回来把它设为附属卡。")
                                .font(.system(size: 12.5))
                                .foregroundColor(Palette.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Picker("主卡", selection: Binding(
                                get: { primaryID ?? primaryCandidates.first?.id ?? card.id },
                                set: { primaryID = $0 }
                            )) {
                                ForEach(primaryCandidates) { p in
                                    Text(p.bank + " ••" + p.last4 + " · " + Fmt.yuan(p.limit)).tag(p.id)
                                }
                            }

                            if let p = selectedPrimary {
                                Text("额度与主卡共享：本卡不单独计入总授信，消费和账单会占用「\(p.short) ••\(p.last4)」所在额度组的额度（同组共用 " + Fmt.yuan(store.groupLimit(store.limitGroupKey(p))) + "）。")
                                    .font(.system(size: 12))
                                    .foregroundColor(Palette.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } header: {
                    Text("附属卡")
                } footer: {
                    Text("附属卡与主卡共用一条信用额度：总授信只按主卡计算一次，主卡和附属卡的已用会合并占用同一条额度。")
                        .font(.system(size: 11.5))
                }

                Section("额度") {
                    if isSupplementary, let p = selectedPrimary {
                        // 附属卡额度由主卡决定，不单独填写
                        HStack {
                            Text("信用额度")
                            Spacer()
                            Text("与主卡共享")
                                .foregroundColor(Palette.sub)
                        }
                        HStack {
                            Text("共享额度")
                            Spacer()
                            Text(Fmt.yuan(store.groupLimit(store.limitGroupKey(p))))
                                .font(.system(size: 15, weight: .semibold))
                        }
                    } else {
                        HStack {
                            Text("信用额度")
                            Spacer()
                            TextField("30000", value: $card.limit, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                    }
                    HStack {
                        Text("已用额度")
                        Spacer()
                        TextField("0", value: $card.used, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("本期已还")
                        Spacer()
                        TextField("0", value: $card.paid, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    if !isSupplementary, !card.bank.isEmpty,
                       store.cards.filter({ store.bankKey($0.bank) == store.bankKey(card.bank) && $0.id != card.id }).count > 0 {
                        Text("⚠️ 「\(card.bank)」还有 \(store.cards.filter { store.bankKey($0.bank) == store.bankKey(card.bank) && $0.id != card.id }.count) 张卡：同银行多卡共享额度，总授信按各行最高额度计算，不做叠加。")
                            .font(.system(size: 12))
                            .foregroundColor(Palette.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("账单周期") {
                    Picker("账单日（出账日）", selection: $card.billDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text("每月 \(day) 日").tag(day)
                        }
                    }
                    Picker("还款日", selection: $card.dueDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text("每月 \(day) 日").tag(day)
                        }
                    }
                }

                Section("提醒") {
                    Toggle("还款提醒", isOn: $card.remind)
                        .tint(Palette.green)
                    if card.remind {
                        Picker("提前天数", selection: $card.remindDays) {
                            ForEach([1, 2, 3, 5, 7], id: \.self) { d in
                                Text("提前 \(d) 天").tag(d)
                            }
                        }
                    }
                }

                Section {
                    Text("账单日与还款日相差 18–25 天较常见。修改后会按新日期重新计算提醒。")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.sub)
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("删除这张卡").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "添加卡片" : "编辑卡片")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: card.bank) { newValue in
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showError = false
                }
            }
            .onAppear {
                if card.owner == nil || card.owner!.isEmpty {
                    card.owner = defaultOwner ?? store.owners.first ?? "本人"
                }
                isSupplementary = card.supplementaryTo != nil
                if primaryID == nil { primaryID = card.supplementaryTo }
            }
            .onChange(of: primaryID) { newValue in
                // 换主卡时，若银行还是空的，跟着主卡走
                guard isSupplementary,
                      card.bank.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let pid = newValue, let p = store.card(pid) else { return }
                card.bank = p.bank
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .alert("删除这张卡？", isPresented: $confirmDelete) {
                Button("删除", role: .destructive) {
                    store.deleteCard(card.id)
                    Notifier.shared.refresh(store: store)
                    dismiss()
                }
                Button("取消", role: .cancel) { }
            }
            .sheet(item: $pickSource) { source in
                switch source {
                case .camera:
                    CameraImagePicker { img in
                        card.photoData = compressedCardImage(img)
                    }
                case .library:
                    PhotoLibraryPicker { img in
                        card.photoData = compressedCardImage(img)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: 卡面主题选择器

    private var themeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CardTheme.all) { theme in
                    themeChip(theme)
                }
            }
            .padding(.vertical, 3)
        }
    }

    private func themeChip(_ theme: CardTheme) -> some View {
        let selected = (card.theme == theme.id && card.photoData == nil)
            || (card.theme == nil && card.photoData == nil && card.colorA == theme.a)

        return Button {
            card.theme = theme.id
            card.colorA = theme.a
            card.colorB = theme.b
            card.photoData = nil
        } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: theme.a), Color(hex: theme.b)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selected ? Palette.blue : Color.white.opacity(0.001), lineWidth: 2.5)
                    )
                    .overlay(
                        Group {
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                    .padding(4)
                            }
                        }
                    )

                Text(theme.name)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? Palette.blue : Palette.sub)
            }
        }
        .buttonStyle(.plain)
    }

    /// 压缩照片：最长边限宽 900，JPEG 0.75，避免撑爆 UserDefaults
    private func compressedCardImage(_ image: UIImage) -> Data? {
        var img = image
        let maxWidth: CGFloat = 900
        if img.size.width > maxWidth {
            let ratio = maxWidth / img.size.width
            let newSize = CGSize(width: maxWidth, height: img.size.height * ratio)
            UIGraphicsBeginImageContextWithOptions(newSize, true, 2)
            img.draw(in: CGRect(origin: .zero, size: newSize))
            if let scaled = UIGraphicsGetImageFromCurrentImageContext() {
                img = scaled
            }
            UIGraphicsEndImageContext()
        }
        return img.jpegData(compressionQuality: 0.75)
    }

    private func save() {
        let bank = card.bank.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bank.isEmpty else {
            showError = true
            return
        }

        card.bank = bank
        if card.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            card.name = "信用卡"
        }
        if card.last4.count > 4 {
            card.last4 = String(card.last4.suffix(4))
        }
        if card.last4.isEmpty {
            card.last4 = "0000"
        }
        if card.limit < 1 {
            card.limit = 1
        }

        // 附属卡关系：勾选了就必须落到一张真实主卡上，否则视为独立卡
        if isSupplementary, let pid = primaryID ?? primaryCandidates.first?.id {
            card.supplementaryTo = pid
            // 附属卡不自带额度，同步一份主卡组的共享额度便于展示
            if let p = store.card(pid) {
                let shared = store.groupLimit(store.limitGroupKey(p))
                if shared > 0 { card.limit = shared }
            }
        } else {
            card.supplementaryTo = nil
        }

        if let index = store.cards.firstIndex(where: { $0.id == card.id }) {
            store.cards[index] = card
        } else {
            store.cards.append(card)
        }

        store.save()
        Notifier.shared.refresh(store: store)
        dismiss()
    }
}

// MARK: - 拍照选卡面（iOS 15 兼容）

struct CameraImagePicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onImage(img)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - 相册选卡面（PHPicker 无需相册权限）

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let item = results.first?.itemProvider,
                  item.canLoadObject(ofClass: UIImage.self) else { return }
            item.loadObject(ofClass: UIImage.self) { object, _ in
                if let img = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.onImage(img)
                    }
                }
            }
        }
    }
}
