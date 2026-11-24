import Foundation
import UserNotifications

final class Notifier {
    static let shared = Notifier()

    private init() { }

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func refresh(store: Store) {
        reschedule(cards: store.cards,
                   activities: store.activities,
                   settings: store.settings)
    }

    func reschedule(cards: [CreditCard], activities: [Activity], settings: AppSettings) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        if settings.billPush {
            for card in cards where card.remind {
                scheduleRepayment(card, center: center)
            }
        }

        if settings.actPush {
            for act in activities where !act.isDone && act.remind != .none {
                scheduleActivity(act, cards: cards, center: center)
            }
        }
    }

    // MARK: 还款提醒

    private func scheduleRepayment(_ card: CreditCard, center: UNUserNotificationCenter) {
        var comps = DateComponents()
        let raw = card.dueDay - card.remindDays
        var day = raw % 28
        if day <= 0 { day += 28 }
        comps.day = day
        comps.hour = 9
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = card.bank + " 还款提醒"
        content.body = "本期应还 " + Fmt.money(card.outstanding) + "，还款日每月 \(card.dueDay) 日"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "repay-" + card.id.uuidString,
                                           content: content,
                                           trigger: trigger)
        center.add(request)
    }

    // MARK: 活动提醒

    private func scheduleActivity(_ act: Activity, cards: [CreditCard], center: UNUserNotificationCenter) {
        var repeats = true
        var comps = DateComponents()

        switch act.remind {
        case .weeklySunday:
            comps.weekday = 1
            comps.hour = 20
        case .weeklyFriday:
            comps.weekday = 6
            comps.hour = 8
        case .monthlyFirst:
            comps.day = 1
            comps.hour = 9
        case .daily:
            comps.hour = 9
        case .dayBefore:
            let target = Calendar.current.date(byAdding: .day, value: -1, to: act.deadline) ?? act.deadline
            var dc = Calendar.current.dateComponents([.month, .day], from: target)
            dc.hour = 9
            comps = dc
            repeats = false
        case .precise:
            // 抢购准时提醒：按用户指定的日期时间，可提前 N 分钟
            guard let at = act.alertAt else { return }
            let fire = at.addingTimeInterval(TimeInterval(-act.leadMinutes * 60))
            guard fire > Date() else { return }
            comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            repeats = false
        case .none:
            return
        }

        let cardName = cards.first(where: { $0.id == act.cardID }).map { $0.short + " ••" + $0.last4 } ?? "信用卡"

        let content = UNMutableNotificationContent()
        content.title = (act.remind == .precise ? "抢购提醒 · " : "活动提醒 · ") + cardName
        content.body = act.title + " · " + act.remainText
            + (act.reward > 0 ? " · 预期收益 " + Fmt.money(act.reward) : "")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        let request = UNNotificationRequest(identifier: "act-" + act.id.uuidString,
                                           content: content,
                                           trigger: trigger)
        center.add(request)
    }
}
