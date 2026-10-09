import Foundation
import UIKit
import Capacitor
import WidgetKit

/// SideStore uygulamayı ücretsiz Apple ID ile imzalar; imza 7 gün geçerlidir.
/// Gerçek bitiş tarihi, paketteki embedded.mobileprovision dosyasındaki ExpirationDate'tir.
@objc(ImzaPlugin)
public class ImzaPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ImzaPlugin"
    public let jsName = "Imza"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "bitis", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pdf", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "ac", returnType: CAPPluginReturnPromise)
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

    /// Başka bir uygulamayı açar (ör. shortcuts:// ile Kestirmeler).
    @objc func ac(_ call: CAPPluginCall) {
        guard let s = call.getString("url"), let url = URL(string: s) else { call.reject("adres yok"); return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url) { ok in ok ? call.resolve() : call.reject("açılamadı") }
        }
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
}
