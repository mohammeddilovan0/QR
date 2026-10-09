import Foundation
import Capacitor

/// SideStore uygulamayı ücretsiz Apple ID ile imzalar; imza 7 gün geçerlidir.
/// Gerçek bitiş tarihi, paketteki embedded.mobileprovision dosyasındaki ExpirationDate'tir.
@objc(ImzaPlugin)
public class ImzaPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ImzaPlugin"
    public let jsName = "Imza"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "bitis", returnType: CAPPluginReturnPromise)
    ]

    @objc func bitis(_ call: CAPPluginCall) {
        guard let exp = ImzaPlugin.expiration() else {
            call.resolve([:])
            return
        }
        call.resolve(["bitis": exp.timeIntervalSince1970 * 1000])
    }

    static func expiration() -> Date? {
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
}
