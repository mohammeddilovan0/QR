import WidgetKit
import SwiftUI
import ActivityKit

// SideStore imzasının bitişine kalan süre: ana ekran / kilit ekranı widget'ı ve son 24 saatteki canlı sayaç (Live Activity).
// Widget, uygulamayla birlikte imzalandığı için kendi embedded.mobileprovision dosyasından aynı bitiş tarihini okur.

/// Uygulamadaki ImzaPlugin ile aynı tanım (ActivityKit türü adından eşleştirir).
struct ImzaAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var bitis: Date
    }
}

func profilBitis() -> Date? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .isoLatin1),
          let start = text.range(of: "<?xml"),
          let end = text.range(of: "</plist>"),
          let xml = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1)
    else { return nil }
    let plist = (try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil)) as? [String: Any]
    return plist?["ExpirationDate"] as? Date
}

let kirmizi = Color(red: 0.85, green: 0.19, blue: 0.15)
let yesil = Color(red: 0.12, green: 0.44, blue: 0.36)

func kalanYazi(_ now: Date, _ bitis: Date) -> String {
    let s = bitis.timeIntervalSince(now)
    if s <= 0 { return "Süre doldu" }
    let g = Int(s / 86400), h = Int(s.truncatingRemainder(dividingBy: 86400) / 3600)
    if g > 0 { return h > 0 ? "\(g) gün \(h) sa" : "\(g) gün" }
    return "\(max(1, Int(s / 3600))) saat"
}

struct Entry: TimelineEntry {
    let date: Date
    let bitis: Date?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), bitis: Date().addingTimeInterval(5 * 86400)) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), bitis: profilBitis() ?? Date().addingTimeInterval(5 * 86400)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date(), b = profilBitis()
        // Saat başlarında güncellenir; 2 günlük kayıt, sonra yeniden istenir.
        let hour = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        var entries = [Entry(date: now, bitis: b)]
        for i in 1...48 { entries.append(Entry(date: hour.addingTimeInterval(Double(i) * 3600), bitis: b)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension View {
    @ViewBuilder func arkaPlan(_ c: Color) -> some View {
        if #available(iOS 17.0, *) { containerBackground(c, for: .widget) } else { background(c) }
    }
}

struct ImzaWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry

    var body: some View {
        let b = entry.bitis
        let left = b.map { $0.timeIntervalSince(entry.date) } ?? 0
        let acil = b != nil && left < 2 * 86400
        let yazi = b.map { kalanYazi(entry.date, $0) } ?? "Uygulamayı aç"
        switch family {
        case .accessoryInline:
            Text("📲 \(yazi)")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: acil ? "exclamationmark.arrow.circlepath" : "arrow.triangle.2.circlepath")
                    Text(b.map { left >= 86400 ? "\(Int(left / 86400))g" : "\(max(0, Int(left / 3600)))s" } ?? "?")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .arkaPlan(.clear)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Kisisel Hesap").font(.caption2)
                Text(yazi).font(.headline)
                Text(acil ? "SideStore'dan yenile!" : "SideStore süresi").font(.caption2)
            }
            .arkaPlan(.clear)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: acil ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                    .font(.title3)
                Spacer(minLength: 0)
                Text("Uygulama süresi").font(.caption).opacity(0.85)
                Text(yazi).font(.system(size: 24, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
                Text(acil ? "SideStore → Refresh All" : (b.map { $0.formatted(.dateTime.weekday(.wide).hour().minute()) } ?? ""))
                    .font(.caption2).opacity(0.85).lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(acil ? 0 : 0)
            .arkaPlan(acil ? kirmizi : yesil)
        }
    }
}

struct ImzaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ImzaWidget", provider: Provider()) { entry in
            ImzaWidgetView(entry: entry)
        }
        .configurationDisplayName("Uygulama süresi")
        .description("SideStore yenilemesine kalan süre.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// Geri sayım: geçmiş bir tarih verilirse çökmemesi için aralık en az 1 sn.
func sayac(_ bitis: Date) -> ClosedRange<Date> {
    let now = Date()
    return now...max(bitis, now.addingTimeInterval(1))
}

struct ImzaCanli: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ImzaAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.arrow.circlepath").font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kisisel Hesap süresi doluyor").font(.headline)
                    Text("SideStore → My Apps → Refresh All").font(.caption)
                }
                Spacer()
                Text(timerInterval: sayac(context.state.bitis), countsDown: true)
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 96)
            }
            .padding()
            .foregroundColor(.white)
            .activityBackgroundTint(kirmizi)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "exclamationmark.arrow.circlepath").font(.title2).foregroundColor(kirmizi)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: sayac(context.state.bitis), countsDown: true)
                        .font(.title3.monospacedDigit()).frame(width: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Kisisel Hesap · SideStore → Refresh All").font(.caption)
                }
            } compactLeading: {
                Image(systemName: "exclamationmark.arrow.circlepath").foregroundColor(kirmizi)
            } compactTrailing: {
                Text(timerInterval: sayac(context.state.bitis), countsDown: true)
                    .monospacedDigit().frame(width: 56)
            } minimal: {
                Image(systemName: "exclamationmark.arrow.circlepath").foregroundColor(kirmizi)
            }
        }
    }
}

@main
struct ImzaWidgets: WidgetBundle {
    var body: some Widget {
        ImzaWidget()
        ImzaCanli()
    }
}
