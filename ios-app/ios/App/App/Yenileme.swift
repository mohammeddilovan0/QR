import Foundation
import AppIntents
import UserNotifications

/// SideStore'un Refresh All'ı uygulamayı yeniden kurmaz, telefona yeni imza profili yükler; paketteki
/// embedded.mobileprovision eski kalır. Kestirmeler eylemi yenileme zamanını buraya yazar, uygulama
/// (ImzaPlugin.bitis) okur. Uygulama açılmadan da hatırlatmalar yeni bitişe göre kurulur.
enum Yenileme {
    static let anahtar = "imzaYenilendi"

    static var tarih: Date? {
        let t = UserDefaults.standard.double(forKey: anahtar)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    static func kaydet() {
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: anahtar)
        planla(bitis: now.addingTimeInterval(7 * 86400))
    }

    /// index.html'deki imzaPlanla ile aynı: 2 gün kala bir bildirim, son 24 saatte saat başı (kimlikler 2001, 2010-2039).
    static func planla(bitis b: Date) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ([2001, 2002, 2003] + Array(2010..<2040)).map(String.init))
        let now = Date()
        func ekle(_ id: Int, _ at: Date, _ body: String) {
            let content = UNMutableNotificationContent()
            content.title = "SideStore yenilemesi 📲"
            content.body = body
            content.sound = UNNotificationSound(named: UNNotificationSoundName("kalk-zil.wav"))
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: at)
            c.add(UNNotificationRequest(identifier: String(id), content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
        let iki = b.addingTimeInterval(-2 * 86400)
        if iki > now.addingTimeInterval(60) {
            ekle(2001, iki, "Uygulamanın süresi 2 gün sonra doluyor. SideStore'u aç → My Apps → Refresh All.")
        }
        var t = b.addingTimeInterval(-86400)
        if let saat = Calendar.current.dateInterval(of: .hour, for: t), saat.start != t { t = saat.end }
        var i = 0
        while t < b && i < 24 {
            if t > now.addingTimeInterval(60) {
                let h = max(1, Int((b.timeIntervalSince(t) / 3600).rounded(.up)))
                ekle(2010 + i, t, "\(h == 1 ? "Son 1 saat!" : "\(h) saat kaldı.") SideStore → My Apps → Refresh All.")
            }
            t = t.addingTimeInterval(3600)
            i += 1
        }
    }
}

@available(iOS 16.0, *)
struct YenilendiIntent: AppIntent {
    static var title: LocalizedStringResource = "SideStore yenilendi"
    static var description = IntentDescription("Kisisel Hesap'ın süresini şu andan 7 gün olarak kaydeder. SideStore'un Refresh All eyleminden sonra çalıştır.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        Yenileme.kaydet()
        return .result(dialog: "Kisisel Hesap süresi 7 gün olarak güncellendi.")
    }
}

/// Eylem Kestirmeler'de kurulum gerekmeden görünsün.
@available(iOS 16.0, *)
struct KisiselKestirmeler: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: YenilendiIntent(), phrases: ["\(.applicationName) SideStore yenilendi"])
    }
}
