import Foundation

/// Uygulama ile widget'ın ortak klasörü (App Group). Uygulama bakiye/harcama özetini ve SideStore bilgisini
/// buraya widget.json olarak yazar, widget okur. SideStore grup kimliğinin sonuna ekip kimliğini ekleyebildiği için
/// gerçek kimlik paketin imza profilinden (embedded.mobileprovision) okunur. Bu dosya hem uygulamada hem widget'ta derlenir.
enum Ortak {
    static let taban = "group.com.mohammeddilovan.kisiselhesap"
    static let dosya = "widget.json"

    static func profil() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>"),
              let xml = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1)
        else { return nil }
        return (try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil)) as? [String: Any]
    }

    static var grup: String {
        var adaylar: [String] = []
        if let e = profil()?["Entitlements"] as? [String: Any], let g = e["com.apple.security.application-groups"] as? [String] { adaylar += g }
        if let g = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { adaylar += g }
        return adaylar.first { $0.hasPrefix(taban) } ?? adaylar.first ?? taban
    }

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: grup)?.appendingPathComponent(dosya)
    }

    static func oku() -> [String: Any] {
        guard let u = url, let d = try? Data(contentsOf: u),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return [:] }
        return o
    }

    @discardableResult
    static func yaz(_ o: [String: Any]) -> Bool {
        guard let u = url, let d = try? JSONSerialization.data(withJSONObject: o) else { return false }
        return (try? d.write(to: u, options: .atomic)) != nil
    }
}
