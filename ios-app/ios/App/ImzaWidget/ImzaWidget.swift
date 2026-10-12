import WidgetKit
import SwiftUI

// İki widget: "Hesap" (bakiye, bu ay harcanan, SideStore süresi) ve "Uygulama süresi" (yalnız SideStore süresi).
// Para bilgisini uygulama ortak klasöre yazar (Ortak.swift); okunamazsa widget yalnız süreyi gösterir.
// Süre: paketin kendi imza profili + uygulamanın / Kestirmeler'in kaydettiği yenileme zamanı (Refresh All
// paketteki profili değiştirmediği için yalnız profile bakmak eski süreyi gösterir).

let kirmizi = Color(red: 0.85, green: 0.19, blue: 0.15)
let yesil = Color(red: 0.12, green: 0.44, blue: 0.36)

func kalanYazi(_ now: Date, _ bitis: Date) -> String {
    let s = bitis.timeIntervalSince(now)
    if s <= 0 { return "Süre doldu" }
    let g = Int(s / 86400), h = Int(s.truncatingRemainder(dividingBy: 86400) / 3600)
    if g > 0 { return h > 0 ? "\(g) gün \(h) sa" : "\(g) gün" }
    return "\(max(1, Int(s / 3600))) saat"
}

func kisaKalan(_ now: Date, _ bitis: Date) -> String {
    let s = bitis.timeIntervalSince(now)
    if s <= 0 { return "0s" }
    return s >= 86400 ? "\(Int(s / 86400))g" : "\(max(1, Int(s / 3600)))s"
}

struct Para {
    let bakiye, bakiyeK, bakiyeL, harcama, harcamaK, gelir, bugun, ay: String
    let guncel: Date
}

struct Entry: TimelineEntry {
    let date: Date
    let bitis: Date?
    let para: Para?
}

func veriOku() -> (Date?, Para?) {
    let o = Ortak.oku()
    var b = Ortak.profil()?["ExpirationDate"] as? Date
    let ms = { (k: String) -> Double in (o[k] as? Double) ?? Double(o[k] as? Int ?? 0) }
    // Uygulamanın hesapladığı bitiş ve Kestirmeler'deki son yenileme + 7 gün: hangisi daha geçse o.
    for t in [ms("bitis"), ms("yenilendi") > 0 ? ms("yenilendi") + 7 * 86400 * 1000 : 0] where t > 0 {
        let d = Date(timeIntervalSince1970: t / 1000)
        if b == nil || d > b! { b = d }
    }
    let s = { (k: String) -> String in o[k] as? String ?? "" }
    let para = s("bakiye").isEmpty ? nil : Para(bakiye: s("bakiye"), bakiyeK: s("bakiyeK"), bakiyeL: s("bakiyeL"),
        harcama: s("harcama"), harcamaK: s("harcamaK"), gelir: s("gelir"), bugun: s("bugun"), ay: s("ay"),
        guncel: Date(timeIntervalSince1970: ms("guncel") / 1000))
    return (b, para)
}

let ornek = Para(bakiye: "4,265,000 IQD", bakiyeK: "4.3M", bakiyeL: "Net servet", harcama: "235,000 IQD", harcamaK: "235K",
                 gelir: "500,000 IQD", bugun: "12,000 IQD", ay: "Ekim", guncel: Date())

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), bitis: Date().addingTimeInterval(5 * 86400), para: ornek) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let (b, p) = veriOku()
        completion(Entry(date: Date(), bitis: b ?? Date().addingTimeInterval(5 * 86400), para: p ?? (context.isPreview ? ornek : nil)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let (b, p) = veriOku()
        // Kalan süre saat başlarında güncellenir; para bilgisi uygulama her kaydettiğinde yenilenir.
        let hour = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        var entries = [Entry(date: now, bitis: b, para: p)]
        for i in 1...48 { entries.append(Entry(date: hour.addingTimeInterval(Double(i) * 3600), bitis: b, para: p)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension View {
    @ViewBuilder func arkaPlan(_ c: Color) -> some View {
        if #available(iOS 17.0, *) { containerBackground(c, for: .widget) } else { background(c) }
    }
}

extension Entry {
    var kalan: TimeInterval { bitis.map { $0.timeIntervalSince(date) } ?? 0 }
    var acil: Bool { bitis != nil && kalan < 2 * 86400 }
    var sureYazi: String { bitis.map { kalanYazi(date, $0) } ?? "Uygulamayı aç" }
}

/// Para widget'larının altındaki küçük SideStore satırı; 2 günden az kalınca kırmızı.
struct SureSatiri: View {
    let entry: Entry
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: entry.acil ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
            Text(entry.acil ? "Yenile: \(entry.sureYazi)" : entry.sureYazi).lineLimit(1)
        }
        .font(.caption2.weight(entry.acil ? .bold : .regular))
        .padding(.horizontal, entry.acil ? 6 : 0).padding(.vertical, entry.acil ? 2 : 0)
        .background(entry.acil ? kirmizi : Color.clear)
        .clipShape(Capsule())
        .opacity(entry.acil ? 1 : 0.8)
    }
}

struct HesapWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry

    var body: some View {
        if let p = entry.para { dolu(p) } else { bos }
    }

    @ViewBuilder func dolu(_ p: Para) -> some View {
        switch family {
        case .accessoryInline:
            Text("💰 \(p.bakiyeK) · \(p.ay) −\(p.harcamaK)")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(String(p.ay.prefix(3))).font(.system(size: 10))
                    Text(p.harcamaK).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
                }.padding(2)
            }
            .arkaPlan(.clear)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(p.bakiyeL).font(.caption2)
                Text(p.bakiye).font(.headline).minimumScaleFactor(0.6).lineLimit(1)
                Text("\(p.ay): −\(p.harcamaK) · 📲 \(entry.bitis.map { kisaKalan(entry.date, $0) } ?? "?")").font(.caption2).lineLimit(1)
            }
            .arkaPlan(.clear)
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.bakiyeL).font(.caption).opacity(0.85)
                    Text(p.bakiye).font(.system(size: 24, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                    Spacer(minLength: 0)
                    SureSatiri(entry: entry)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    satir("\(p.ay) harcama", p.harcama)
                    satir("\(p.ay) gelir", p.gelir)
                    satir("Bugün", p.bugun)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .arkaPlan(yesil)
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(p.bakiyeL).font(.caption).opacity(0.85)
                Text(p.bakiye).font(.system(size: 20, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                Spacer(minLength: 0)
                Text("\(p.ay) harcama").font(.caption2).opacity(0.85)
                Text(p.harcama).font(.system(size: 15, weight: .semibold)).minimumScaleFactor(0.5).lineLimit(1)
                Spacer(minLength: 0)
                SureSatiri(entry: entry)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .arkaPlan(yesil)
        }
    }

    func satir(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l).font(.caption2).opacity(0.85)
            Text(v).font(.system(size: 14, weight: .semibold)).minimumScaleFactor(0.5).lineLimit(1)
        }
    }

    /// Para bilgisi yoksa (uygulama henüz açılmadı ya da ortak klasör kullanılamıyor) yalnız süre.
    var bos: some View { SureWidgetView(entry: entry) }
}

struct SureWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry

    var body: some View {
        let b = entry.bitis, yazi = entry.sureYazi
        switch family {
        case .accessoryInline:
            Text("📲 \(yazi)")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.acil ? "exclamationmark.arrow.circlepath" : "arrow.triangle.2.circlepath")
                    Text(b.map { kisaKalan(entry.date, $0) } ?? "?").font(.system(size: 14, weight: .bold))
                }
            }
            .arkaPlan(.clear)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Kisisel Hesap").font(.caption2)
                Text(yazi).font(.headline)
                Text(entry.acil ? "SideStore'dan yenile!" : "SideStore süresi").font(.caption2)
            }
            .arkaPlan(.clear)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: entry.acil ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                    .font(.title3)
                Spacer(minLength: 0)
                Text("Uygulama süresi").font(.caption).opacity(0.85)
                Text(yazi).font(.system(size: 24, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
                Text(entry.acil ? "SideStore → Refresh All" : (b.map { $0.formatted(.dateTime.weekday(.wide).hour().minute()) } ?? ""))
                    .font(.caption2).opacity(0.85).lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .arkaPlan(entry.acil ? kirmizi : yesil)
        }
    }
}

struct HesapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HesapWidget", provider: Provider()) { entry in
            HesapWidgetView(entry: entry)
        }
        .configurationDisplayName("Hesap")
        .description("Bakiye, bu ay harcanan ve uygulama süresi.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct ImzaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ImzaWidget", provider: Provider()) { entry in
            SureWidgetView(entry: entry)
        }
        .configurationDisplayName("Uygulama süresi")
        .description("SideStore yenilemesine kalan süre.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct ImzaWidgets: WidgetBundle {
    var body: some Widget {
        HesapWidget()
        ImzaWidget()
    }
}
