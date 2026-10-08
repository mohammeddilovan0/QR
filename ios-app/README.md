# Kişisel Hesap – iPhone uygulaması

Web uygulamasının (repo kökündeki `index.html`) [Capacitor](https://capacitorjs.com) ile sarılmış yerel iOS sürümü.
Farkı: **Ayağa kalk** hatırlatmaları telefonun kendi bildirimleriyle kurulur, seçilen ses uygulama kapalıyken de çalar;
Cloudflare köprüsüne gerek kalmaz. Geri kalan her şey web sürümüyle aynı.

## iPhone'a yükleme (Mac'te, Node gerekmez)

1. App Store'dan **Xcode**'u kur ve bir kez aç.
2. Bu repoyu indir (GitHub'da **Code → Download ZIP**, ya da `git clone`).
3. `ios-app/ios/App/App.xcodeproj` dosyasını çift tıkla, Xcode'da açılır. Paketler ilk açılışta kendiliğinden iner.
4. Xcode → **Settings → Accounts** → **+** → Apple ID ile giriş yap (ücretsiz hesap yeter).
5. Soldan **App** projesini seç → **Signing & Capabilities** → **Team**: kendi adın (Personal Team).
   "Bundle identifier kullanılıyor" hatası çıkarsa `com.mohammeddilovan.kisiselhesap` sonuna bir şey ekle (ör. `.m1`).
6. iPhone'u kabloyla Mac'e tak, telefonda **Bu bilgisayara güven** de. iPhone'da **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu**'nu aç (telefon yeniden başlar).
7. Xcode'un üstündeki cihaz listesinden iPhone'unu seç, **▶ (Run)**'a bas.
8. İlk açılışta iPhone **güvenilmeyen geliştirici** der: **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → Apple ID'n → **Güven**. Sonra uygulamayı aç.

Ücretsiz Apple hesabıyla yüklenen uygulama **7 gün** çalışır; sonra telefonu takıp 7. adımı tekrarlamak yeter (veriler silinmez).
Yıllık 99 $ Apple Developer üyeliğiyle bu süre 1 yıl olur ve TestFlight ile kablosuz yüklenebilir.

## Verileri taşıma

1. Ana ekrandaki eski uygulamada **Daha fazla → Ayarlar → Yedekle**, dosyayı **Dosyalar**'a kaydet.
2. Yeni uygulamada **Daha fazla → Ayarlar → Yedeği geri yükle**, aynı dosyayı seç.

Hatırlatıcı ayarları yedeğe girmez, yeni uygulamada bir kez açıp seçmek gerekir.

## Geliştirici notu

Web uygulaması değişince iOS kopyasını güncellemek için (Node gerekir):

```
cd ios-app && npm install && npm run sync
```

`sync`, `index.html`'i `ios/App/App/public/`'e kopyalar ve bildirim eklentisini `ios/plugins/`'e alır;
böylece Mac'te yalnızca Xcode ile derlenebilir. Hatırlatıcı sesleri (`ios/App/App/kalk-*.wav`) web uygulamasının
ürettiği seslerden `scripts/sounds.cjs` ile çıkarılır.
