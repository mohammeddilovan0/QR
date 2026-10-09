import Foundation
import Capacitor
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// SideStore uygulamayı ücretsiz Apple ID ile imzalar; imza 7 gün geçerlidir.
/// Gerçek bitiş tarihi, paketteki embedded.mobileprovision dosyasındaki ExpirationDate'tir.
@objc(ImzaPlugin)
public class ImzaPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ImzaPlugin"
    public let jsName = "Imza"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "bitis", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "canliDurum", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "canliBaslat", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "canliBitir", returnType: CAPPluginReturnPromise)
    ]

    @objc func bitis(_ call: CAPPluginCall) {
        // Yenilemeden sonra widget'lar yeni tarihi hemen göstersin.
        WidgetCenter.shared.reloadAllTimelines()
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

    // MARK: Canlı sayaç (Live Activity, son 24 saat)

    @objc func canliDurum(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            let aktif = Activity<ImzaAttributes>.activities.contains { $0.activityState == .active }
            call.resolve(["destek": true, "izin": ActivityAuthorizationInfo().areActivitiesEnabled, "aktif": aktif])
            return
        }
        #endif
        call.resolve(["destek": false, "izin": false, "aktif": false])
    }

    @objc func canliBaslat(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            guard let ms = call.getDouble("bitis") else { call.reject("bitis yok"); return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { call.reject("kapali"); return }
            let bitis = Date(timeIntervalSince1970: ms / 1000)
            Task {
                for a in Activity<ImzaAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
                do {
                    let content = ActivityContent(state: ImzaAttributes.ContentState(bitis: bitis), staleDate: bitis)
                    _ = try Activity.request(attributes: ImzaAttributes(), content: content, pushType: nil)
                    call.resolve(["ok": true])
                } catch {
                    call.reject(error.localizedDescription)
                }
            }
            return
        }
        #endif
        call.reject("desteklenmiyor")
    }

    @objc func canliBitir(_ call: CAPPluginCall) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            Task {
                for a in Activity<ImzaAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
                call.resolve()
            }
            return
        }
        #endif
        call.resolve()
    }
}

#if canImport(ActivityKit)
/// Widget uzantısındaki (App/ImzaWidget) ile aynı tanım.
@available(iOS 16.1, *)
public struct ImzaAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var bitis: Date
    }
}
#endif
