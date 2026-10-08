# Kişisel Hesap – iPhone uygulaması

Web uygulamasının (repo kökündeki `index.html`) [Capacitor](https://capacitorjs.com) ile sarılmış yerel iOS sürümü.
Farkı: **Ayağa kalk** hatırlatmaları telefonun kendi bildirimleriyle kurulur, seçilen ses uygulama kapalıyken de çalar;
Cloudflare köprüsüne gerek kalmaz. Geri kalan her şey web sürümüyle aynı.

## iPhone'a yükleme (SideStore)

Uygulama GitHub'da kendiliğinden derlenir: https://github.com/mohammeddilovan0/QR/releases/download/ios/KisiselHesap.ipa
SideStore bu dosyayı kendi Apple ID'nizle imzalayıp yükler ve 7 günlük süreyi telefondan yeniler, Mac gerekmez
(SideStore'un ilk kurulumu hariç: https://docs.sidestore.io).

1. SideStore'u kur (bir kez, Mac ile).
2. iPhone'da Safari ile yukarıdaki .ipa'yı indir.
3. SideStore → **My Apps** → **+** → indirilen `KisiselHesap.ipa`.
4. Güncelleme gelince 2–3'ü tekrarla; veriler silinmez.

Xcode ile de yüklenebilir: `ios-app/ios/App/App.xcodeproj` açılır, **Signing & Capabilities → Team** seçilir, iPhone seçilip **Run**.

## Verileri taşıma

1. Ana ekrandaki eski uygulamada **Daha fazla → Ayarlar → Yedekle**, dosyayı **Dosyalar**'a kaydet.
2. Yeni uygulamada **Daha fazla → Ayarlar → Yedeği geri yükle**, aynı dosyayı seç.

Hatırlatıcı ayarları yedeğe girmez, yeni uygulamada bir kez açıp seçmek gerekir.

## Geliştirici notu

Web uygulaması değişince iOS kopyasını güncellemek için (Node gerekir):

```
cd ios-app && npm install && npm run sync
```

GitHub derlemesi zaten her seferinde güncel `index.html`'i pakete koyar.

`sync`, `index.html`'i `ios/App/App/public/`'e kopyalar ve bildirim eklentisini `ios/plugins/`'e alır;
böylece Mac'te yalnızca Xcode ile derlenebilir. Hatırlatıcı sesleri (`ios/App/App/kalk-*.wav`) web uygulamasının
ürettiği seslerden `scripts/sounds.cjs` ile çıkarılır.
