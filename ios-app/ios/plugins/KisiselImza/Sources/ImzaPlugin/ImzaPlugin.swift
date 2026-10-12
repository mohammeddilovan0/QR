import Foundation
import UIKit
import Capacitor
import WidgetKit
import UniformTypeIdentifiers

/// SideStore uygulamayı ücretsiz Apple ID ile imzalar; imza 7 gün geçerlidir.
/// Gerçek bitiş tarihi, paketteki embedded.mobileprovision dosyasındaki ExpirationDate'tir.
@objc(ImzaPlugin)
public class ImzaPlugin: CAPPlugin, CAPBridgedPlugin, UIDocumentPickerDelegate {
    public let identifier = "ImzaPlugin"
    public let jsName = "Imza"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "bitis", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pdf", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "yedekDurum", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "yedekKlasor", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "yedekKlasorSil", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "yedekYaz", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "widget", returnType: CAPPluginReturnPromise)
    ]

    @objc func bitis(_ call: CAPPluginCall) {
        // Yenilemeden sonra widget'lar yeni tarihi hemen göstersin.
        WidgetCenter.shared.reloadAllTimelines()
        var r: [String: Any] = [:]
        if let exp = ImzaPlugin.expiration() { r["bitis"] = exp.timeIntervalSince1970 * 1000 }
        // Kestirmeler'deki "SideStore yenilendi" eyleminin (App/Yenileme.swift) yazdığı son yenileme zamanı.
        let yen = UserDefaults.standard.double(forKey: "imzaYenilendi")
        if yen > 0 { r["yenilendi"] = yen * 1000 }
        call.resolve(r)
    }

    static func expiration() -> Date? {
        profil(Bundle.main.bundleURL)?["ExpirationDate"] as? Date
    }

    static func profil(_ bundleURL: URL) -> [String: Any]? {
        let url = bundleURL.appendingPathComponent("embedded.mobileprovision")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>"),
              let xml = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1)
        else { return nil }
        return (try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil)) as? [String: Any]
    }

    /// iOS'taki web görünümü window.print() desteklemiyor. Sayfa yazdırma stiliyle (yalnız #report) A4 PDF'e
    /// çevrilir ve paylaşım menüsü açılır: Dosyalar'a kaydet, WhatsApp, yazdır…
    @objc func pdf(_ call: CAPPluginCall) {
        let ad = (call.getString("ad") ?? "Hesap raporu").replacingOccurrences(of: "/", with: "-")
        DispatchQueue.main.async {
            guard let web = self.bridge?.webView, let vc = self.bridge?.viewController else {
                call.reject("görünüm yok")
                return
            }
            let a4 = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
            let r = UIPrintPageRenderer()
            r.addPrintFormatter(web.viewPrintFormatter(), startingAtPageAt: 0)
            r.setValue(a4, forKey: "paperRect")
            r.setValue(a4.insetBy(dx: 28, dy: 36), forKey: "printableRect")
            let data = NSMutableData()
            UIGraphicsBeginPDFContextToData(data, a4, nil)
            r.prepare(forDrawingPages: NSRange(location: 0, length: r.numberOfPages))
            for i in 0..<r.numberOfPages {
                UIGraphicsBeginPDFPage()
                r.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
            }
            UIGraphicsEndPDFContext()
            guard r.numberOfPages > 0 else { call.reject("rapor boş"); return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(ad + ".pdf")
            do { try data.write(to: url, options: .atomic) } catch { call.reject(error.localizedDescription); return }
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = web
            share.popoverPresentationController?.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 1, height: 1)
            vc.present(share, animated: true) { call.resolve() }
        }
    }

    // MARK: Otomatik yedek
    /// Yedek iki yere yazılır: uygulamanın Belgeler klasörü (Dosyalar → Bu iPhone'da → Kisisel Hesap) ve kullanıcının
    /// bir kez seçtiği klasör (ör. iCloud Drive). Seçilen klasöre erişim, güvenlik kapsamlı yer imiyle saklanır;
    /// böylece her seferinde sormadan yazılabilir. Uygulama silinse de iCloud'daki yedek durur.
    static let klasorAnahtar = "yedekKlasor"
    static let onEk = "kisisel-hesap-oto-"
    static let sakla = 14
    private var klasorCall: CAPPluginCall?

    static func klasor() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: klasorAnahtar) else { return nil }
        var eski = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &eski) else { return nil }
        if eski, url.startAccessingSecurityScopedResource() {
            if let yeni = try? url.bookmarkData() { UserDefaults.standard.set(yeni, forKey: klasorAnahtar) }
            url.stopAccessingSecurityScopedResource()
        }
        return url
    }

    static func klasorAdi(_ url: URL) -> String {
        let ad = FileManager.default.displayName(atPath: url.path)
        return url.path.contains("Mobile Documents") ? "iCloud Drive › \(ad)" : ad
    }

    @objc func yedekDurum(_ call: CAPPluginCall) {
        var r: [String: Any] = [:]
        if UserDefaults.standard.data(forKey: ImzaPlugin.klasorAnahtar) != nil {
            r["secili"] = true
            if let u = ImzaPlugin.klasor() { r["klasor"] = ImzaPlugin.klasorAdi(u) }
        }
        call.resolve(r)
    }

    @objc func yedekKlasor(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let vc = self.bridge?.viewController else { call.reject("görünüm yok"); return }
            self.klasorCall?.resolve(["iptal": true])
            self.klasorCall = call
            let p = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
            p.delegate = self
            p.allowsMultipleSelection = false
            vc.present(p, animated: true)
        }
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let call = klasorCall else { return }
        klasorCall = nil
        guard let url = urls.first else { call.resolve(["iptal": true]); return }
        let acik = url.startAccessingSecurityScopedResource()
        defer { if acik { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try url.bookmarkData()
            UserDefaults.standard.set(data, forKey: ImzaPlugin.klasorAnahtar)
            call.resolve(["klasor": ImzaPlugin.klasorAdi(url)])
        } catch {
            call.reject("Klasör kaydedilemedi: \(error.localizedDescription)")
        }
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        klasorCall?.resolve(["iptal": true])
        klasorCall = nil
    }

    @objc func yedekKlasorSil(_ call: CAPPluginCall) {
        UserDefaults.standard.removeObject(forKey: ImzaPlugin.klasorAnahtar)
        call.resolve()
    }

    /// { ad: "kisisel-hesap-oto-2026-10-11.json", veri: "<json>" } → { yerel, klasor?, hata? }
    @objc func yedekYaz(_ call: CAPPluginCall) {
        guard let ad = call.getString("ad"), ad.hasPrefix(ImzaPlugin.onEk), !ad.contains("/"),
              let veri = call.getString("veri")?.data(using: .utf8) else { call.reject("geçersiz"); return }
        DispatchQueue.global(qos: .utility).async {
            var r: [String: Any] = [:]
            if let belge = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                r["yerel"] = (try? ImzaPlugin.yaz(veri, ad, belge)) != nil
            }
            if UserDefaults.standard.data(forKey: ImzaPlugin.klasorAnahtar) != nil {
                if let u = ImzaPlugin.klasor() {
                    let acik = u.startAccessingSecurityScopedResource()
                    do {
                        try ImzaPlugin.yaz(veri, ad, u)
                        r["klasor"] = ImzaPlugin.klasorAdi(u)
                    } catch {
                        r["hata"] = error.localizedDescription
                    }
                    if acik { u.stopAccessingSecurityScopedResource() }
                } else {
                    r["hata"] = "Seçilen klasör bulunamadı. Klasörü yeniden seçin."
                }
            }
            call.resolve(r)
        }
    }

    /// Dosyayı (iCloud ile çakışmasın diye dosya koordinatörüyle) yazar, en yeni `sakla` otomatik yedeği bırakır.
    static func yaz(_ veri: Data, _ ad: String, _ dir: URL) throws {
        let hedef = dir.appendingPathComponent(ad)
        var hata: NSError?, ic: Error?
        NSFileCoordinator().coordinate(writingItemAt: hedef, options: .forReplacing, error: &hata) { u in
            do { try veri.write(to: u, options: .atomic) } catch { ic = error }
        }
        if let e = hata ?? ic { throw e }
        let fm = FileManager.default
        let eskiler = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
            .filter { $0.hasPrefix(onEk) && $0.hasSuffix(".json") }
            .sorted(by: >)
        for f in eskiler.dropFirst(sakla) {
            NSFileCoordinator().coordinate(writingItemAt: dir.appendingPathComponent(f), options: .forDeleting, error: nil) { u in
                try? fm.removeItem(at: u)
            }
        }
    }

    // MARK: Widget verisi
    /// Uygulama bakiye/harcama özetini widget ile ortak klasöre (App Group) widget.json olarak yazar.
    /// Grup kimliği App/ImzaWidget içindeki Ortak.swift ile aynı kuralla bulunur (bu paket o dosyayı göremez).
    static func ortakDosya() -> URL? {
        let taban = "group.com.mohammeddilovan.kisiselhesap"
        var adaylar: [String] = []
        if let e = profil(Bundle.main.bundleURL)?["Entitlements"] as? [String: Any],
           let g = e["com.apple.security.application-groups"] as? [String] { adaylar += g }
        if let g = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { adaylar += g }
        let grup = adaylar.first { $0.hasPrefix(taban) } ?? adaylar.first ?? taban
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: grup)?.appendingPathComponent("widget.json")
    }

    @objc func widget(_ call: CAPPluginCall) {
        guard let veri = call.getString("veri")?.data(using: .utf8),
              var yeni = (try? JSONSerialization.jsonObject(with: veri)) as? [String: Any] else { call.reject("veri yok"); return }
        guard let url = ImzaPlugin.ortakDosya() else { call.resolve(["grup": false]); return }
        // Kestirmeler'in yazdığı yenileme zamanı daha yeniyse korunur.
        if let d = try? Data(contentsOf: url), let eski = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
           let y = eski["yenilendi"] as? Double, y > (yeni["yenilendi"] as? Double ?? 0) { yeni["yenilendi"] = y }
        guard let out = try? JSONSerialization.data(withJSONObject: yeni), (try? out.write(to: url, options: .atomic)) != nil else {
            call.resolve(["grup": false]); return
        }
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve(["grup": true])
    }
}
